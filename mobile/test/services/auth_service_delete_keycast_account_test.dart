// ABOUTME: Tests for AuthService.deleteKeycastAccount method
// ABOUTME: Verifies Keycast account deletion during account deletion flow

import 'package:flutter_test/flutter_test.dart';
import 'package:keycast_flutter/keycast_flutter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_key_manager/nostr_key_manager.dart';
import 'package:nostr_sdk/nostr_sdk.dart' show Nip19, generatePrivateKey;
import 'package:openvine/models/known_account.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/user_data_cleanup_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/auth_service_test_harness.dart';

class _MockUserDataCleanupService extends Mock
    implements UserDataCleanupService {}

class _MockKeycastOAuth extends Mock implements KeycastOAuth {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AuthService deleteKeycastAccount', () {
    const testAccessToken = 'test_access_token_123';
    const otherAccountPubkey =
        'cdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcd';

    late _MockUserDataCleanupService mockCleanupService;
    late _MockKeycastOAuth mockOAuthClient;

    setUp(() {
      mockCleanupService = _MockUserDataCleanupService();
      mockOAuthClient = _MockKeycastOAuth();
      stubUserDataCleanupSuccess(mockCleanupService);
      AuthServiceChannelMocks.install();
      SharedPreferences.setMockInitialValues({kKnownAccountsKey: '[]'});
    });

    tearDown(AuthServiceChannelMocks.remove);

    /// An [AuthService] with an account signed in, plus that account's pubkey.
    ///
    /// Deletion refuses to spend a token it cannot attribute to a signed-in
    /// account, so every test past the no-client case needs one. It arrives by
    /// key import rather than a Divine Login round trip because
    /// `deleteKeycastAccount` does not branch on [AuthenticationSource] — only
    /// on which pubkey is signed in. The real flow calls this while the signer
    /// is still live (`delete_account_dialog.dart`), before sign-out.
    Future<(AuthService, String)> signedInAuthService({
      bool withOAuthClient = true,
    }) async {
      final privateKeyHex = generatePrivateKey();
      final pubkeyHex = SecureKeyContainer.fromPrivateKeyHex(
        privateKeyHex,
      ).publicKeyHex;
      final authService = buildTestAuthService(
        cleanupService: mockCleanupService,
        oauthClient: withOAuthClient ? mockOAuthClient : null,
      );
      addTearDown(authService.dispose);

      await ignoringDiscoveryErrors(
        () => authService.importFromNsec(Nip19.encodePrivateKey(privateKeyHex)),
      );
      expect(authService.currentPublicKeyHex, pubkeyHex);

      return (authService, pubkeyHex);
    }

    KeycastSession session({String? owner, String? token}) {
      return KeycastSession(
        bunkerUrl: 'https://bunker.example.com',
        accessToken: token,
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
        userPubkey: owner,
      );
    }

    /// Arranges a valid, owner-bound session carrying [testAccessToken].
    Future<AuthService> withUsableSession() async {
      final (authService, pubkeyHex) = await signedInAuthService();
      when(() => mockOAuthClient.getSession()).thenAnswer(
        (_) async => session(owner: pubkeyHex, token: testAccessToken),
      );
      return authService;
    }

    test('returns success when no OAuth client is configured', () async {
      final (authService, _) = await signedInAuthService(
        withOAuthClient: false,
      );

      final result = await authService.deleteKeycastAccount();

      expect(result.success, isTrue);
      expect(result.error, isNull);
    });

    test('returns failure when session is unavailable after refresh', () async {
      final (authService, pubkeyHex) = await signedInAuthService();
      when(() => mockOAuthClient.getSession()).thenAnswer((_) async => null);
      when(
        () => mockOAuthClient.refreshSession(userPubkey: pubkeyHex),
      ).thenAnswer((_) async => null);

      final result = await authService.deleteKeycastAccount();

      expect(result.success, isFalse);
      expect(result.error, contains('No usable session'));
      expect(result.requiresReauthentication, isTrue);
      verifyNever(
        () => mockOAuthClient.deleteAccount(
          any(),
          nip98Signer: any(named: 'nip98Signer'),
        ),
      );
    });

    test(
      'returns failure when session has no access token after refresh',
      () async {
        final (authService, pubkeyHex) = await signedInAuthService();
        when(
          () => mockOAuthClient.getSession(),
        ).thenAnswer((_) async => session(owner: pubkeyHex));

        final result = await authService.deleteKeycastAccount();

        expect(result.success, isFalse);
        expect(result.error, contains('No usable session'));
        verifyNever(
          () => mockOAuthClient.deleteAccount(
            any(),
            nip98Signer: any(named: 'nip98Signer'),
          ),
        );
      },
    );

    // Deletion is irreversible and the session slot is global, so a session
    // this account cannot claim must never reach the delete call — it would
    // destroy whichever account actually minted the token.
    test('refuses a session that carries no owner', () async {
      final (authService, _) = await signedInAuthService();
      when(
        () => mockOAuthClient.getSession(),
      ).thenAnswer((_) async => session(token: testAccessToken));

      final result = await authService.deleteKeycastAccount();

      expect(result.success, isFalse);
      expect(result.requiresReauthentication, isTrue);
      verifyNever(
        () => mockOAuthClient.deleteAccount(
          any(),
          nip98Signer: any(named: 'nip98Signer'),
        ),
      );
    });

    test('refuses a session bound to a different account', () async {
      final (authService, _) = await signedInAuthService();
      when(() => mockOAuthClient.getSession()).thenAnswer(
        (_) async => session(owner: otherAccountPubkey, token: testAccessToken),
      );

      final result = await authService.deleteKeycastAccount();

      expect(result.success, isFalse);
      expect(result.requiresReauthentication, isTrue);
      verifyNever(
        () => mockOAuthClient.deleteAccount(
          any(),
          nip98Signer: any(named: 'nip98Signer'),
        ),
      );
    });

    // A refresh that does not name its owner persists a session no account can
    // claim, which SignerSecureStore then declines to archive and deletes as
    // corrupt on the next restore.
    test(
      "refreshes an expired session in the signed-in account's name",
      () async {
        final (authService, pubkeyHex) = await signedInAuthService();
        when(() => mockOAuthClient.getSession()).thenAnswer((_) async => null);
        when(
          () => mockOAuthClient.refreshSession(userPubkey: pubkeyHex),
        ).thenAnswer(
          (_) async => session(owner: pubkeyHex, token: testAccessToken),
        );
        when(
          () => mockOAuthClient.deleteAccount(
            testAccessToken,
            nip98Signer: any(named: 'nip98Signer'),
          ),
        ).thenAnswer(
          (_) async => DeleteAccountResult(
            success: true,
            message: 'Account permanently deleted',
          ),
        );

        final result = await authService.deleteKeycastAccount();

        expect(result.success, isTrue);
        verify(
          () => mockOAuthClient.refreshSession(userPubkey: pubkeyHex),
        ).called(1);
      },
    );

    test('returns success when account deletion succeeds', () async {
      final authService = await withUsableSession();
      when(
        () => mockOAuthClient.deleteAccount(
          testAccessToken,
          nip98Signer: any(named: 'nip98Signer'),
        ),
      ).thenAnswer(
        (_) async => DeleteAccountResult(
          success: true,
          message: 'Account permanently deleted',
        ),
      );

      final result = await authService.deleteKeycastAccount();

      expect(result.success, isTrue);
      expect(result.error, isNull);
      verify(
        () => mockOAuthClient.deleteAccount(
          testAccessToken,
          nip98Signer: any(named: 'nip98Signer'),
        ),
      ).called(1);
    });

    test('returns failure with error message when deletion fails', () async {
      final authService = await withUsableSession();
      const errorMessage = 'Unauthorized: invalid or expired token';
      when(
        () => mockOAuthClient.deleteAccount(
          testAccessToken,
          nip98Signer: any(named: 'nip98Signer'),
        ),
      ).thenAnswer((_) async => DeleteAccountResult.error(errorMessage));

      final result = await authService.deleteKeycastAccount();

      expect(result.success, isFalse);
      expect(result.error, equals(errorMessage));
      verify(
        () => mockOAuthClient.deleteAccount(
          testAccessToken,
          nip98Signer: any(named: 'nip98Signer'),
        ),
      ).called(1);
    });

    // The caller decides between "retry" and "sign in again" copy from this
    // flag, and it must survive the hop out of the package: the server's own
    // 403 prose is not matchable, and by the time this runs the NIP-62 vanish
    // has already been published.
    test(
      'propagates requiresReauthentication from a refused deletion',
      () async {
        final authService = await withUsableSession();
        when(
          () => mockOAuthClient.deleteAccount(
            testAccessToken,
            nip98Signer: any(named: 'nip98Signer'),
          ),
        ).thenAnswer(
          (_) async => DeleteAccountResult.error(
            'Account deletion requires the Divine app or web login with your '
            'private key',
            requiresReauthentication: true,
          ),
        );

        final result = await authService.deleteKeycastAccount();

        expect(result.success, isFalse);
        expect(result.requiresReauthentication, isTrue);
      },
    );

    // Without a proof-of-key the request falls back to the bearer token, and a
    // refreshed bearer token is exactly what keycast refuses (#4881) — after
    // the irreversible NIP-62 vanish has already been published. If this
    // regresses, deletion silently goes back to failing for every returning
    // user.
    test(
      'supplies a NIP-98 signer so a refreshed session can still delete',
      () async {
        final (authService, pubkeyHex) = await signedInAuthService();
        when(() => mockOAuthClient.getSession()).thenAnswer((_) async => null);
        when(
          () => mockOAuthClient.refreshSession(userPubkey: pubkeyHex),
        ).thenAnswer(
          (_) async => session(owner: pubkeyHex, token: testAccessToken),
        );

        Future<String?> Function(String)? capturedSigner;
        when(
          () => mockOAuthClient.deleteAccount(
            testAccessToken,
            nip98Signer: any(named: 'nip98Signer'),
          ),
        ).thenAnswer((invocation) async {
          capturedSigner =
              invocation.namedArguments[#nip98Signer]
                  as Future<String?> Function(String)?;
          return DeleteAccountResult(success: true, message: 'deleted');
        });

        await authService.deleteKeycastAccount();

        expect(
          capturedSigner,
          isNotNull,
          reason: 'deleteKeycastAccount must offer a proof-of-key signer',
        );
      },
    );

    test('returns failure when exception is thrown', () async {
      final authService = await withUsableSession();
      when(
        () => mockOAuthClient.deleteAccount(
          testAccessToken,
          nip98Signer: any(named: 'nip98Signer'),
        ),
      ).thenThrow(Exception('Network error'));

      final result = await authService.deleteKeycastAccount();

      expect(result.success, isFalse);
      expect(result.error, contains('Failed to delete Keycast account'));
      expect(result.error, contains('Network error'));
    });
  });
}
