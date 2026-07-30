// ABOUTME: Tests AuthService-to-invite-session identity readiness mapping.
// ABOUTME: Covers local/imported and delayed Keycast signer composition.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_key_manager/nostr_key_manager.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:openvine/blocs/invite_status/invite_status_auth_session_source.dart';
import 'package:openvine/services/auth/nostr_identity.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/user_data_cleanup_service.dart';

class _MockAuthService extends Mock implements AuthService {}

class _MockNostrSigner extends Mock implements NostrSigner {}

class _MockUserDataCleanupService extends Mock
    implements UserDataCleanupService {}

void main() {
  group(InviteStatusAuthSessionSource, () {
    test('maps an imported local identity to a ready session', () async {
      final authService = AuthService(
        userDataCleanupService: _MockUserDataCleanupService(),
      );
      addTearDown(authService.dispose);
      final keyContainer = SecureKeyContainer.fromPrivateKeyHex(
        generatePrivateKey(),
      );
      addTearDown(keyContainer.dispose);
      authService.debugSetIdentity(
        LocalNostrIdentity(keyContainer: keyContainer),
      );

      final session = InviteStatusAuthSessionSource(authService).current;

      expect(session.accountId, keyContainer.publicKeyHex);
      expect(session.isSignerReady, isTrue);
    });

    test('maps Keycast warmup from pubkey-only to signer-ready', () async {
      final authService = AuthService(
        userDataCleanupService: _MockUserDataCleanupService(),
      );
      addTearDown(authService.dispose);
      const pubkey =
          'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
      final source = InviteStatusAuthSessionSource(authService);
      authService.debugSetIdentity(PubkeyOnlyNostrIdentity(pubkey: pubkey));

      expect(source.current.accountId, pubkey);
      expect(source.current.isSignerReady, isFalse);

      authService.debugSetIdentity(
        KeycastNostrIdentity(
          pubkey: pubkey,
          rpcSigner: _MockNostrSigner(),
        ),
      );

      expect(source.current.accountId, pubkey);
      expect(source.current.isSignerReady, isTrue);
    });

    test('re-samples readiness from the existing auth state stream', () async {
      final authService = _MockAuthService();
      final authStates = StreamController<AuthState>();
      addTearDown(authStates.close);
      var signerReady = false;
      when(
        () => authService.currentPublicKeyHex,
      ).thenReturn(
        'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc',
      );
      when(
        () => authService.canPublishNostrWritesNow,
      ).thenAnswer((_) => signerReady);
      when(
        () => authService.authStateStream,
      ).thenAnswer((_) => authStates.stream);
      final source = InviteStatusAuthSessionSource(authService);

      expect(source.current.isSignerReady, isFalse);

      signerReady = true;
      final readySession = source.changes.first;
      authStates.add(AuthState.authenticated);

      expect((await readySession).isSignerReady, isTrue);
    });
  });
}
