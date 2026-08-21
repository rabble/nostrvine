// ABOUTME: Coordinates Shorebird patch reads, downloads, and update tracks
// ABOUTME: Persists staging validation across relaunches without racing stable

import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';
import 'package:unified_logger/unified_logger.dart';

/// The update track this installation checks at startup.
enum ShorebirdSubscribedTrack { stable, staging }

/// Patch state read from the Shorebird engine.
class ShorebirdPatchSnapshot {
  const ShorebirdPatchSnapshot({required this.current, required this.next});

  final Patch? current;
  final Patch? next;

  bool get hasPendingPatch => next != null && next?.number != current?.number;
}

/// Result of trying to download a patch from the staging track.
enum ShorebirdPatchApplyResult { installed, unchanged }

/// A track check plus patch state captured before and after it.
class ShorebirdPatchCheck {
  const ShorebirdPatchCheck({
    required this.status,
    required this.before,
    required this.snapshot,
  });

  final UpdateStatus status;
  final ShorebirdPatchSnapshot before;
  final ShorebirdPatchSnapshot snapshot;

  bool get isRollback =>
      status == UpdateStatus.restartRequired &&
      before.current != null &&
      snapshot.next == null;
}

/// Owns Shorebird updater calls and the track persisted across app launches.
class ShorebirdPatchRepository {
  ShorebirdPatchRepository({
    required ShorebirdUpdater updater,
    required SharedPreferences preferences,
  }) : _updater = updater,
       _preferences = preferences;

  static const _subscribedTrackKey = 'shorebird_subscribed_track';

  // Startup and Developer Options create separate repository instances. A
  // process-wide tail is therefore required to prevent their Shorebird FFI
  // calls from overlapping. The upstream calls have no timeout; if one hangs,
  // later operations intentionally remain queued until the app is relaunched.
  static Future<void>? _operationTail;

  final ShorebirdUpdater _updater;
  final SharedPreferences _preferences;

  bool get isAvailable => _updater.isAvailable;

  ShorebirdSubscribedTrack get subscribedTrack {
    final stored = _preferences.getString(_subscribedTrackKey);
    return ShorebirdSubscribedTrack.values.firstWhere(
      (track) => track.name == stored,
      orElse: () => ShorebirdSubscribedTrack.stable,
    );
  }

  Future<ShorebirdPatchSnapshot> readSnapshot() => _runExclusive(_readSnapshot);

  Future<ShorebirdPatchSnapshot> _readSnapshot() async {
    final (current, next) = await (
      _updater.readCurrentPatch(),
      _updater.readNextPatch(),
    ).wait;
    return ShorebirdPatchSnapshot(current: current, next: next);
  }

  Future<ShorebirdPatchCheck> checkStagingTrack() => _runExclusive(() async {
    final before = await _readSnapshot();
    final status = await _updater.checkForUpdate(track: UpdateTrack.staging);
    return ShorebirdPatchCheck(
      status: status,
      before: before,
      snapshot: await _readSnapshot(),
    );
  });

  Future<ShorebirdPatchApplyResult> applyStagingPatch() =>
      _runExclusive(() async {
        final before = await _readSnapshot();
        await _updater.update(track: UpdateTrack.staging);
        final after = await _readSnapshot();

        final downloadedNewPatch =
            after.hasPendingPatch && after.next?.number != before.next?.number;
        if (!downloadedNewPatch) return ShorebirdPatchApplyResult.unchanged;

        await _saveSubscribedTrack(ShorebirdSubscribedTrack.staging);
        return ShorebirdPatchApplyResult.installed;
      });

  Future<void> useStableTrack() => _runExclusive(
    () => _saveSubscribedTrack(ShorebirdSubscribedTrack.stable),
  );

  /// Replaces Shorebird's native launch updater while supporting custom tracks.
  Future<void> updateSubscribedTrackAtStartup() => _runExclusive(() async {
    if (!isAvailable) {
      Log.warning(
        'Skipping automatic patch check because Shorebird is unavailable',
        name: 'ShorebirdPatchRepository',
      );
      return;
    }

    final track = switch (subscribedTrack) {
      ShorebirdSubscribedTrack.stable => UpdateTrack.stable,
      ShorebirdSubscribedTrack.staging => UpdateTrack.staging,
    };
    final status = await _updater.checkForUpdate(track: track);
    if (status == UpdateStatus.outdated) {
      await _updater.update(track: track);
    }
  });

  Future<void> _saveSubscribedTrack(ShorebirdSubscribedTrack track) async {
    final saved = await _preferences.setString(_subscribedTrackKey, track.name);
    if (!saved) throw StateError('Unable to persist Shorebird update track');
  }

  Future<T> _runExclusive<T>(Future<T> Function() operation) {
    final result = Completer<T>();
    final previousOperation = _operationTail;
    late final Future<void> operationTail;
    operationTail = (previousOperation ?? Future<void>.value())
        .then((_) async {
          try {
            result.complete(await operation());
          } catch (error, stackTrace) {
            result.completeError(error, stackTrace);
          }
        })
        .whenComplete(() {
          if (identical(_operationTail, operationTail)) _operationTail = null;
        });
    _operationTail = operationTail;
    return result.future;
  }
}
