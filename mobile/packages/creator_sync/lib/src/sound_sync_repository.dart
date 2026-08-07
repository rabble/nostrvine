// ABOUTME: Reconciles the saved sound library between device and relays.
// ABOUTME: Last-write-wins per item, with tombstones and a resurrect guard.

import 'package:creator_sync/src/creator_sync_reportable_sites.dart';
import 'package:creator_sync/src/exceptions.dart';
import 'package:creator_sync/src/sync_index_client.dart';
import 'package:creator_sync/src/sync_index_entry.dart';
import 'package:creator_sync/src/sync_item_ref.dart';
import 'package:creator_sync/src/sync_state_store.dart';
import 'package:meta/meta.dart';

/// Reports an error to the host app's crash reporter.
///
/// This package cannot import the app's observability layer without
/// inverting the dependency direction, so the app injects this port and
/// wires it to `CrashReportingService.instance.recordError`.
typedef CreatorSyncErrorReporter =
    void Function(
      Object error,
      StackTrace stackTrace, {
      required String site,
    });

/// Device-local saved sound persistence, keyed by sound id.
///
/// Implemented in the app layer over `SavedSoundsService`.
abstract interface class LocalSoundStore {
  /// Returns every locally saved sound as `id -> serialized body`.
  Future<Map<String, Map<String, dynamic>>> readAll();

  /// Inserts or replaces the sound [id] with [body].
  Future<void> upsert(String id, Map<String, dynamic> body);

  /// Deletes the sound [id] if present.
  Future<void> remove(String id);
}

/// What one reconcile pass changed.
@immutable
class SoundSyncOutcome {
  /// Creates a [SoundSyncOutcome].
  const SoundSyncOutcome({
    required this.pulled,
    required this.pushed,
    required this.deleted,
  });

  /// Remote sounds applied locally.
  final int pulled;

  /// Local sounds published to relays.
  final int pushed;

  /// Local sounds removed by a remote tombstone.
  final int deleted;
}

/// Mirrors the saved sound library across a user's devices.
class SoundSyncRepository {
  /// Creates a [SoundSyncRepository].
  SoundSyncRepository({
    required SyncIndexClient index,
    required SyncStateStore state,
    required LocalSoundStore local,
    CreatorSyncErrorReporter? errorReporter,
  }) : _index = index,
       _state = state,
       _local = local,
       _report = errorReporter;

  final SyncIndexClient _index;
  final SyncStateStore _state;
  final LocalSoundStore _local;
  final CreatorSyncErrorReporter? _report;

  /// Runs one full reconcile pass.
  ///
  /// Throws [SyncIndexException] when the relay round trip fails; callers
  /// treat that as transient and retry on the next trigger.
  Future<SoundSyncOutcome> reconcile() async {
    try {
      final applied = await _state.readApplied(SyncItemKind.sound);
      final remote = await _index.fetch(SyncItemKind.sound);
      final localSounds = await _local.readAll();

      var pulled = 0;
      var deleted = 0;

      for (final record in remote) {
        final dTag = record.ref.dTag;
        final seen = applied[dTag];
        if (seen != null && record.createdAt <= seen.createdAt) continue;

        if (record.entry.deleted) {
          if (localSounds.containsKey(record.ref.id)) {
            await _local.remove(record.ref.id);
            // Keeps the snapshot the push loop below iterates in sync
            // with what was just removed — this is the resurrection
            // guard: without it the push loop would see this id as a
            // local item with no matching applied hash and republish it.
            localSounds.remove(record.ref.id);
            deleted++;
          }
          applied[dTag] = SyncItemState(
            createdAt: record.createdAt,
            bodyHash: SyncItemState.tombstoneHash,
          );
        } else {
          await _local.upsert(record.ref.id, record.entry.body!);
          localSounds[record.ref.id] = record.entry.body!;
          pulled++;
          applied[dTag] = SyncItemState(
            createdAt: record.createdAt,
            bodyHash: syncBodyHash(record.entry.body!),
          );
        }
      }

      // Commits pull progress before the push phase runs. `_local.upsert`
      // and `_local.remove` above already persisted to disk, so if a
      // publish below throws, the in-memory `applied` map must not be
      // discarded — otherwise the next reconcile would see these items as
      // unseen and re-apply the (now stale) remote body over whatever the
      // user edited locally in between.
      await _state.writeApplied(SyncItemKind.sound, applied);

      var pushed = 0;
      for (final entry in localSounds.entries) {
        final ref = SyncItemRef(SyncItemKind.sound, entry.key);
        final localHash = syncBodyHash(entry.value);
        final seen = applied[ref.dTag];

        // Publish when this item was never published (a new add, or an
        // add whose publish failed), or when the local body has drifted
        // from what was last published (an edit whose publish failed).
        // Matching hashes mean the relay already has this exact body, so
        // republishing would only fight the other device.
        if (seen != null && seen.bodyHash == localHash) continue;

        final stamped = await _index.publish(
          ref,
          SyncIndexEntry.item(body: entry.value),
          latestKnownRemote: seen?.createdAt,
        );
        applied[ref.dTag] = SyncItemState(
          createdAt: stamped,
          bodyHash: localHash,
        );
        pushed++;
      }

      await _state.writeApplied(SyncItemKind.sound, applied);
      return SoundSyncOutcome(
        pulled: pulled,
        pushed: pushed,
        deleted: deleted,
      );
    } on SyncIndexException {
      // Expected relay/network failures and expected auth/signer failures
      // (e.g. signed out, signer refused to sign) are both surfaced via a
      // status enum in the UI, not Crashlytics. See error_handling.md.
      rethrow;
    } catch (e, stackTrace) {
      _report?.call(
        e,
        stackTrace,
        site: CreatorSyncReportableSites.reconcileSounds,
      );
      rethrow;
    }
  }

  /// Publishes the current local state of sound [soundId].
  ///
  /// On success the applied state advances so the next reconcile does not
  /// treat this device's own echo as a remote edit. On failure nothing is
  /// recorded, leaving the body hash stale so the next reconcile detects
  /// the drift and retries the publish.
  Future<void> publishLocalChange(String soundId) async {
    try {
      final sounds = await _local.readAll();
      final body = sounds[soundId];
      // Intentional no-op: the sound was removed locally (or the id was
      // never valid) between the caller's own change and this publish
      // call, so there is nothing left to publish.
      if (body == null) return;

      final applied = await _state.readApplied(SyncItemKind.sound);
      final ref = SyncItemRef(SyncItemKind.sound, soundId);
      final stamped = await _index.publish(
        ref,
        SyncIndexEntry.item(body: body),
        latestKnownRemote: applied[ref.dTag]?.createdAt,
      );
      applied[ref.dTag] = SyncItemState(
        createdAt: stamped,
        bodyHash: syncBodyHash(body),
      );
      await _state.writeApplied(SyncItemKind.sound, applied);
    } on SyncIndexException {
      rethrow;
    } catch (e, stackTrace) {
      _report?.call(
        e,
        stackTrace,
        site: CreatorSyncReportableSites.publishSoundChange,
      );
      rethrow;
    }
  }

  /// Publishes a tombstone for sound [soundId].
  Future<void> publishLocalDeletion(String soundId) async {
    try {
      final applied = await _state.readApplied(SyncItemKind.sound);
      final ref = SyncItemRef(SyncItemKind.sound, soundId);
      final stamped = await _index.publish(
        ref,
        SyncIndexEntry.tombstone(),
        latestKnownRemote: applied[ref.dTag]?.createdAt,
      );
      applied[ref.dTag] = SyncItemState(
        createdAt: stamped,
        bodyHash: SyncItemState.tombstoneHash,
      );
      await _state.writeApplied(SyncItemKind.sound, applied);
    } on SyncIndexException {
      rethrow;
    } catch (e, stackTrace) {
      _report?.call(
        e,
        stackTrace,
        site: CreatorSyncReportableSites.publishSoundDeletion,
      );
      rethrow;
    }
  }
}
