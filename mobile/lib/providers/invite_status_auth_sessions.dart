// ABOUTME: Bridges auth signer capability into invite status.
// ABOUTME: Feeds InviteStatusCubit a push signal for late RPC readiness.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/blocs/invite_status/invite_status_cubit.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/providers/provider_identity_stream.dart';

/// Current auth session for invite status.
///
/// Invite status uses NIP-98 over the REST invite API. That requires an
/// authenticated identity that can sign now, but it does not require the
/// app-wide `NostrClient` to finish relay initialization.
final inviteStatusAuthSessionProvider = Provider<InviteStatusAuthSession>((
  ref,
) {
  final authService = ref.watch(authServiceProvider);
  ref.watch(currentAuthStateProvider);
  ref.watch(currentAuthRpcCapabilityProvider);

  return InviteStatusAuthSession(
    accountId: authService.currentPublicKeyHex,
    isSignerReady: authService.canPublishNostrWritesNow,
  );
});

/// Session updates for [InviteStatusCubit].
///
/// Reads from [inviteStatusAuthSessionProvider] rather than `authStateStream`
/// alone: auth state only says the identity is known, and a Keycast signer with
/// no local key becomes usable on the RPC-capability signal (#6977). The cubit
/// asks once and then waits for a push, so watching only auth state strands it.
final Provider<Stream<InviteStatusAuthSession>>
inviteStatusAuthSessionsProvider = identityStreamOf<InviteStatusAuthSession>(
  inviteStatusAuthSessionProvider,
);
