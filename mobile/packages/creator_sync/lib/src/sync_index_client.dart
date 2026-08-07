// ABOUTME: Publishes and fetches encrypted kind-30078 sync index events.
// ABOUTME: Filters foreign app-data events out of the shared kind.

import 'package:creator_sync/src/exceptions.dart';
import 'package:creator_sync/src/sync_cipher.dart';
import 'package:creator_sync/src/sync_clock.dart';
import 'package:creator_sync/src/sync_index_entry.dart';
import 'package:creator_sync/src/sync_item_ref.dart';
import 'package:meta/meta.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/event_kind.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:nostr_sdk/signer/nostr_signer.dart';
import 'package:unified_logger/unified_logger.dart';

/// One decrypted sync index event fetched from a relay.
@immutable
class RemoteSyncRecord {
  /// Creates a [RemoteSyncRecord].
  const RemoteSyncRecord({
    required this.ref,
    required this.entry,
    required this.createdAt,
  });

  /// Which item this record describes.
  final SyncItemRef ref;

  /// The decrypted payload.
  final SyncIndexEntry entry;

  /// The event's `created_at`, used for last-write-wins comparison.
  final int createdAt;
}

/// Reads and writes the encrypted sync index on Nostr.
class SyncIndexClient {
  /// Creates a [SyncIndexClient].
  SyncIndexClient({
    required NostrClient client,
    required NostrSigner signer,
    required SyncCipher cipher,
  }) : _client = client,
       _signer = signer,
       _cipher = cipher;

  final NostrClient _client;
  final NostrSigner _signer;
  final SyncCipher _cipher;

  /// How long a tombstone lives before relays may reap it (NIP-40).
  static const Duration tombstoneLifetime = Duration(days: 90);

  static const String _logName = 'SyncIndexClient';

  /// Publishes [entry] as the addressable event for [ref].
  ///
  /// Returns the `created_at` stamped on the event so the caller can
  /// record the authoritative value rather than re-deriving it.
  ///
  /// Throws [SyncIndexException] when signing fails or no relay accepts.
  Future<int> publish(
    SyncItemRef ref,
    SyncIndexEntry entry, {
    int? latestKnownRemote,
  }) async {
    final pubkey = await _signer.getPublicKey();
    if (pubkey == null || pubkey.isEmpty) {
      throw SyncIndexException('cannot publish while signed out');
    }

    final createdAt = SyncClock.nowSeconds(
      latestKnownRemote: latestKnownRemote,
    );
    final tags = <List<String>>[
      ['d', ref.dTag],
      if (entry.deleted)
        ['expiration', '${createdAt + tombstoneLifetime.inSeconds}'],
    ];

    final event = Event(
      pubkey,
      EventKind.appSpecificData,
      tags,
      await _cipher.seal(entry.toPayloadJson()),
      createdAt: createdAt,
    );

    final signed = await _signer.signEvent(event);
    if (signed == null) {
      throw SyncIndexException('signer refused to sign ${ref.dTag}');
    }

    final result = await _client.publishEvent(signed);
    if (!result.isSuccess) {
      throw SyncIndexException('no relay accepted ${ref.dTag}');
    }
    return createdAt;
  }

  /// Fetches every known record of [kind] for the signed-in account.
  ///
  /// Pass [since] to fetch incrementally. Records that fail to decrypt or
  /// parse are skipped rather than aborting the whole reconcile — one bad
  /// event must not strand the rest of the library.
  ///
  /// Throws [SyncIndexException] when signed out or the query fails.
  Future<List<RemoteSyncRecord>> fetch(SyncItemKind kind, {int? since}) async {
    final pubkey = await _signer.getPublicKey();
    if (pubkey == null || pubkey.isEmpty) {
      throw SyncIndexException('cannot fetch while signed out');
    }

    // queryEventsDetailed, not queryEvents: the latter discards `timedOut`
    // and `noRelays` and returns [] on an unreachable relay, which would
    // read as "the account has no synced items" and let reconcile publish
    // over a library it simply could not see.
    final List<Event> events;
    try {
      final result = await _client.queryEventsDetailed([
        Filter(
          kinds: [EventKind.appSpecificData],
          authors: [pubkey],
          since: since,
        ),
      ]);
      if (result.noRelays || result.timedOut) {
        throw SyncIndexException(
          'sync index query could not reach a relay '
          '(noRelays: ${result.noRelays}, timedOut: ${result.timedOut})',
        );
      }
      events = result.events;
    } on SyncIndexException {
      rethrow;
    } catch (e) {
      throw SyncIndexException('sync index query failed: ${e.runtimeType}');
    }

    // Relay filters cannot prefix-match d tags, so this result also holds
    // foreign app-data events (DM read cursors, the vault key). Keep only
    // the newest event per recognised item d tag.
    final newest = <String, Event>{};
    for (final event in events) {
      final dTag = event.dTagValue;
      if (dTag.isEmpty) continue;
      final ref = SyncItemRef.tryParse(dTag);
      if (ref == null || ref.kind != kind) continue;

      final existing = newest[dTag];
      if (existing == null || event.createdAt > existing.createdAt) {
        newest[dTag] = event;
      }
    }

    final records = <RemoteSyncRecord>[];
    for (final entry in newest.entries) {
      final ref = SyncItemRef.tryParse(entry.key)!;
      try {
        records.add(
          RemoteSyncRecord(
            ref: ref,
            entry: SyncIndexEntry.fromPayloadJson(
              await _cipher.open(entry.value.content),
            ),
            createdAt: entry.value.createdAt,
          ),
        );
      } on SyncDecryptException catch (e) {
        Log.warning(
          'skipping undecryptable sync record ${entry.key}: ${e.message}',
          name: _logName,
          category: LogCategory.relay,
        );
      } on FormatException catch (e) {
        Log.warning(
          'skipping malformed sync record ${entry.key}: ${e.message}',
          name: _logName,
          category: LogCategory.relay,
        );
      }
    }
    return records;
  }
}
