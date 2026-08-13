/// Marker for a [NostrSigner] failure that happened *instead of* the
/// operation, and that is expected to clear on its own.
///
/// Implementing it is a promise about two things at once:
///
/// * **Nothing happened.** The signer produced no signature, ciphertext or
///   plaintext, and no side effect a retry could duplicate.
/// * **It is worth retrying.** The cause is infrastructural — a bounded
///   server giving up, a saturated pool — not a refusal, a policy decision,
///   or bad input, all of which would fail again identically.
///
/// Callers use it to keep durable work retryable instead of terminalizing it.
/// A remote-signer transport that surfaces its own timeout as an *error*
/// rather than as a Dart [TimeoutException] should carry this marker, so the
/// caller classifies it the same way it already classifies running out of
/// patience locally — the two mean the same thing and only differ in which
/// side of the wire noticed first.
///
/// The marker lives on the signer contract rather than in any one transport
/// package so consumers can branch on it without depending on the transport
/// that produced it.
abstract interface class TransientSignerFailure {}
