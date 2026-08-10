// ABOUTME: Injectable outbound-DM policy for NIP17MessageService (#176). The
// ABOUTME: DM package can't reach app state (Riverpod), so the protected-minor
// ABOUTME: decision is injected as a policy the send primitives consult.

/// Result of evaluating the outbound-DM policy for one recipient.
enum DmSendPolicyDecision {
  /// The send may proceed.
  allowed,

  /// Fail closed for now, but the missing account-state verdict may resolve.
  temporarilyBlocked,

  /// A confirmed policy blocks this recipient — the send can never succeed.
  ///
  /// The reason is deliberately not carried here: the app owns the policy and
  /// therefore owns the copy. A caller that needs to explain the refusal
  /// re-derives it from the recipient it already holds.
  terminallyBlocked,
}

/// Decides whether the current sender may deliver a DM to [recipientPubkey].
///
/// The default is [allowAllDmSendPolicy]; the app injects a policy that refuses
/// recipients its own rules forbid — a protected minor DMing outside the
/// approved official set, or anyone addressing an identity the product has
/// retired. It is consulted at the lowest send primitive so every publisher
/// (direct, group fan-out, drain replay, reactions, file) is covered at one
/// seam. Temporary fail-closed denials remain distinguishable from confirmed
/// terminal blocks, so a cold-start queue drain cannot delete a legitimate
/// queued send.
typedef DmSendPolicy =
    Future<DmSendPolicyDecision> Function(String recipientPubkey);

/// Default policy: no restriction. Preserves existing behavior wherever no
/// policy is injected.
Future<DmSendPolicyDecision> allowAllDmSendPolicy(
  String recipientPubkey,
) async => DmSendPolicyDecision.allowed;
