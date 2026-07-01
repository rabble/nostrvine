// ABOUTME: Unit tests for AuthService NIP-46 bunker:// connect flow and the
// ABOUTME: client-initiated nostrconnect:// session guards. No network needed.
//
// #4741 PR1 gap-fill: connectWithBunker (heavily uncovered) is driven through
// the injectable remoteSignerFactory with a mock NostrRemoteSigner, so no real
// relay round-trip happens. The nostrconnect:// happy path (initiateNostrConnect
// -> waitForNostrConnectResponse) connects to public relays via
// NostrConnectSession.start() and has no injection seam, so only its no-session
// guards are covered here — adding a session seam is a follow-up for the
// extraction.

// mocktail's `when(() => mock.method())` capture idiom must be a closure (it
// records the invocation inside the stubbing zone) and cannot be a tearoff.
// ignore_for_file: unnecessary_lambdas

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_sdk/nostr_sdk.dart'
    show NostrRemoteSigner, NostrRemoteSignerInfo;
import 'package:openvine/models/known_account.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/nostr_identity.dart';
import 'package:openvine/services/user_data_cleanup_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/auth_service_test_harness.dart';

class _MockUserDataCleanupService extends Mock
    implements UserDataCleanupService {}

class _MockNostrRemoteSigner extends Mock implements NostrRemoteSigner {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AuthService NIP-46 bunker connect', () {
    late _MockUserDataCleanupService mockCleanupService;

    setUp(() {
      mockCleanupService = _MockUserDataCleanupService();
      stubUserDataCleanupSuccess(mockCleanupService);
      AuthServiceChannelMocks.install();
      SharedPreferences.setMockInitialValues({kKnownAccountsKey: '[]'});
    });

    tearDown(AuthServiceChannelMocks.remove);

    AuthService createAuthService(RemoteSignerFactory factory) =>
        buildTestAuthService(
          cleanupService: mockCleanupService,
          remoteSignerFactory: factory,
        );

    String bunkerUrlFor(String remoteSignerPubkey) =>
        'bunker://$remoteSignerPubkey'
        '?relay=wss%3A%2F%2Frelay.example.com&secret=testsecret';

    group('connectWithBunker', () {
      test('connects and sets a BunkerNostrIdentity on success', () async {
        final remoteSignerPubkey = freshPubkeyHex();
        final userPubkey = freshPubkeyHex();
        final url = bunkerUrlFor(remoteSignerPubkey);

        final signer = _MockNostrRemoteSigner();
        when(
          () => signer.info,
        ).thenReturn(NostrRemoteSignerInfo.parseBunkerUrl(url));
        when(() => signer.connect()).thenAnswer((_) async => 'ack');
        when(() => signer.pullPubkey()).thenAnswer((_) async => userPubkey);

        final authService = createAuthService((_, _) => signer);
        addTearDown(authService.dispose);

        final result = await ignoringDiscoveryErrors(
          () => authService.connectWithBunker(url),
        );

        expect(result.success, isTrue);
        expect(
          authService.authenticationSource,
          equals(AuthenticationSource.bunker),
        );
        expect(authService.currentIdentity, isA<BunkerNostrIdentity>());
        expect(authService.currentPublicKeyHex, equals(userPubkey));
      });

      test('fails when the bunker returns no public key', () async {
        final url = bunkerUrlFor(freshPubkeyHex());

        final signer = _MockNostrRemoteSigner();
        when(
          () => signer.info,
        ).thenReturn(NostrRemoteSignerInfo.parseBunkerUrl(url));
        when(() => signer.connect()).thenAnswer((_) async => 'ack');
        when(() => signer.pullPubkey()).thenAnswer((_) async => null);

        final authService = createAuthService((_, _) => signer);
        addTearDown(authService.dispose);

        final result = await authService.connectWithBunker(url);

        expect(result.success, isFalse);
        expect(result.errorMessage, contains('Failed to get public key'));
        expect(authService.isAuthenticated, isFalse);
      });

      test('fails on an invalid bunker URL', () async {
        var factoryCalled = false;
        final authService = createAuthService((_, _) {
          factoryCalled = true;
          return _MockNostrRemoteSigner();
        });
        addTearDown(authService.dispose);

        final result = await authService.connectWithBunker('not-a-bunker-url');

        expect(result.success, isFalse);
        expect(authService.isAuthenticated, isFalse);
        expect(factoryCalled, isFalse);
      });
    });

    group('nostrconnect:// guards', () {
      test(
        'waitForNostrConnectResponse fails with no active session',
        () async {
          final authService = createAuthService(
            (_, _) => _MockNostrRemoteSigner(),
          );
          addTearDown(authService.dispose);

          final result = await authService.waitForNostrConnectResponse();

          expect(result.success, isFalse);
          expect(
            result.errorMessage,
            contains('No active nostrconnect session'),
          );
        },
      );

      test('exposes null nostrconnect state before any session', () {
        final authService = createAuthService(
          (_, _) => _MockNostrRemoteSigner(),
        );
        addTearDown(authService.dispose);

        expect(authService.nostrConnectUrl, isNull);
        expect(authService.nostrConnectState, isNull);
        // Cancelling with no active session is a safe no-op.
        expect(authService.cancelNostrConnect, returnsNormally);
      });
    });
  });
}
