// ABOUTME: Capability for unwrapping NIP-59 gift wraps server-side in one batch.
// ABOUTME: Lets a remote signer (e.g. Keycast) unwrap a page in one round trip.

/// One index-aligned result slot from a server-side NIP-17 gift-wrap unwrap
/// batch.
///
/// On success it carries the decrypted kind:14 [rumor] (unsigned event JSON)
/// and the server-authenticated [sender] (the seal signer's pubkey, hex). On a
/// per-item failure it carries an [error] code instead — one bad gift wrap
/// never fails the whole batch.
class GiftWrapUnwrapSlot {
  /// A slot whose gift wrap unwrapped successfully.
  const GiftWrapUnwrapSlot.success({
    required Map<String, dynamic> this.rumor,
    required String this.sender,
  }) : error = null;

  /// A slot whose gift wrap failed to unwrap, carrying the server's [error]
  /// code (e.g. `sender_mismatch`, `decrypt_failed`, `invalid_event`). The code
  /// set is open: treat any unknown code as a failure rather than pinning to a
  /// fixed list.
  const GiftWrapUnwrapSlot.failure(String this.error)
    : rumor = null,
      sender = null;

  /// The decrypted kind:14 rumor as JSON, or `null` on failure.
  final Map<String, dynamic>? rumor;

  /// The authenticated sender (seal signer pubkey, hex), or `null` on failure.
  final String? sender;

  /// The per-item error code, or `null` on success.
  final String? error;

  /// Whether this slot unwrapped successfully.
  bool get isSuccess => error == null && rumor != null && sender != null;
}

/// A signer that can unwrap NIP-59 gift wraps server-side in a single batched
/// round trip per chunk, rather than two `nip44Decrypt` round trips per wrap.
///
/// Signers that cannot do this simply do not implement the interface; callers
/// detect support with `signer is GiftWrapBatchUnwrapper` and fall back to the
/// per-wrap decrypt path when it is absent.
abstract interface class GiftWrapBatchUnwrapper {
  /// Unwraps [giftWraps] — a list of kind:1059 gift-wrap events as JSON — into
  /// ordered, index-aligned [GiftWrapUnwrapSlot]s.
  ///
  /// Returns `null` when the server does not support the verb (e.g. an older
  /// backend), so the caller can fall back to the per-wrap path. May throw
  /// [TimeoutException] when the request times out — callers should treat that
  /// as a transient failure to retry, never as "no messages".
  Future<List<GiftWrapUnwrapSlot>?> nip17UnwrapBatch(
    List<Map<String, dynamic>> giftWraps,
  );
}
