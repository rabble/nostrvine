// ABOUTME: Shared authorization policy for restoring persisted email verification
// ABOUTME: Keeps startup routing and in-screen rehydration on the same identity rules

import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/pending_verification_service.dart';

/// Whether [pending] may be restored for the active authentication identity.
bool canRestorePendingEmailVerification({
  required PendingVerification pending,
  required AuthState authState,
  required bool isAnonymous,
  required String? currentPublicKeyHex,
}) {
  if (pending.isExpired) return false;

  final ownerPublicKeyHex = pending.ownerPublicKeyHex;
  return ownerPublicKeyHex == null
      ? authState == AuthState.unauthenticated
      : authState == AuthState.authenticated &&
            isAnonymous &&
            currentPublicKeyHex == ownerPublicKeyHex;
}
