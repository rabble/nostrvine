// ABOUTME: Unit tests for AuthService anonymous-account creation —
// ABOUTME: createAnonymousAccount, ...FromKeyContainer, ...FromPrivateKeyHex.
//
// #4741 PR1 gap-fill: covers the previously-uncovered anonymous-signup paths
// (fresh identity generation + acceptTerms, invite-gated key-container import)
// using a real channel-backed SecureKeyStorage. Transitively exercises
// createNewIdentity and acceptTerms.

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_key_manager/nostr_key_manager.dart';
import 'package:nostr_sdk/nostr_sdk.dart' show generatePrivateKey;
import 'package:openvine/models/known_account.dart';
import 'package:openvine/services/auth/nostr_identity.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/user_data_cleanup_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/auth_service_test_harness.dart';

class _MockUserDataCleanupService extends Mock
    implements UserDataCleanupService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AuthService anonymous account creation', () {
    late _MockUserDataCleanupService mockCleanupService;

    setUp(() {
      mockCleanupService = _MockUserDataCleanupService();
      stubUserDataCleanupSuccess(mockCleanupService);
      AuthServiceChannelMocks.install();
      SharedPreferences.setMockInitialValues({kKnownAccountsKey: '[]'});
    });

    tearDown(AuthServiceChannelMocks.remove);

    AuthService createAuthService() =>
        buildTestAuthService(cleanupService: mockCleanupService);

    test('createAnonymousAccount generates an automatic identity and '
        'accepts terms', () async {
      final authService = createAuthService();
      addTearDown(authService.dispose);

      await ignoringDiscoveryErrors(authService.createAnonymousAccount);

      expect(authService.isAuthenticated, isTrue);
      expect(
        authService.authenticationSource,
        equals(AuthenticationSource.automatic),
      );
      expect(authService.currentIdentity, isA<LocalNostrIdentity>());
      expect(authService.currentPublicKeyHex, isNotNull);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('terms_accepted_at'), isNotNull);
      expect(prefs.getBool('age_verified_16_plus'), isTrue);
    });

    test('createAnonymousAccountFromKeyContainer imports the provided key '
        'as an automatic identity', () async {
      final privateKeyHex = generatePrivateKey();
      final container = SecureKeyContainer.fromPrivateKeyHex(privateKeyHex);
      final expectedPubkey = container.publicKeyHex;
      final authService = createAuthService();
      addTearDown(authService.dispose);

      await ignoringDiscoveryErrors(
        () => authService.createAnonymousAccountFromKeyContainer(container),
      );

      expect(authService.isAuthenticated, isTrue);
      expect(
        authService.authenticationSource,
        equals(AuthenticationSource.automatic),
      );
      expect(authService.currentPublicKeyHex, equals(expectedPubkey));
    });

    test('createAnonymousAccountFromKeyContainer throws for a '
        'public-key-only container', () async {
      final pubkey = SecureKeyContainer.fromPrivateKeyHex(
        generatePrivateKey(),
      ).publicKeyHex;
      final pubkeyOnly = SecureKeyContainer.fromPublicKey(pubkey);
      final authService = createAuthService();
      addTearDown(authService.dispose);

      await expectLater(
        authService.createAnonymousAccountFromKeyContainer(pubkeyOnly),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Failed to read generated identity key'),
          ),
        ),
      );
      expect(authService.isAuthenticated, isFalse);
    });
  });
}
