// ABOUTME: Enum representing the state of remote Keycast RPC availability
// ABOUTME: Used to decouple local identity readiness from remote signer warmup

/// The availability of remote Keycast RPC signing.
///
/// This is separate from [AuthState] intentionally — the router only needs
/// to know whether the user is authenticated, while downstream code
/// (likes, reposts, follows) needs to know whether writes can be signed
/// right now or should be queued optimistically.
enum AuthRpcCapability {
  /// No RPC session exists or has ever been attempted.
  unavailable,

  /// A local identity is active and a background RPC upgrade is in progress.
  upgrading,

  /// RPC is fully available — the Keycast signer can sign remotely.
  rpcReady,
}
