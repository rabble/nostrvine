// ABOUTME: Capability for building NIP-59 gift wraps server-side in one batch.
// ABOUTME: Lets a remote signer (e.g. Keycast) wrap every recipient in one trip.

/// One index-aligned result slot from a server-side NIP-17 gift-wrap build
/// batch.
///
/// On success it carries the signed kind:1059 [giftWrap] as JSON. On a
/// per-recipient failure it carries an [error] code instead — one bad recipient
/// never fails the whole batch.
class GiftWrapSlot {
  /// A slot whose gift wrap was built successfully.
  const GiftWrapSlot.success(Map<String, dynamic> this.giftWrap) : error = null;

  /// A slot whose gift wrap could not be built, carrying the server's [error]
  /// code (e.g. `invalid_recipient`, `permission_denied`, `encrypt_failed`).
  /// The code set is open: treat any unknown code as a failure rather than
  /// pinning to a fixed list.
  const GiftWrapSlot.failure(String this.error) : giftWrap = null;

  /// The signed kind:1059 gift wrap as JSON, or `null` on failure.
  final Map<String, dynamic>? giftWrap;

  /// The per-recipient error code, or `null` on success.
  final String? error;

  /// Whether this slot produced a gift wrap.
  bool get isSuccess => error == null && giftWrap != null;
}

/// A signer that can build NIP-59 gift wraps server-side in a single batched
/// round trip, rather than a `nip44Encrypt` + `signEvent` pair per wrap.
///
/// Signers that cannot do this simply do not implement the interface; callers
/// detect support with `signer is GiftWrapBatchWrapper` and fall back to the
/// per-wrap build path when it is absent.
abstract interface class GiftWrapBatchWrapper {
  /// Wraps one shared [rumor] — an unsigned NIP-17 rumor as JSON — for
  /// [recipientPubkeys] (hex), returning ordered, index-aligned [GiftWrapSlot]s.
  ///
  /// Every slot seals the SAME rumor, so the rumor id is shared across them;
  /// receiver-side dedup and the durable outgoing queue both key on it.
  ///
  /// Returns `null` when the server does not expose the verb (an older
  /// backend), so the caller can stop asking and use the per-wrap path.
  ///
  /// Throws for every other failure — a transient server error, an expired
  /// token, a request-level rejection, or a [TimeoutException]. Callers must
  /// treat a throw as "fall back for this send" and NOT as "the verb is
  /// missing": collapsing the two would let one blip permanently demote a
  /// session to the slow path.
  Future<List<GiftWrapSlot>?> nip17WrapBatch(
    Map<String, dynamic> rumor,
    List<String> recipientPubkeys,
  );
}
