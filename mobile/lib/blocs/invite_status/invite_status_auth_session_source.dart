// ABOUTME: Adapts AuthService identity changes into invite-status sessions.
// ABOUTME: Keeps signer-specific readiness outside InviteStatusCubit.

import 'package:openvine/blocs/invite_status/invite_status_cubit.dart';
import 'package:openvine/services/auth_service.dart';

/// Supplies account-scoped invite authentication sessions from [AuthService].
class InviteStatusAuthSessionSource {
  const InviteStatusAuthSessionSource(this._authService);

  final AuthService _authService;

  /// Current account and generic Nostr signing readiness.
  InviteStatusAuthSession get current => InviteStatusAuthSession(
    accountId: _authService.currentPublicKeyHex,
    isSignerReady: _authService.canPublishNostrWritesNow,
  );

  /// Re-samples [current] whenever the authenticated session changes.
  Stream<InviteStatusAuthSession> get changes =>
      _authService.authStateStream.map((_) => current);
}
