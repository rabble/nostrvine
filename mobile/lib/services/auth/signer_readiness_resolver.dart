// ABOUTME: Resolves signer readiness from identity and observable RPC state.
// ABOUTME: Keeps temporary warm-up distinct from permanent unavailability.

import 'package:openvine/models/auth_rpc_capability.dart';
import 'package:openvine/models/signer_readiness.dart';
import 'package:openvine/services/auth/nostr_identity.dart';

SignerReadiness resolveSignerReadiness(
  NostrIdentity? identity,
  AuthRpcCapability rpcCapability, {
  bool rpcCapabilityInitialized = true,
}) => switch (identity) {
  null => SignerReadiness.pending,
  LocalNostrIdentity() => SignerReadiness.ready,
  KeycastNostrIdentity(:final signsWithLocalKey) =>
    signsWithLocalKey
        ? SignerReadiness.ready
        : !rpcCapabilityInitialized
        ? SignerReadiness.pending
        : switch (rpcCapability) {
            AuthRpcCapability.rpcReady => SignerReadiness.ready,
            AuthRpcCapability.upgrading => SignerReadiness.pending,
            AuthRpcCapability.unavailable => SignerReadiness.unavailable,
          },
  PubkeyOnlyNostrIdentity() =>
    !rpcCapabilityInitialized
        ? SignerReadiness.pending
        : switch (rpcCapability) {
            AuthRpcCapability.upgrading => SignerReadiness.pending,
            AuthRpcCapability.unavailable ||
            AuthRpcCapability.rpcReady => SignerReadiness.unavailable,
          },
  AmberNostrIdentity() ||
  BunkerNostrIdentity() ||
  Nip07NostrIdentity() => SignerReadiness.ready,
};
