// ABOUTME: Top-level function for off-main-isolate NIP-17 gift-wrap BUILD
// ABOUTME: (seal + wrap + sign). Used by NIP17MessageService when the active
// ABOUTME: signer is a local key signer that can safely expose raw private key
// ABOUTME: bytes. Remote signers (Amber, Keycast RPC, NIP-46) keep building on
// ABOUTME: the main isolate because they cannot cross an isolate boundary.
// ABOUTME: Send-side twin of dm_decryption_worker.dart. See #5391.

import 'package:nostr_sdk/nip59/gift_wrap_util.dart';

/// Input payload for [buildGiftWrapBatch].
///
/// All fields are sendable across a Dart isolate boundary: [rumorJson] is a
/// plain JSON map (the output of `Event.toJson`), [privateKeyHex] is a raw hex
/// string extracted from the caller's secure key container under a scoped
/// callback, and [receiverPublicKeys] is a list of hex pubkeys.
class BuildGiftWrapRequest {
  /// Creates a batch gift-wrap build request.
  const BuildGiftWrapRequest({
    required this.privateKeyHex,
    required this.rumorJson,
    required this.receiverPublicKeys,
  });

  /// Hex-encoded sender private key used for NIP-44 ECDH and Schnorr signing.
  final String privateKeyHex;

  /// The unsigned kind-14 rumor as `Event.toJson`; its id is preserved.
  final Map<String, dynamic> rumorJson;

  /// Recipient public keys (hex) to wrap [rumorJson] for, one wrap each.
  final List<String> receiverPublicKeys;
}

/// Per-receiver build result. Either holds the signed gift wrap as JSON (the
/// shape produced by `Event.toJson`) or an error description.
///
/// The batch helper NEVER throws — every failure becomes a
/// [BuiltGiftWrapResult.failure] entry so one bad receiver cannot tank the
/// whole batch.
class BuiltGiftWrapResult {
  const BuiltGiftWrapResult._({this.giftWrap, this.error});

  /// Creates a successful result containing the signed [giftWrap].
  const BuiltGiftWrapResult.success(Map<String, dynamic> giftWrap)
    : this._(giftWrap: giftWrap);

  /// Creates a failure result with the given [error] description.
  const BuiltGiftWrapResult.failure(String error) : this._(error: error);

  /// Signed kind-1059 gift wrap as JSON (null on failure).
  final Map<String, dynamic>? giftWrap;

  /// Human-readable failure reason (null on success).
  final String? error;

  /// Whether this entry represents a successfully built gift wrap.
  bool get isSuccess => giftWrap != null;
}

/// Builds NIP-17 gift wraps (kind 1059) for each receiver in
/// [BuildGiftWrapRequest.receiverPublicKeys], running the full seal + wrap +
/// sign with pure functions so it is safe to invoke inside [compute()].
///
/// Results are returned in the same order as the receiver list. A null wrap
/// from the builder or any thrown error becomes a [BuiltGiftWrapResult.failure]
/// entry — this function never throws.
Future<List<BuiltGiftWrapResult>> buildGiftWrapBatch(
  BuildGiftWrapRequest request,
) async {
  final results = <BuiltGiftWrapResult>[];
  for (final receiver in request.receiverPublicKeys) {
    try {
      final wrap = await buildGiftWrapFromHex(
        senderPrivateKeyHex: request.privateKeyHex,
        rumorJson: request.rumorJson,
        receiverPublicKey: receiver,
      );
      if (wrap == null) {
        results.add(
          const BuiltGiftWrapResult.failure('gift wrap build returned null'),
        );
      } else {
        results.add(BuiltGiftWrapResult.success(wrap.toJson()));
      }
    } on Object catch (e) {
      results.add(BuiltGiftWrapResult.failure('build failed: $e'));
    }
  }
  return results;
}
