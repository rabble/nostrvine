// ABOUTME: Account deletion service implementing NIP-62 Request to Vanish
// ABOUTME: Handles network-wide account deletion by publishing kind 62 events to all relays

import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/utils/unified_logger.dart';

/// Result of account deletion operation
class DeleteAccountResult {
  const DeleteAccountResult({
    required this.success,
    this.error,
    this.deleteEventId,
  });

  final bool success;
  final String? error;
  final String? deleteEventId;

  static DeleteAccountResult createSuccess(String deleteEventId) =>
      DeleteAccountResult(success: true, deleteEventId: deleteEventId);

  static DeleteAccountResult failure(String error) =>
      DeleteAccountResult(success: false, error: error);
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

  /// Delete user's account using NIP-62 Request to Vanish
  Future<DeleteAccountResult> deleteAccount({String? customReason}) async {
    try {
      if (!_authService.isAuthenticated) {
        return DeleteAccountResult.failure('Not authenticated');
      }

      // Create NIP-62 event
      final event = await createNip62Event(
        reason:
            customReason ?? 'User requested account deletion via diVine app',
      );

      if (event == null) {
        return DeleteAccountResult.failure('Failed to create deletion event');
      }

      // Publish to all configured relays
      final sentEvent = await _nostrService.publishEvent(event);

      if (sentEvent == null) {
        Log.error(
          'Failed to publish NIP-62 deletion request to any relay',
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

      return DeleteAccountResult.createSuccess(event.id);
    } catch (e) {
      Log.error(
        'Account deletion failed: $e',
        name: 'AccountDeletionService',
        category: LogCategory.system,
      );
      return DeleteAccountResult.failure('Account deletion failed: $e');
    }
  }

  /// Create NIP-62 kind 62 event with ALL_RELAYS tag
  Future<Event?> createNip62Event({required String reason}) async {
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
