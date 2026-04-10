// ABOUTME: Service for sending encrypted NIP-17 (gift-wrapped) private messages
// ABOUTME: Handles three-layer encryption (kind 14 rumor → kind 13 seal → kind 1059 gift wrap)
// ABOUTME: Works with any NostrSigner (local keys, Keycast RPC, Amber, etc.)

import 'package:models/models.dart' show NIP17SendResult;
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/event_kind.dart';
import 'package:nostr_sdk/nip59/gift_wrap_util.dart';
import 'package:nostr_sdk/nostr.dart';
import 'package:nostr_sdk/relay/relay.dart';
import 'package:nostr_sdk/signer/nostr_signer.dart';
import 'package:unified_logger/unified_logger.dart';

/// Service for sending encrypted private messages using NIP-17 gift wrapping.
///
/// Accepts any [NostrSigner] implementation, supporting both local key
/// signing and remote signing (e.g. Keycast RPC, Amber).
class NIP17MessageService {
  NIP17MessageService({
    required NostrSigner signer,
    required String senderPublicKey,
    required NostrClient nostrService,
  }) : _signer = signer,
       _senderPublicKey = senderPublicKey,
       _nostrService = nostrService;

  final NostrSigner _signer;
  final String _senderPublicKey;
  final NostrClient _nostrService;

  /// Access to the underlying NostrService for relay management
  NostrClient get nostrService => _nostrService;

  /// Send a private encrypted message to a recipient.
  ///
  /// Uses NIP-17 three-layer encryption:
  /// 1. Rumor (unsigned) — the actual message content
  /// 2. Kind 13 (seal) — signed and encrypted by sender
  /// 3. Kind 1059 (gift wrap) — wrapped with random ephemeral key
  ///
  /// Parameters:
  /// - [recipientPubkey]: Recipient's public key (hex format)
  /// - [content]: Message content (text for kind 14, file URL for kind 15)
  /// - [eventKind]: The rumor event kind (14 = text, 15 = file)
  /// - [additionalTags]: Optional tags to include in the rumor event
  Future<NIP17SendResult> sendPrivateMessage({
    required String recipientPubkey,
    required String content,
    int eventKind = EventKind.privateDirectMessage,
    List<List<String>> additionalTags = const [],
  }) async {
    try {
      Log.info(
        'Sending NIP-17 encrypted message to recipient',
        category: LogCategory.system,
      );

      // Create a minimal Nostr instance for GiftWrapUtil.
      // Uses the injected signer (works with local or remote signing).
      final nostr = Nostr(
        _signer,
        [], // Empty filters - not using for subscriptions
        _dummyRelayGenerator, // Dummy relay generator - not using relays
      );
      await nostr.refreshPublicKey();

      // Create kind 14 rumor event (unsigned, will be encrypted)
      final rumorTags = <List<String>>[
        ['p', recipientPubkey],
        ...additionalTags,
      ];

      final rumorEvent = Event(
        _senderPublicKey,
        eventKind,
        rumorTags,
        content,
      );

      Log.debug(
        'Created kind $eventKind rumor event',
        category: LogCategory.system,
      );

      // Create gift wrap for the recipient
      final giftWrapEvent = await GiftWrapUtil.getGiftWrapEvent(
        nostr,
        rumorEvent,
        recipientPubkey,
      );

      if (giftWrapEvent == null) {
        return NIP17SendResult.failure('Failed to create gift wrap event');
      }

      Log.debug(
        'Created recipient gift wrap with ephemeral key: '
        '${giftWrapEvent.pubkey}',
        category: LogCategory.system,
      );

      // Publish the recipient's gift wrap
      final sentEvent = await _nostrService.publishEvent(giftWrapEvent);

      if (sentEvent == null) {
        const errorMsg = 'Message publish failed to relays';
        Log.error(errorMsg, category: LogCategory.system);
        return NIP17SendResult.failure(errorMsg);
      }

      // NIP-17: publish a self-addressed gift wrap so our own sent messages
      // are recoverable from relays after reinstall or data loss.
      // Wrapped in its own try-catch because the message was already
      // delivered to the recipient — self-wrap failure is non-fatal.
      try {
        final selfWrapEvent = await GiftWrapUtil.getGiftWrapEvent(
          nostr,
          rumorEvent,
          _senderPublicKey,
        );
        if (selfWrapEvent != null) {
          await _nostrService.publishEvent(selfWrapEvent);
        }
      } catch (e) {
        Log.error(
          'Self-wrap failed (non-fatal): $e',
          category: LogCategory.system,
        );
      }

      Log.info(
        'Successfully published NIP-17 message',
        category: LogCategory.system,
      );
      return NIP17SendResult.success(
        rumorEventId: rumorEvent.id,
        messageEventId: giftWrapEvent.id,
        recipientPubkey: recipientPubkey,
      );
    } catch (e, stackTrace) {
      Log.error(
        'Failed to send NIP-17 message: $e',
        category: LogCategory.system,
        error: e,
        stackTrace: stackTrace,
      );
      return NIP17SendResult.failure('Failed to send message: $e');
    }
  }

  /// Dummy relay generator - we don't use relays in this Nostr instance
  /// Only needed for Nostr constructor, but not actually called
  Relay _dummyRelayGenerator(String url) {
    throw UnimplementedError(
      'Relay generation not needed for signing-only Nostr instance',
    );
  }
}
