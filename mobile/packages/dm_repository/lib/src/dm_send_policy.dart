// ABOUTME: Injectable outbound-DM policy for NIP17MessageService (#176). The
// ABOUTME: DM package can't reach app state (Riverpod), so the protected-minor
// ABOUTME: decision is injected as a policy the send primitives consult.

/// Decides whether the current sender may deliver a DM to [recipientPubkey].
///
/// The default is [allowAllDmSendPolicy]; the app injects a policy that blocks
/// a protected minor from DMing anyone outside the approved official set. It is
/// consulted at the lowest send primitive so every publisher (direct, group
/// fan-out, drain replay, reactions, file) is covered at one seam.
typedef DmSendPolicy = Future<bool> Function(String recipientPubkey);

/// Default policy: no restriction. Preserves existing behavior wherever no
/// policy is injected.
Future<bool> allowAllDmSendPolicy(String recipientPubkey) async => true;
