// ABOUTME: Regression tests for NostrService consuming NostrIdentity as the
// ABOUTME: sole source of truth (per PR #2833) rather than the fallback-chain
// ABOUTME: getters on AuthService, preventing the null-signer placeholder trap.

import 'dart:async';

import 'package:db_client/db_client.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_key_manager/nostr_key_manager.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:openvine/models/environment_config.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/database_provider.dart';
import 'package:openvine/providers/environment_provider.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/nostr_identity.dart';
import 'package:openvine/services/relay_statistics_service.dart';

class _MockAuthService extends Mock implements AuthService {}

class _MockNostrClient extends Mock implements NostrClient {}

class _MockAppDbClient extends Mock implements AppDbClient {}

class _MockRelayStatisticsService extends Mock
    implements RelayStatisticsService {}

class _MockSecureKeyContainer extends Mock implements SecureKeyContainer {}

/// Records every factory invocation so the test can observe what signer
/// NostrService passed to each recreation.
class _RecordingFactory {
  final List<NostrSigner?> signers = [];
  final List<_MockNostrClient> clients = [];

  NostrClient call({
    NostrSigner? signer,
    RelayStatisticsService? statisticsService,
    EnvironmentConfig? environmentConfig,
    AppDbClient? dbClient,
  }) {
    signers.add(signer);
    final client = _MockNostrClient();
    // hasKeys reflects whether we got a real signer or a null placeholder.
    final hasKeys = signer != null;
    when(() => client.hasKeys).thenReturn(hasKeys);
    when(
      () => client.publicKey,
    ).thenReturn(signer is NostrIdentity ? signer.pubkey : '');
    // ignore: unnecessary_lambdas
    when(() => client.initialize()).thenAnswer((_) => Future<void>.value());
    when(() => client.addRelays(any())).thenAnswer((_) => Future.value(0));
    // ignore: unnecessary_lambdas
    when(() => client.dispose()).thenAnswer((_) => Future<void>.value());
    clients.add(client);
    return client;
  }

  int get callCount => signers.length;
}

void main() {
  const pubkeyA =
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
  const pubkeyB =
      'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

  setUpAll(() {
    registerFallbackValue(<String>[]);
  });

  late _MockAuthService mockAuth;
  late _MockAppDbClient mockDbClient;
  late _MockRelayStatisticsService mockStats;
  late StreamController<AuthState> authStream;
  late _RecordingFactory factory;
  late NostrIdentity identityA;
  late NostrIdentity identityB;

  NostrIdentity buildIdentity(String pubkey) {
    final keyContainer = _MockSecureKeyContainer();
    when(() => keyContainer.publicKeyHex).thenReturn(pubkey);
    when(() => keyContainer.isDisposed).thenReturn(false);
    return LocalNostrIdentity(keyContainer: keyContainer);
  }

  setUp(() {
    mockAuth = _MockAuthService();
    mockDbClient = _MockAppDbClient();
    mockStats = _MockRelayStatisticsService();
    authStream = StreamController<AuthState>.broadcast();
    factory = _RecordingFactory();
    identityA = buildIdentity(pubkeyA);
    identityB = buildIdentity(pubkeyB);

    // Baseline: unauthenticated state. Tests override currentIdentity
    // per scenario.
    when(() => mockAuth.currentIdentity).thenReturn(null);
    when(() => mockAuth.currentPublicKeyHex).thenReturn(null);
    when(() => mockAuth.currentNpub).thenReturn(null);
    when(() => mockAuth.userRelays).thenReturn([]);
    when(() => mockAuth.authStateStream).thenAnswer((_) => authStream.stream);
    when(
      () => mockAuth.registerUserRelaysDiscoveredCallback(any()),
    ).thenReturn(null);
  });

  tearDown(() async {
    await authStream.close();
  });

  ProviderContainer createContainer() {
    return ProviderContainer(
      overrides: [
        authServiceProvider.overrideWithValue(mockAuth),
        relayStatisticsServiceProvider.overrideWithValue(mockStats),
        currentEnvironmentProvider.overrideWithValue(
          EnvironmentConfig.production,
        ),
        appDbClientProvider.overrideWithValue(mockDbClient),
        nostrClientFactoryProvider.overrideWithValue(factory.call),
      ],
    );
  }

  group('NostrService uses NostrIdentity as source of truth', () {
    test('does not recreate with null-signer placeholder when authenticating '
        'emits while currentIdentity is still null', () async {
      // Simulate the auth-screen transient state described in PR #2833:
      // the fallback-chain getter reports a pubkey (from _currentProfile or
      // _currentKeyContainer) but the atomic NostrIdentity has not yet
      // been assembled. NostrService must read the identity, not the
      // fallback getter, so it derives newPubkey=null from a null
      // identity and takes the NO-OP branch.
      final container = createContainer();
      addTearDown(container.dispose);

      // Trigger NostrService.build() — initial state with no identity.
      container.read(nostrServiceProvider);
      expect(
        factory.callCount,
        equals(1),
        reason: 'build() calls factory once for initial placeholder',
      );
      expect(factory.signers.single, isNull);

      // Move AuthService into the 'authenticating' trap state:
      // currentPublicKeyHex returns a real pubkey via the fallback chain
      // but currentIdentity is still null.
      when(() => mockAuth.currentPublicKeyHex).thenReturn(pubkeyA);
      when(() => mockAuth.currentNpub).thenReturn('npub1aaa');
      // currentIdentity intentionally remains null.

      authStream.add(AuthState.authenticating);
      // Let the async listener run.
      await Future<void>.delayed(Duration.zero);

      expect(
        factory.callCount,
        equals(1),
        reason:
            'Must NOT recreate with a null signer while currentIdentity '
            'is null — the placeholder client would report hasKeys=false '
            'permanently and trap downstream providers.',
      );

      // Now the atomic identity finishes assembling. The authenticated
      // emit should trigger a single recreation with the real signer.
      when(() => mockAuth.currentIdentity).thenReturn(identityA);

      authStream.add(AuthState.authenticated);
      await Future<void>.delayed(Duration.zero);

      expect(
        factory.callCount,
        equals(2),
        reason:
            'authenticated emit with real identity must recreate the '
            'client with a real signer',
      );
      expect(factory.signers.last, same(identityA));
      expect(factory.clients.last.hasKeys, isTrue);
      expect(factory.clients.last.publicKey, equals(pubkeyA));
    });

    test('recreates with null-signer placeholder on signOut '
        '(identity → null transition)', () async {
      // Start authenticated as A.
      when(() => mockAuth.currentIdentity).thenReturn(identityA);
      when(() => mockAuth.currentPublicKeyHex).thenReturn(pubkeyA);

      final container = createContainer();
      addTearDown(container.dispose);

      container.read(nostrServiceProvider);
      expect(factory.callCount, equals(1));
      expect(factory.signers.single, same(identityA));
      expect(factory.clients.single.hasKeys, isTrue);

      // Sign out: clear identity and pubkey, emit unauthenticated.
      when(() => mockAuth.currentIdentity).thenReturn(null);
      when(() => mockAuth.currentPublicKeyHex).thenReturn(null);
      authStream.add(AuthState.unauthenticated);
      await Future<void>.delayed(Duration.zero);

      expect(
        factory.callCount,
        equals(2),
        reason: 'signOut must dispose the A client and recreate a new one',
      );
      expect(factory.signers.last, isNull);
      expect(factory.clients.last.hasKeys, isFalse);
    });

    test(
      'full account switch A → unauth → B installs real signer for B',
      () async {
        // Reproduces the device-log scenario verbatim: start authenticated
        // as A, signOut through unauthenticated, transition through
        // authenticating with currentIdentity still null, then authenticated
        // with the real identity for B.
        when(() => mockAuth.currentIdentity).thenReturn(identityA);
        when(() => mockAuth.currentPublicKeyHex).thenReturn(pubkeyA);

        final container = createContainer();
        addTearDown(container.dispose);

        container.read(nostrServiceProvider);
        expect(factory.callCount, equals(1));
        expect(factory.clients.last.hasKeys, isTrue);

        // Step 1: signOut — unauthenticated, clear identity.
        when(() => mockAuth.currentIdentity).thenReturn(null);
        when(() => mockAuth.currentPublicKeyHex).thenReturn(null);
        authStream.add(AuthState.unauthenticated);
        await Future<void>.delayed(Duration.zero);
        expect(factory.callCount, equals(2));
        expect(factory.clients.last.hasKeys, isFalse);

        // Step 2: authenticating for B — fallback chain reports B's pubkey
        // (from _currentProfile or _currentKeyContainer set in partial
        // _setupUserSession state) but currentIdentity is still null.
        when(() => mockAuth.currentPublicKeyHex).thenReturn(pubkeyB);
        // currentIdentity stays null intentionally.
        authStream.add(AuthState.authenticating);
        await Future<void>.delayed(Duration.zero);

        expect(
          factory.callCount,
          equals(2),
          reason:
              'authenticating emit with null currentIdentity must NOT '
              'recreate — that would install a placeholder that masks '
              'the subsequent authenticated emit',
        );

        // Step 3: authenticated with real identity for B.
        when(() => mockAuth.currentIdentity).thenReturn(identityB);
        authStream.add(AuthState.authenticated);
        await Future<void>.delayed(Duration.zero);

        expect(factory.callCount, equals(3));
        expect(factory.signers.last, same(identityB));
        expect(factory.clients.last.hasKeys, isTrue);
        expect(factory.clients.last.publicKey, equals(pubkeyB));
      },
    );
  });
}
