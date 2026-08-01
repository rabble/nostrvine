// ABOUTME: Tests for AuthService.exportKeycastNsec method
// ABOUTME: Verifies the owner-bound bearer-token handoff and refusal
// ABOUTME: passthrough for the nsec Keycast holds for a Divine Login account

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

  group('AuthService exportKeycastNsec', () {
    const testAccessToken = 'test-access-token';
    const testPassword = 'hunter2';
    const testNsec =
        'nsec1testkeymaterialthatisnotarealkey00000000000000000000000000';
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
    /// The export refuses to spend a token it cannot attribute to a signed-in
    /// account, so every test past the no-client case needs one. It arrives by
    /// key import rather than a Divine Login round trip because neither
    /// `exportKeycastNsec` nor the token gate branches on
    /// [AuthenticationSource] — only on which pubkey is signed in.
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

    test('needs sign-in when no OAuth client is configured', () async {
      final (authService, _) = await signedInAuthService(
        withOAuthClient: false,
      );

      final result = await authService.exportKeycastNsec(testPassword);

      expect(result.success, isFalse);
      expect(result.key, isNull);
      expect(result.failure, ExportKeyFailure.needsSignIn);
    });

    test('needs sign-in when there is no session after a refresh', () async {
      final (authService, pubkeyHex) = await signedInAuthService();
      when(() => mockOAuthClient.getSession()).thenAnswer((_) async => null);
      when(
        () => mockOAuthClient.refreshSession(userPubkey: pubkeyHex),
      ).thenAnswer((_) async => null);

      final result = await authService.exportKeycastNsec(testPassword);

      expect(result.failure, ExportKeyFailure.needsSignIn);
      // No password is sent anywhere without a credential to send it with.
      verifyNever(() => mockOAuthClient.exportKey(any(), any()));
    });

    test('needs sign-in when the session carries no access token', () async {
      final (authService, pubkeyHex) = await signedInAuthService();
      when(
        () => mockOAuthClient.getSession(),
      ).thenAnswer((_) async => session(owner: pubkeyHex));

      final result = await authService.exportKeycastNsec(testPassword);

      expect(result.failure, ExportKeyFailure.needsSignIn);
      verifyNever(() => mockOAuthClient.exportKey(any(), any()));
    });

    test('returns the key using the stored session token', () async {
      final (authService, pubkeyHex) = await signedInAuthService();
      when(() => mockOAuthClient.getSession()).thenAnswer(
        (_) async => session(owner: pubkeyHex, token: testAccessToken),
      );
      when(
        () => mockOAuthClient.exportKey(testAccessToken, testPassword),
      ).thenAnswer((_) async => ExportKeyResult.success(testNsec));

      final result = await authService.exportKeycastNsec(testPassword);

      expect(result.success, isTrue);
      expect(result.key, testNsec);
      verify(
        () => mockOAuthClient.exportKey(testAccessToken, testPassword),
      ).called(1);
      // A session that is already valid is used as-is.
      verifyNever(
        () => mockOAuthClient.refreshSession(
          userPubkey: any(named: 'userPubkey'),
        ),
      );
    });

    // A refresh that does not name its owner persists a session no account can
    // claim, which SignerSecureStore then declines to archive and deletes as
    // corrupt on the next restore. The account it belongs to has to travel
    // with the request.
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
          () => mockOAuthClient.exportKey(testAccessToken, testPassword),
        ).thenAnswer((_) async => ExportKeyResult.success(testNsec));

        final result = await authService.exportKeycastNsec(testPassword);

        expect(result.key, testNsec);
        verify(
          () => mockOAuthClient.refreshSession(userPubkey: pubkeyHex),
        ).called(1);
      },
    );

    // Storage keeps one global session slot, so an unowned or foreign session
    // can outlive the account that minted it. Spending its token here would
    // hand the caller somebody else's nsec.
    test('refuses a session that carries no owner', () async {
      final (authService, _) = await signedInAuthService();
      when(
        () => mockOAuthClient.getSession(),
      ).thenAnswer((_) async => session(token: testAccessToken));

      final result = await authService.exportKeycastNsec(testPassword);

      expect(result.failure, ExportKeyFailure.needsSignIn);
      verifyNever(() => mockOAuthClient.exportKey(any(), any()));
    });

    test('refuses a session bound to a different account', () async {
      final (authService, _) = await signedInAuthService();
      when(() => mockOAuthClient.getSession()).thenAnswer(
        (_) async => session(owner: otherAccountPubkey, token: testAccessToken),
      );

      final result = await authService.exportKeycastNsec(testPassword);

      expect(result.failure, ExportKeyFailure.needsSignIn);
      verifyNever(() => mockOAuthClient.exportKey(any(), any()));
    });

    test(
      'passes a refusal through unchanged rather than reshaping it',
      () async {
        final (authService, pubkeyHex) = await signedInAuthService();
        when(() => mockOAuthClient.getSession()).thenAnswer(
          (_) async => session(owner: pubkeyHex, token: testAccessToken),
        );
        when(
          () => mockOAuthClient.exportKey(testAccessToken, testPassword),
        ).thenAnswer(
          (_) async => ExportKeyResult.failure(
            ExportKeyFailure.denied,
            message: 'Operation denied by policy',
          ),
        );

        final result = await authService.exportKeycastNsec(testPassword);

        expect(result.success, isFalse);
        expect(result.key, isNull);
        // A verified_minor refusal must reach the UI as denied, not as a
        // generic error the user could read as "try again".
        expect(result.failure, ExportKeyFailure.denied);
        expect(result.error, 'Operation denied by policy');
      },
    );

    test('reports a thrown client error as a network failure', () async {
      final (authService, pubkeyHex) = await signedInAuthService();
      when(() => mockOAuthClient.getSession()).thenAnswer(
        (_) async => session(owner: pubkeyHex, token: testAccessToken),
      );
      when(
        () => mockOAuthClient.exportKey(testAccessToken, testPassword),
      ).thenThrow(Exception('socket closed'));

      final result = await authService.exportKeycastNsec(testPassword);

      expect(result.success, isFalse);
      expect(result.failure, ExportKeyFailure.network);
    });
  });
}
