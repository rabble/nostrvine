// ABOUTME: Account deletion service implementing NIP-62 Request to Vanish
// ABOUTME: Handles network-wide account deletion by publishing kind 5 events for all user content
// ABOUTME: then publishing kind 62 event to all relays

import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:unified_logger/unified_logger.dart';

/// Result of account deletion operation
class DeleteAccountResult {
  const DeleteAccountResult({
    required this.success,
    this.error,
    this.deleteEventId,
    this.deletedEventsCount = 0,
    this.accountChanged = false,
    this.contentQueryFailed = false,
  });

  final bool success;
  final String? error;
  final String? deleteEventId;

  /// Number of events a relay actually confirmed (`OK true`) a kind-5 deletion
  /// request for — not merely the number we managed to write to a socket.
  final int deletedEventsCount;

  /// True when the relay query that enumerates the user's existing content
  /// failed, so the kind-5 sweep covered nothing.
  ///
  /// The vanish request may still have been published, so the caller must tell
  /// the user their existing content was *not* individually requested for
  /// deletion rather than reporting an unqualified success.
  final bool contentQueryFailed;

  /// True when the deletion aborted because the signed-in account no longer
  /// matches the account the user confirmed. Lets the UI localize the outcome
  /// rather than surfacing the raw abort string.
  final bool accountChanged;

  static DeleteAccountResult createSuccess(
    String deleteEventId, {
    int deletedEventsCount = 0,
    bool contentQueryFailed = false,
  }) => DeleteAccountResult(
    success: true,
    deleteEventId: deleteEventId,
    deletedEventsCount: deletedEventsCount,
    contentQueryFailed: contentQueryFailed,
  );

  static DeleteAccountResult failure(
    String error, {
    bool accountChanged = false,
  }) => DeleteAccountResult(
    success: false,
    error: error,
    accountChanged: accountChanged,
  );
}

/// Thrown when the signed-in account changes mid-deletion, so no kind-5 or
/// kind-62 event is ever signed for an account the user did not confirm.
class AccountChangedDuringDeletion implements Exception {
  const AccountChangedDuringDeletion();

  @override
  String toString() => 'AccountChangedDuringDeletion';
}

/// Service for deleting user's entire Nostr account via NIP-62
class AccountDeletionService {
  AccountDeletionService({
    required NostrClient nostrService,
    required AuthService authService,
  }) : _nostrService = nostrService,
       _authService = authService;

  final NostrClient _nostrService;
  final AuthService _authService;

  /// Kinds this flow's own deletion machinery produces, excluded from the sweep.
  ///
  /// NIP-09: "Publishing a deletion request event against a deletion request has
  /// no effect." NIP-62 states the same for a request to vanish. Sweeping them
  /// asks relays to delete this flow's own kind-5 requests and the vanish
  /// request itself, which grows the `e`-tag list on every retry for no
  /// protocol effect — and asks the network to retract a legally-framed vanish.
  static const _kindsExcludedFromSweep = {5, 62};

  /// Inclusive lower bound of the NIP-01 addressable (parameterized replaceable)
  /// range. Deletions for these kinds need an `a` tag, not just `e`.
  static const _addressableKindMin = 30000;
  static const _addressableKindMax = 39999;

  /// Aborts (via [AccountChangedDuringDeletion]) if [expectedPubkey] is set and
  /// no longer matches the live signer. Called immediately before every
  /// destructive sign/publish so a mid-flight account switch can't delete a
  /// different account's content.
  void _assertSignerMatches(String? expectedPubkey) {
    if (expectedPubkey != null &&
        _authService.currentPublicKeyHex != expectedPubkey) {
      throw const AccountChangedDuringDeletion();
    }
  }

  /// Delete user's account using NIP-62 Request to Vanish
  /// First fetches all user events and publishes kind 5 deletion requests for each
  /// Then publishes kind 62 account deletion request
  Future<DeleteAccountResult> deleteAccount({
    String? customReason,
    void Function(int current, int total)? onProgress,
    String? expectedPubkey,
  }) async {
    try {
      if (!_authService.isAuthenticated) {
        return DeleteAccountResult.failure('Not authenticated');
      }

      final pubkey = _authService.currentPublicKeyHex;
      if (pubkey == null || pubkey.isEmpty) {
        return DeleteAccountResult.failure('No pubkey available');
      }
      if (expectedPubkey != null && pubkey != expectedPubkey) {
        return DeleteAccountResult.failure(
          'Signed-in account changed; deletion aborted',
          accountChanged: true,
        );
      }

      final reason =
          customReason ?? 'User requested account deletion via Divine app';

      Log.info(
        'Starting account deletion for pubkey: $pubkey',
        name: 'AccountDeletionService',
        category: LogCategory.system,
      );

      final sweep = await _fetchSweepTargets(pubkey);
      final allUserEvents = sweep.events;

      Log.info(
        'Found ${allUserEvents.length} events to delete'
        '${sweep.queryFailed ? ' (relay query FAILED — sweep will cover nothing)' : ''}',
        name: 'AccountDeletionService',
        category: LogCategory.system,
      );

      int deletedCount = 0;
      if (allUserEvents.isNotEmpty) {
        deletedCount = await _publishDeletionEventsForAll(
          allUserEvents,
          reason,
          expectedPubkey: expectedPubkey,
          onProgress: onProgress,
        );

        Log.info(
          'Published $deletedCount NIP-09 deletion requests',
          name: 'AccountDeletionService',
          category: LogCategory.system,
        );
      }

      final event = await createNip62Event(
        reason: reason,
        expectedPubkey: expectedPubkey,
      );

      if (event == null) {
        return DeleteAccountResult.failure('Failed to create deletion event');
      }

      // Final guard immediately before the network-wide kind-62 publish.
      _assertSignerMatches(expectedPubkey);
      // Await the relay `OK` rather than the socket write: this event is
      // irreversible and legally framed, so "a WebSocket accepted the frame" is
      // not good enough evidence to report deletion to the user.
      final outcome = await _nostrService.publishEventAwaitOk(event);

      if (outcome.failed) {
        Log.error(
          'NIP-62 deletion request not confirmed by any relay: '
          '${outcome.summary}',
          name: 'AccountDeletionService',
          category: LogCategory.system,
        );
        return DeleteAccountResult.failure(
          'Failed to publish deletion request to relays',
        );
      }

      Log.info(
        'NIP-62 deletion request confirmed by relay(s): ${outcome.acceptedBy}',
        name: 'AccountDeletionService',
        category: LogCategory.system,
      );

      return DeleteAccountResult.createSuccess(
        event.id,
        deletedEventsCount: deletedCount,
        contentQueryFailed: sweep.queryFailed,
      );
    } on AccountChangedDuringDeletion {
      Log.warning(
        'Deletion aborted: signed-in account changed mid-flight',
        name: 'AccountDeletionService',
        category: LogCategory.auth,
      );
      return DeleteAccountResult.failure(
        'Signed-in account changed; deletion aborted',
        accountChanged: true,
      );
    } catch (e) {
      Log.error(
        'Account deletion failed: $e',
        name: 'AccountDeletionService',
        category: LogCategory.system,
      );
      return DeleteAccountResult.failure('Account deletion failed: $e');
    }
  }

  /// The value of an event's first `d` tag, or `null` when it has none.
  ///
  /// An addressable event's coordinate is `kind:pubkey:d-tag`, so a missing `d`
  /// tag means the event has no addressable coordinate to delete.
  static String? _dTagOf(Event event) {
    for (final tag in event.tags) {
      if (tag.length >= 2 && tag[0] == 'd') {
        return tag[1];
      }
    }
    return null;
  }

  /// Fetch the user's events that are valid targets for the kind-5 sweep.
  ///
  /// NIP-01 filters cannot express "every kind except these", so the query stays
  /// broad and [_kindsExcludedFromSweep] is applied here.
  ///
  /// Returns `queryFailed: true` when the relay query itself failed. The caller
  /// must not treat that as "this account has no content" — the previous
  /// behaviour of swallowing the error into an empty list silently skipped the
  /// entire sweep while still publishing the vanish.
  Future<({List<Event> events, bool queryFailed})> _fetchSweepTargets(
    String pubkey,
  ) async {
    try {
      final filter = Filter(authors: [pubkey], limit: 10000);
      final events = await _nostrService.queryEvents([filter]);

      final targets = events
          .where((event) => !_kindsExcludedFromSweep.contains(event.kind))
          .toList(growable: false);

      Log.debug(
        'Fetched ${events.length} events for user $pubkey '
        '(${targets.length} sweep targets after excluding kinds '
        '${_kindsExcludedFromSweep.join(', ')})',
        name: 'AccountDeletionService',
        category: LogCategory.system,
      );

      return (events: targets, queryFailed: false);
    } catch (e) {
      Log.error(
        'Failed to fetch user events: $e',
        name: 'AccountDeletionService',
        category: LogCategory.system,
      );
      return (events: const <Event>[], queryFailed: true);
    }
  }

  /// Publish NIP-09 kind 5 deletion events for all user events
  Future<int> _publishDeletionEventsForAll(
    List<Event> events,
    String reason, {
    String? expectedPubkey,
    void Function(int current, int total)? onProgress,
  }) async {
    int successCount = 0;
    final total = events.length;

    final eventsByKind = <int, List<Event>>{};
    for (final event in events) {
      eventsByKind.putIfAbsent(event.kind, () => []).add(event);
    }

    for (final entry in eventsByKind.entries) {
      final kind = entry.key;
      final kindEvents = entry.value;

      final deleteEvent = await _createBatchDeleteEvent(
        events: kindEvents,
        kind: kind,
        reason: reason,
        expectedPubkey: expectedPubkey,
      );

      if (deleteEvent != null) {
        final outcome = await _nostrService.publishEventAwaitOk(deleteEvent);
        if (outcome.confirmed) {
          successCount += kindEvents.length;
          Log.debug(
            'Batch deletion for ${kindEvents.length} kind $kind events '
            'confirmed by ${outcome.acceptedBy}',
            name: 'AccountDeletionService',
            category: LogCategory.system,
          );
        } else {
          Log.warning(
            'Batch deletion for kind $kind not confirmed: ${outcome.summary}',
            name: 'AccountDeletionService',
            category: LogCategory.system,
          );
        }
      }

      onProgress?.call(successCount, total);
    }

    return successCount;
  }

  /// Create NIP-09 kind 5 deletion event for multiple events of the same kind
  Future<Event?> _createBatchDeleteEvent({
    required List<Event> events,
    required int kind,
    required String reason,
    String? expectedPubkey,
  }) async {
    try {
      if (!_authService.isAuthenticated) {
        return null;
      }

      final tags = <List<String>>[];

      // Addressable kinds need an `a` tag as well as `e`. NIP-09: "When an `a`
      // tag is used, relays SHOULD delete all versions of the replaceable event
      // up to the `created_at`." With `e` alone, every prior version of an
      // edited video survives on a relay that implements NIP-09 but not NIP-62
      // — which is exactly the population this sweep exists to serve.
      final isAddressable =
          kind >= _addressableKindMin && kind <= _addressableKindMax;
      final addressableIds = <String>{};

      for (final event in events) {
        tags.add(['e', event.id]);

        if (isAddressable) {
          final dTag = _dTagOf(event);
          if (dTag != null && dTag.isNotEmpty) {
            addressableIds.add('$kind:${event.pubkey}:$dTag');
          }
        }
      }

      for (final addressableId in addressableIds) {
        tags.add(['a', addressableId]);
      }

      tags.add(['k', kind.toString()]);

      // Immediately before signing the kind-5 deletion for this account.
      _assertSignerMatches(expectedPubkey);
      final signedEvent = await _authService.createAndSignEvent(
        kind: 5,
        content: reason,
        tags: tags,
      );

      return signedEvent;
    } on AccountChangedDuringDeletion {
      rethrow;
    } catch (e) {
      Log.error(
        'Failed to create batch delete event: $e',
        name: 'AccountDeletionService',
        category: LogCategory.system,
      );
      return null;
    }
  }

  /// Create NIP-62 kind 62 event with ALL_RELAYS tag
  Future<Event?> createNip62Event({
    required String reason,
    String? expectedPubkey,
  }) async {
    try {
      if (!_authService.isAuthenticated) {
        Log.error(
          'Cannot create NIP-62 event: not authenticated',
          name: 'AccountDeletionService',
          category: LogCategory.system,
        );
        return null;
      }

      final pubkey = _authService.currentPublicKeyHex;
      if (pubkey == null || pubkey.isEmpty) {
        Log.error(
          'Cannot create NIP-62 event: no pubkey available',
          name: 'AccountDeletionService',
          category: LogCategory.system,
        );
        return null;
      }

      // NIP-62 requires relay tag with ALL_RELAYS for network-wide deletion
      final tags = <List<String>>[
        ['relay', 'ALL_RELAYS'],
      ];

      Log.info(
        'Creating NIP-62 event with pubkey: $pubkey, kind: 62, reason: $reason',
        name: 'AccountDeletionService',
        category: LogCategory.system,
      );

      // Immediately before signing the network-wide kind-62 vanish.
      _assertSignerMatches(expectedPubkey);
      // Create and sign event via AuthService
      final signedEvent = await _authService.createAndSignEvent(
        kind: 62, // NIP-62 account deletion kind
        content: reason,
        tags: tags,
      );

      if (signedEvent == null) {
        Log.error(
          'Failed to create and sign NIP-62 event',
          name: 'AccountDeletionService',
          category: LogCategory.system,
        );
        return null;
      }

      Log.info(
        'Created NIP-62 deletion event (kind 62): ${signedEvent.id}',
        name: 'AccountDeletionService',
        category: LogCategory.system,
      );

      return signedEvent;
    } on AccountChangedDuringDeletion {
      rethrow;
    } catch (e, stackTrace) {
      Log.error(
        'Failed to create NIP-62 event: $e\nStack trace: $stackTrace',
        name: 'AccountDeletionService',
        category: LogCategory.system,
      );
      return null;
    }
  }
}
