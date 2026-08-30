// ABOUTME: Resolves signer readiness from identity and observable RPC state.
// ABOUTME: Keeps temporary warm-up distinct from permanent unavailability.

import 'package:openvine/models/auth_rpc_capability.dart';
import 'package:openvine/models/signer_readiness.dart';
import 'package:openvine/services/auth/nostr_identity.dart';

SignerReadiness resolveSignerReadiness(
  NostrIdentity? identity,
  AuthRpcCapability rpcCapability,
) => switch (identity) {
  null => SignerReadiness.pending,
  LocalNostrIdentity() => SignerReadiness.ready,
  KeycastNostrIdentity(:final signsWithLocalKey) =>
    signsWithLocalKey
        ? SignerReadiness.ready
        : switch (rpcCapability) {
            AuthRpcCapability.rpcReady => SignerReadiness.ready,
            AuthRpcCapability.upgrading => SignerReadiness.pending,
            AuthRpcCapability.unavailable => SignerReadiness.unavailable,
          },
  PubkeyOnlyNostrIdentity() => switch (rpcCapability) {
    AuthRpcCapability.upgrading => SignerReadiness.pending,
    AuthRpcCapability.unavailable ||
    AuthRpcCapability.rpcReady => SignerReadiness.unavailable,
  },
  AmberNostrIdentity() ||
  BunkerNostrIdentity() ||
  Nip07NostrIdentity() => SignerReadiness.ready,
};
