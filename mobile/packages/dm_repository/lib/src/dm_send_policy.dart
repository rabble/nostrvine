// ABOUTME: Injectable outbound-DM policy for NIP17MessageService (#176). The
// ABOUTME: DM package can't reach app state (Riverpod), so the protected-minor
// ABOUTME: decision is injected as a policy the send primitives consult.

/// Result of evaluating the outbound-DM policy for one recipient.
enum DmSendPolicyDecision {
  /// The send may proceed.
  allowed,

  /// Fail closed for now, but the missing account-state verdict may resolve.
  temporarilyBlocked,

  /// A confirmed protected-minor policy blocks this recipient.
  terminallyBlocked,
}

/// Decides whether the current sender may deliver a DM to [recipientPubkey].
///
/// The default is [allowAllDmSendPolicy]; the app injects a policy that blocks
/// a protected minor from DMing anyone outside the approved official set. It is
/// consulted at the lowest send primitive so every publisher (direct, group
/// fan-out, drain replay, reactions, file) is covered at one seam. Temporary
/// fail-closed denials remain distinguishable from confirmed terminal blocks,
/// so a cold-start queue drain cannot delete a legitimate queued send.
typedef DmSendPolicy =
    Future<DmSendPolicyDecision> Function(String recipientPubkey);

/// Default policy: no restriction. Preserves existing behavior wherever no
/// policy is injected.
Future<DmSendPolicyDecision> allowAllDmSendPolicy(
  String recipientPubkey,
) async => DmSendPolicyDecision.allowed;
