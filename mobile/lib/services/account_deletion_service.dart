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
  });

  final bool success;
  final String? error;
  final String? deleteEventId;
  final int deletedEventsCount;

  /// True when the deletion aborted because the signed-in account no longer
  /// matches the account the user confirmed. Lets the UI localize the outcome
  /// rather than surfacing the raw abort string.
  final bool accountChanged;

  static DeleteAccountResult createSuccess(
    String deleteEventId, {
    int deletedEventsCount = 0,
  }) => DeleteAccountResult(
    success: true,
    deleteEventId: deleteEventId,
    deletedEventsCount: deletedEventsCount,
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

      final allUserEvents = await _fetchAllUserEvents(pubkey);

      Log.info(
        'Found ${allUserEvents.length} events to delete',
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
      final sentEvent = await _nostrService.publishEvent(event);

      final failureReason = sentEvent.failureReason;
      if (failureReason != null) {
        Log.error(
          'Failed to publish NIP-62 deletion request: $failureReason',
          name: 'AccountDeletionService',
          category: LogCategory.system,
        );
        return DeleteAccountResult.failure(
          'Failed to publish deletion request to relays',
        );
      }

      Log.info(
        'NIP-62 deletion request published to relays',
        name: 'AccountDeletionService',
        category: LogCategory.system,
      );

      return DeleteAccountResult.createSuccess(
        event.id,
        deletedEventsCount: deletedCount,
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

  /// Fetch all events authored by the user from relays
  Future<List<Event>> _fetchAllUserEvents(String pubkey) async {
    final allEvents = <Event>[];

    try {
      final filter = Filter(authors: [pubkey], limit: 10000);
      final events = await _nostrService.queryEvents([filter]);

      allEvents.addAll(events);

      Log.debug(
        'Fetched ${events.length} events for user $pubkey',
        name: 'AccountDeletionService',
        category: LogCategory.system,
      );
    } catch (e) {
      Log.error(
        'Failed to fetch user events: $e',
        name: 'AccountDeletionService',
        category: LogCategory.system,
      );
    }

    return allEvents;
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
        final sentEvent = await _nostrService.publishEvent(deleteEvent);
        if (sentEvent.isSuccess) {
          successCount += kindEvents.length;
          Log.debug(
            'Published batch deletion for ${kindEvents.length} kind $kind events',
            name: 'AccountDeletionService',
            category: LogCategory.system,
          );
        } else {
          Log.warning(
            'Batch deletion for kind $kind skipped: ${sentEvent.failureReason}',
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

      for (final event in events) {
        tags.add(['e', event.id]);
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
