// ABOUTME: Service for sending encrypted NIP-17 (gift-wrapped) private messages
// ABOUTME: Handles three-layer encryption
// ABOUTME: (kind 14 rumor → kind 13 seal → kind 1059 gift wrap)
// ABOUTME: Works with any NostrSigner (local keys, Keycast RPC, Amber, etc.)

import 'package:meta/meta.dart';
import 'package:models/models.dart' show NIP17SendResult;
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/event_kind.dart';
import 'package:nostr_sdk/nip59/gift_wrap_util.dart';
import 'package:nostr_sdk/nostr.dart';
import 'package:nostr_sdk/relay/relay.dart';
import 'package:nostr_sdk/signer/nostr_signer.dart';
import 'package:unified_logger/unified_logger.dart';

/// Builds a NIP-59 gift-wrapped event for [recipientPubkey] from
/// [rumorEvent], using [nostr] for signing. Returns `null` when the
/// underlying SDK declines to produce one (e.g. an internal encryption
/// step yields a null result without throwing).
///
/// Defaults to [GiftWrapUtil.getGiftWrapEvent]; injectable for tests
/// so the `null`-return branch in [NIP17MessageService] can be
/// exercised without conjuring valid gift-wrapped events by hand.
@internal
typedef GiftWrapBuilder =
    Future<Event?> Function(
      Nostr nostr,
      Event rumorEvent,
      String recipientPubkey,
    );

/// Service for sending encrypted private messages using NIP-17 gift wrapping.
///
/// Accepts any [NostrSigner] implementation, supporting both local key
/// signing and remote signing (e.g. Keycast RPC, Amber).
class NIP17MessageService {
  /// Creates a [NIP17MessageService] with the given dependencies.
  NIP17MessageService({
    required NostrSigner signer,
    required String senderPublicKey,
    required NostrClient nostrService,
    @visibleForTesting GiftWrapBuilder? giftWrapBuilder,
  }) : _signer = signer,
       _senderPublicKey = senderPublicKey,
       _nostrService = nostrService,
       _giftWrapBuilder = giftWrapBuilder ?? GiftWrapUtil.getGiftWrapEvent;

  final NostrSigner _signer;
  final String _senderPublicKey;
  final NostrClient _nostrService;
  final GiftWrapBuilder _giftWrapBuilder;

  /// Access to the underlying NostrService for relay management
  NostrClient get nostrService => _nostrService;

  /// Build the unsigned NIP-17 rumor event for a 1:1 send.
  ///
  /// Pure construction — does not touch relays or the signer. Exposed
  /// separately from [sendRumor] so the repository can persist the
  /// rumor (or its serialized JSON) into the durable outgoing-DM queue
  /// **before** publishing, keyed by the rumor's id. Without this split
  /// a publish that succeeds with the recipient relay but the app
  /// crashes before [sendPrivateMessage] returns leaves no local
  /// trace of the in-flight send.
  ///
  /// Parameters:
  /// - [recipientPubkey]: Recipient's public key (hex format)
  /// - [content]: Message content (text for kind 14, file URL for kind 15)
  /// - [eventKind]: The rumor event kind (14 = text, 15 = file)
  /// - [additionalTags]: Optional tags to include in the rumor event
  Event buildRumor({
    required String recipientPubkey,
    required String content,
    int eventKind = EventKind.privateDirectMessage,
    List<List<String>> additionalTags = const [],
  }) {
    final rumorTags = <List<String>>[
      ['p', recipientPubkey],
      ...additionalTags,
    ];

    return Event(_senderPublicKey, eventKind, rumorTags, content);
  }

  /// Wrap and publish a pre-built [rumorEvent] to the recipient and to
  /// ourselves (self-addressed gift wrap for cross-device recovery).
  ///
  /// Self-wrap failure is intentionally non-fatal — the message has
  /// already been delivered to the recipient at that point, and
  /// blocking the success result on the self-wrap would cause the
  /// repository to mark a successfully-delivered message as failed and
  /// retry the recipient publish, double-delivering. A future revision
  /// (PR #3910) will surface the self-wrap outcome separately so the
  /// repository can mark each wrap status independently.
  Future<NIP17SendResult> sendRumor({
    required Event rumorEvent,
    required String recipientPubkey,
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

      Log.debug(
        'Wrapping kind ${rumorEvent.kind} rumor event',
        category: LogCategory.system,
      );

      // Create gift wrap for the recipient
      final giftWrapEvent = await _giftWrapBuilder(
        nostr,
        rumorEvent,
        recipientPubkey,
      );

      if (giftWrapEvent == null) {
        return const NIP17SendResult.failure(
          'Failed to create gift wrap event',
        );
      }

      Log.debug(
        'Created recipient gift wrap with ephemeral key: '
        '${giftWrapEvent.pubkey}',
        category: LogCategory.system,
      );

      // Publish the recipient's gift wrap
      final sentEvent = await _nostrService.publishEvent(giftWrapEvent);

      if (sentEvent is! PublishSuccess) {
        const errorMsg = 'Message publish failed to relays';
        Log.error(errorMsg, category: LogCategory.system);
        return const NIP17SendResult.failure(errorMsg);
      }

      // NIP-17: publish a self-addressed gift wrap so our own sent
      // messages are recoverable from relays after reinstall or data
      // loss. Three independent failure modes — track them separately
      // so the result can distinguish recipient-only delivery from
      // full delivery. Re-publishing the recipient wrap would
      // double-deliver, so any future retry handling must target only
      // the self-wrap (see #3909).
      var selfWrapPublished = false;
      try {
        final selfWrapEvent = await _giftWrapBuilder(
          nostr,
          rumorEvent,
          _senderPublicKey,
        );
        if (selfWrapEvent == null) {
          Log.warning(
            'Self-wrap creation returned null — recipient was '
            'delivered, but the sender will not see this message on '
            'other devices or after a reinstall.',
            category: LogCategory.system,
          );
        } else {
          final published = await _nostrService.publishEvent(selfWrapEvent);
          if (published is! PublishSuccess) {
            Log.warning(
              'Self-wrap publish failed — recipient was '
              'delivered, but the sender will not see this message on '
              'other devices or after a reinstall.',
              category: LogCategory.system,
            );
          } else {
            selfWrapPublished = true;
          }
        }
      } on Object catch (e) {
        Log.error(
          'Self-wrap failed (non-fatal): recipient was delivered, but '
          'the sender will not see this message on other devices or '
          'after a reinstall: $e',
          category: LogCategory.system,
        );
      }

      Log.info(
        'Successfully published NIP-17 message '
        '(selfWrapPublished=$selfWrapPublished)',
        category: LogCategory.system,
      );
      return NIP17SendResult.success(
        rumorEventId: rumorEvent.id,
        messageEventId: giftWrapEvent.id,
        recipientPubkey: recipientPubkey,
        selfWrapPublished: selfWrapPublished,
      );
    } on Object catch (e, stackTrace) {
      Log.error(
        'Failed to send NIP-17 message: $e',
        category: LogCategory.system,
        error: e,
        stackTrace: stackTrace,
      );
      return NIP17SendResult.failure('Failed to send message: $e');
    }
  }

  /// Convenience wrapper that builds a rumor and sends it in one call.
  ///
  /// Existing callers (group sends, file sends, NIP-04 fallback wiring)
  /// keep working unchanged. New callers that need to enqueue a durable
  /// queue row keyed by the rumor's id should call [buildRumor] +
  /// [sendRumor] directly so the queue insert happens between the two.
  Future<NIP17SendResult> sendPrivateMessage({
    required String recipientPubkey,
    required String content,
    int eventKind = EventKind.privateDirectMessage,
    List<List<String>> additionalTags = const [],
  }) async {
    final rumor = buildRumor(
      recipientPubkey: recipientPubkey,
      content: content,
      eventKind: eventKind,
      additionalTags: additionalTags,
    );
    return sendRumor(
      rumorEvent: rumor,
      recipientPubkey: recipientPubkey,
    );
  }

  /// Dummy relay generator - we don't use relays in this Nostr instance
  /// Only needed for Nostr constructor, but not actually called
  Relay _dummyRelayGenerator(String url) {
    throw UnimplementedError(
      'Relay generation not needed for signing-only Nostr instance',
    );
  }
}
