// ABOUTME: Service for sending encrypted NIP-17 (gift-wrapped) private messages
// ABOUTME: Handles three-layer encryption
// ABOUTME: (kind 14 rumor → kind 13 seal → kind 1059 gift wrap)
// ABOUTME: Works with any NostrSigner (local keys, Keycast RPC, Amber, etc.)

import 'package:dm_repository/src/dm_send_policy.dart';
import 'package:dm_repository/src/gift_wrap_build_worker.dart';
import 'package:flutter/foundation.dart' show compute;
import 'package:meta/meta.dart';
import 'package:models/models.dart' show NIP17SendResult;
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/event_kind.dart';
import 'package:nostr_sdk/nip59/gift_wrap_util.dart';
import 'package:nostr_sdk/nostr.dart';
import 'package:nostr_sdk/relay/relay.dart';
import 'package:nostr_sdk/signer/isolate_decrypt_signer.dart';
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

/// Builds NIP-17 gift wraps off the main isolate for local-key signers.
///
/// Defaults to running [buildGiftWrapBatch] in a [compute] isolate; injectable
/// for tests so the offload branch can be exercised inline without spawning a
/// real isolate.
@internal
typedef IsolateGiftWrapBatchBuilder =
    Future<List<BuiltGiftWrapResult>> Function(BuildGiftWrapRequest request);

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
    DmSendPolicy? sendPolicy,
    @visibleForTesting GiftWrapBuilder? giftWrapBuilder,
    @visibleForTesting IsolateGiftWrapBatchBuilder? isolateGiftWrapBatchBuilder,
  }) : _signer = signer,
       _senderPublicKey = senderPublicKey,
       _nostrService = nostrService,
       _sendPolicy = sendPolicy ?? allowAllDmSendPolicy,
       _giftWrapBuilder = giftWrapBuilder ?? GiftWrapUtil.getGiftWrapEvent,
       _isolateGiftWrapBatchBuilder =
           isolateGiftWrapBatchBuilder ?? _computeGiftWrapBatch;

  final NostrSigner _signer;
  final String _senderPublicKey;
  final NostrClient _nostrService;
  final DmSendPolicy _sendPolicy;
  final GiftWrapBuilder _giftWrapBuilder;
  final IsolateGiftWrapBatchBuilder _isolateGiftWrapBatchBuilder;

  /// Default off-main-isolate builder: runs [buildGiftWrapBatch] in a
  /// [compute] isolate. Kept as a static tear-off so the constructor's
  /// default does not capture instance state.
  static Future<List<BuiltGiftWrapResult>> _computeGiftWrapBatch(
    BuildGiftWrapRequest request,
  ) => compute(buildGiftWrapBatch, request);

  /// Access to the underlying NostrService for relay management
  NostrClient get nostrService => _nostrService;

  /// Whether the injected [DmSendPolicy] permits delivering to
  /// [recipientPubkey]. Exposed so `DmRepository` can gate BEFORE enqueue
  /// (avoid storing a doomed intent) and enforce group all-or-nothing before
  /// any per-recipient send. The per-send gate in [sendRumor] remains the
  /// authoritative choke point (covers the drain replay); this is the earlier,
  /// cheaper check.
  Future<bool> canSendTo(String recipientPubkey) =>
      _sendPolicy(recipientPubkey);

  /// Builds a single NIP-17 gift wrap for [receiverPublicKey] from
  /// [rumorEvent].
  ///
  /// Routes through a [compute] isolate when the signer can safely expose its
  /// private key bytes (local-key signers), keeping the CPU-bound pure-Dart
  /// secp256k1 work off the UI isolate. Remote signers (Amber, Keycast RPC,
  /// NIP-46) cannot cross a `SendPort`, so they fall back to the
  /// on-main-isolate [_giftWrapBuilder] — already async RPC/IPC, not a block.
  ///
  /// Any failure of the isolate path (thrown error, null/failed result) falls
  /// back to the main-isolate builder, mirroring the receive-side decrypt
  /// offload in DmRepository. See #5391.
  Future<Event?> _buildWrap({
    required Nostr nostr,
    required Event rumorEvent,
    required String receiverPublicKey,
  }) async {
    final signer = _signer;
    if (signer is IsolateDecryptSigner && signer.canDecryptInIsolate) {
      try {
        final hex = signer.withPrivateKeyHex((k) => k);
        final results = await _isolateGiftWrapBatchBuilder(
          BuildGiftWrapRequest(
            privateKeyHex: hex,
            rumorJson: rumorEvent.toJson(),
            receiverPublicKeys: [receiverPublicKey],
          ),
        );
        final result = results.single;
        if (result.isSuccess) {
          return Event.fromJson(result.giftWrap!);
        }
        Log.debug(
          'Isolate gift-wrap build returned failure for rumor '
          '${rumorEvent.id}: ${result.error}; falling back to main isolate',
          category: LogCategory.system,
        );
      } on Object catch (e, stackTrace) {
        Log.error(
          'Isolate gift-wrap build threw for rumor ${rumorEvent.id}: $e',
          category: LogCategory.system,
          error: e,
          stackTrace: stackTrace,
        );
        // Fall through to the main-isolate builder below.
      }
    }
    return _giftWrapBuilder(nostr, rumorEvent, receiverPublicKey);
  }

  /// Builds the recipient and self-addressed gift wraps in a single isolate
  /// hop for local-key signers (one [compute] spawn covers both receivers,
  /// halving the spawn cost vs two separate [_buildWrap] calls).
  ///
  /// Returns `(recipientWrap, selfWrap?)`. For remote signers — or if the
  /// batch isolate call fails — only the recipient wrap is built here and
  /// `selfWrap` is `null`; [_publishSelfWrap] then builds the self-wrap
  /// lazily after the recipient publish confirms delivery (avoids an extra
  /// signing round-trip on publish failure).
  ///
  /// Security: `withPrivateKeyHex((k) => k)` copies the raw private-key hex
  /// out of its scoped callback so it can be serialised across the [compute]
  /// isolate boundary. This matches the receive-side pattern in
  /// `DmRepository._decryptRumor`. The key is already in the main-isolate
  /// heap; the threat model for this copy is identical to the attacker who
  /// can already read the heap. The isolate is short-lived and the key does
  /// not persist beyond the call.
  Future<(Event?, Event?)> _buildBothWraps({
    required Nostr nostr,
    required Event rumorEvent,
    required String recipientPubkey,
  }) async {
    final signer = _signer;
    if (signer is IsolateDecryptSigner && signer.canDecryptInIsolate) {
      try {
        final hex = signer.withPrivateKeyHex((k) => k);
        final results = await _isolateGiftWrapBatchBuilder(
          BuildGiftWrapRequest(
            privateKeyHex: hex,
            rumorJson: rumorEvent.toJson(),
            receiverPublicKeys: [recipientPubkey, _senderPublicKey],
          ),
        );
        if (results.length == 2) {
          final r = results[0];
          final s = results[1];
          if (!r.isSuccess) {
            Log.debug(
              'Batch gift-wrap: recipient slot failed (${r.error}); '
              'falling back to main-isolate builder',
              category: LogCategory.system,
            );
          }
          if (!s.isSuccess) {
            Log.debug(
              'Batch gift-wrap: self-wrap slot failed (${s.error}); '
              '_publishSelfWrap will rebuild on the main isolate',
              category: LogCategory.system,
            );
          }
          return (
            r.isSuccess ? Event.fromJson(r.giftWrap!) : null,
            s.isSuccess ? Event.fromJson(s.giftWrap!) : null,
          );
        }
        Log.debug(
          'Batch gift-wrap returned unexpected result count '
          '(${results.length}); falling back to main-isolate builder',
          category: LogCategory.system,
        );
      } on Object catch (e, stackTrace) {
        Log.error(
          'Batch gift-wrap build threw for rumor ${rumorEvent.id}: $e; '
          'falling back to main-isolate builder',
          category: LogCategory.system,
          error: e,
          stackTrace: stackTrace,
        );
      }
    }
    // Remote signer or batch failed: build only the recipient wrap. The
    // self-wrap is built lazily by _publishSelfWrap after the recipient
    // publish confirms delivery — avoids an extra signing round-trip for
    // remote signers when the recipient publish fails.
    return (
      await _buildWrap(
        nostr: nostr,
        rumorEvent: rumorEvent,
        receiverPublicKey: recipientPubkey,
      ),
      null,
    );
  }

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

  /// OK-confirmation window for the recipient wrap when [sendRumor] runs
  /// with `awaitRecipientOk: true` (reaction sends). Kept under the reaction
  /// path's outer 15 s publish cap so the confirmation resolves with headroom
  /// for the subsequent self-wrap before the caller's timeout fires.
  static const Duration _recipientOkConfirmTimeout = Duration(seconds: 10);

  /// Wrap and publish a pre-built [rumorEvent] to the recipient and to
  /// ourselves (self-addressed gift wrap for cross-device recovery).
  ///
  /// When [awaitRecipientOk] is `true`, the recipient wrap publish requires
  /// the relay's NIP-20 `OK true` before it counts as landed, instead of the
  /// default frame-accept. A bare frame-accept is a false positive on a flaky
  /// single relay — it reports success even though the relay never stored the
  /// event — so reaction sends (which have no durable message-style retry
  /// queue) opt in to confirmation. Message sends keep the default.
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
    List<String>? targetRelays,
    bool awaitRecipientOk = false,
  }) async {
    try {
      // Send gate (#176): the lowest recipient-delivering primitive, so every
      // publisher — direct send, group fan-out, drain replay, reactions,
      // file — is covered at one seam. A protected minor's policy blocks any
      // recipient outside the approved official set. Checked before any wrap
      // build or publish, so a blocked send leaks no metadata to relays and
      // performs no signing work.
      if (!await _sendPolicy(recipientPubkey)) {
        Log.info(
          'NIP-17 send blocked by policy for recipient',
          category: LogCategory.system,
        );
        return const NIP17SendResult.blocked(
          'blocked: recipient not permitted by send policy',
        );
      }

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

      // Build recipient and self-addressed gift wraps. For local-key signers
      // both are built in one isolate hop (half the spawn cost vs two separate
      // calls); for remote signers the self-wrap is deferred to
      // _publishSelfWrap after the recipient publish confirms delivery.
      final (giftWrapEvent, prebuiltSelfWrap) = await _buildBothWraps(
        nostr: nostr,
        rumorEvent: rumorEvent,
        recipientPubkey: recipientPubkey,
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

      // Publish the recipient's gift wrap. Route it to the recipient's
      // NIP-17 kind-10050 DM inbox relays when known (so non-diVine users
      // who only read their own inbox relays actually receive it); fall
      // back to the default pool otherwise. The no-targetRelays call shape
      // is kept identical to preserve existing behavior.
      if (awaitRecipientOk) {
        // OK-confirm path (reactions): require the relay's NIP-20 OK before
        // reporting delivery, but keep this device's own durability
        // independent of it.
        final outcome = (targetRelays != null && targetRelays.isNotEmpty)
            ? await _nostrService.publishEventAwaitOk(
                giftWrapEvent,
                targetRelays: targetRelays,
                timeout: _recipientOkConfirmTimeout,
              )
            : await _nostrService.publishEventAwaitOk(
                giftWrapEvent,
                timeout: _recipientOkConfirmTimeout,
              );

        // Classify the outcome BEFORE deciding on the self-wrap. Three cases:
        //  * explicit OK-false → hard rejection: the recipient definitely did
        //    not get it.
        //  * nothing reached any relay (offline) → the send definitively did
        //    not happen.
        //  * frame written to a relay but no OK within the window →
        //    inconclusive soft-unconfirmed; it may already be delivered.
        final rejected = outcome.rejectedBy.isNotEmpty;
        final reachedNoRelay =
            outcome.acceptedBy.isEmpty &&
            outcome.rejectedBy.isEmpty &&
            outcome.noResponseFrom.isEmpty;
        final softUnconfirmed = !rejected && !reachedNoRelay;

        // Publish the self-addressed wrap ONLY when the recipient confirmed OR
        // the send is soft-unconfirmed (frame written, OK lost/late — the
        // recipient may already have the reaction). On a hard rejection or an
        // offline no-relay-reached the recipient definitely did not get it, so
        // a self-wrap would surface a phantom reaction on the sender's other
        // devices / reinstall (ingested via persistIncoming as a plain
        // `received` row with no retry metadata). The self-wrap is p-tagged to
        // the sender only, so publishing it on a soft-unconfirmed send never
        // double-delivers to the counterparty.
        // Short-circuit `&&`: when the gate is false the self-wrap publish is
        // never awaited, so it is skipped entirely on rejected / reachedNoRelay.
        final selfWrapPublished =
            (outcome.confirmed || softUnconfirmed) &&
            await _publishSelfWrap(
              nostr: nostr,
              rumorEvent: rumorEvent,
              prebuiltSelfWrap: prebuiltSelfWrap,
            );

        if (outcome.confirmed) {
          Log.info(
            'Successfully published NIP-17 reaction '
            '(selfWrapPublished=$selfWrapPublished)',
            category: LogCategory.system,
          );
          return NIP17SendResult.success(
            rumorEventId: rumorEvent.id,
            messageEventId: giftWrapEvent.id,
            recipientPubkey: recipientPubkey,
            selfWrapPublished: selfWrapPublished,
          );
        }

        // Not confirmed. The caller's chip + retry follow from the sub-case:
        //  * rejected → mark failed (terminal-ish; failed rows skip the sweep's
        //    in-flight min-age guard so they re-drive immediately).
        //  * reachedNoRelay (offline) → mark failed so the sweep re-drives it
        //    the instant connectivity returns.
        //  * softUnconfirmed → keep a dim, sweep-retryable 'pending' chip
        //    (a lost OK is not proof of loss).
        final String errorMsg;
        if (rejected) {
          errorMsg = 'Reaction rejected by relay: ${outcome.summary}';
        } else if (reachedNoRelay) {
          errorMsg = 'Reaction not sent: no relay reached';
        } else {
          errorMsg = 'Reaction recipient OK unconfirmed: ${outcome.summary}';
        }
        Log.warning(
          'NIP-17 reaction recipient publish unconfirmed '
          '(rumor=${rumorEvent.id}, recipient=$recipientPubkey, '
          '${outcome.summary}); selfWrapPublished=$selfWrapPublished',
          category: LogCategory.system,
        );
        return NIP17SendResult.failure(
          errorMsg,
          retryablePending: softUnconfirmed,
        );
      }

      // Frame-accept path (messages): a WebSocket-accepted frame counts as
      // sent, and the self-wrap runs only after the recipient publish lands.
      final sentEvent = (targetRelays != null && targetRelays.isNotEmpty)
          ? await _nostrService.publishEvent(
              giftWrapEvent,
              targetRelays: targetRelays,
            )
          : await _nostrService.publishEvent(giftWrapEvent);

      if (sentEvent is! PublishSuccess) {
        const errorMsg = 'Message publish failed to relays';
        Log.error(
          '$errorMsg (rumor=${rumorEvent.id}, recipient=$recipientPubkey)',
          category: LogCategory.system,
        );
        return const NIP17SendResult.failure(errorMsg);
      }

      // NIP-17: publish a self-addressed gift wrap so our own sent
      // messages are recoverable from relays after reinstall or data
      // loss. The recipient already received the message at this
      // point, so a self-wrap failure must never bubble up — the
      // helper catches everything and reports the per-wrap status
      // separately. Re-publishing the recipient wrap would
      // double-deliver, so the recovery path uses [publishSelfWrap]
      // to retry only the missing self-wrap.
      final selfWrapPublished = await _publishSelfWrap(
        nostr: nostr,
        rumorEvent: rumorEvent,
        prebuiltSelfWrap: prebuiltSelfWrap,
      );

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
        'Failed to send NIP-17 message '
        '(rumor=${rumorEvent.id}, recipient=$recipientPubkey): $e',
        category: LogCategory.system,
        error: e,
        stackTrace: stackTrace,
      );
      return NIP17SendResult.failure('Failed to send message: $e');
    }
  }

  /// Publish only the sender self-addressed gift wrap for an
  /// already-sent [rumorEvent].
  ///
  /// Used by the recovery path when a previous [sendRumor] delivered
  /// to the recipient (the recipient kind 1059 wrap landed) but the
  /// self-addressed wrap did not. Re-running [sendRumor] would publish
  /// the recipient wrap a second time and double-deliver, so the
  /// recovery path goes through this method instead. Receiver-side
  /// dedup keys on the rumor event id, so callers must pass the same
  /// rumor that was published originally — rebuilding it from the
  /// queue's `rumor_event_json` preserves the id, minting a fresh
  /// rumor would not.
  ///
  /// Returns [NIP17SendResult.success] on a successful self-wrap
  /// publish (the `messageEventId` slot carries the rumor id since no
  /// new recipient-wrap event id is produced on this path) or
  /// [NIP17SendResult.failure] when the self-wrap could not be built
  /// or did not reach a relay.
  Future<NIP17SendResult> publishSelfWrap({required Event rumorEvent}) async {
    try {
      Log.info(
        'Publishing self-addressed NIP-17 gift wrap for rumor recovery',
        category: LogCategory.system,
      );

      final nostr = Nostr(_signer, [], _dummyRelayGenerator);
      await nostr.refreshPublicKey();

      final published = await _publishSelfWrap(
        nostr: nostr,
        rumorEvent: rumorEvent,
      );
      if (!published) {
        return const NIP17SendResult.failure('Self-wrap publish failed');
      }
      return NIP17SendResult.success(
        rumorEventId: rumorEvent.id,
        messageEventId: rumorEvent.id,
        recipientPubkey: _senderPublicKey,
      );
    } on Object catch (e, stackTrace) {
      Log.error(
        'Failed to publish self-wrap recovery: $e',
        category: LogCategory.system,
        error: e,
        stackTrace: stackTrace,
      );
      return NIP17SendResult.failure('Failed to publish self-wrap: $e');
    }
  }

  /// Build and publish the sender self-addressed gift wrap for
  /// [rumorEvent]. Returns `true` when the wrap reached at least one
  /// relay.
  ///
  /// When [prebuiltSelfWrap] is non-null (supplied by [_buildBothWraps] on
  /// the local-key-signer path), the build step is skipped and the prebuilt
  /// event is published directly. Otherwise the wrap is built via
  /// [_buildWrap] on the main isolate.
  ///
  /// Catches every error — used by both the happy-path send (where the
  /// recipient has already received the message and an exception must
  /// not crash the result) and the recovery path (where an exception
  /// is just another failure mode the caller surfaces).
  Future<bool> _publishSelfWrap({
    required Nostr nostr,
    required Event rumorEvent,
    Event? prebuiltSelfWrap,
  }) async {
    try {
      final selfWrapEvent =
          prebuiltSelfWrap ??
          await _buildWrap(
            nostr: nostr,
            rumorEvent: rumorEvent,
            receiverPublicKey: _senderPublicKey,
          );
      if (selfWrapEvent == null) {
        Log.warning(
          'Self-wrap creation returned null — the sender will not see '
          'this message on other devices or after a reinstall.',
          category: LogCategory.system,
        );
        return false;
      }
      final published = await _nostrService.publishEvent(selfWrapEvent);
      if (published is! PublishSuccess) {
        Log.warning(
          'Self-wrap publish failed — the sender will not see this '
          'message on other devices or after a reinstall.',
          category: LogCategory.system,
        );
        return false;
      }
      return true;
    } on Object catch (e) {
      Log.error(
        'Self-wrap failed (non-fatal): the sender will not see this '
        'message on other devices or after a reinstall: $e',
        category: LogCategory.system,
      );
      return false;
    }
  }

  /// Build a kind-[eventKind] rumor with [content] + [tags] and publish it as
  /// a **self-addressed** NIP-59 gift wrap (never to a counterparty) to
  /// [targetRelays] — the user's own DM inbox relays, or the default pool when
  /// `null`/empty. Returns `true` when the wrap reached at least one relay.
  ///
  /// Used for the DM read-state cursor marker (#4977): a kind-30078
  /// application-data rumor whose `content` is the read map. The gift-wrap seal
  /// (kind 13) NIP-44-encrypts it to the user's own key, so the read map is
  /// never world-readable on the (unauthenticated) relay. Self-wrap failure is
  /// non-fatal — a missed marker just means read state is restored on the next
  /// publish.
  Future<bool> publishSelfApplicationMarker({
    required String content,
    required List<List<String>> tags,
    int eventKind = EventKind.appSpecificData,
    List<String>? targetRelays,
  }) async {
    try {
      final nostr = Nostr(_signer, [], _dummyRelayGenerator);
      await nostr.refreshPublicKey();
      final rumor = Event(_senderPublicKey, eventKind, tags, content);
      final selfWrapEvent = await _buildWrap(
        nostr: nostr,
        rumorEvent: rumor,
        receiverPublicKey: _senderPublicKey,
      );
      if (selfWrapEvent == null) return false;
      final published = (targetRelays != null && targetRelays.isNotEmpty)
          ? await _nostrService.publishEvent(
              selfWrapEvent,
              targetRelays: targetRelays,
            )
          : await _nostrService.publishEvent(selfWrapEvent);
      return published is PublishSuccess;
    } on Object catch (e, stackTrace) {
      Log.error(
        'DM read-marker self-wrap failed (non-fatal): $e',
        category: LogCategory.system,
        error: e,
        stackTrace: stackTrace,
      );
      return false;
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
    return sendRumor(rumorEvent: rumor, recipientPubkey: recipientPubkey);
  }

  /// Dummy relay generator - we don't use relays in this Nostr instance
  /// Only needed for Nostr constructor, but not actually called
  Relay _dummyRelayGenerator(String url) {
    throw UnimplementedError(
      'Relay generation not needed for signing-only Nostr instance',
    );
  }
}
