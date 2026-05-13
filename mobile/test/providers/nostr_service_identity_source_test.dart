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
  final Map<String?, Completer<void>> initializeCompleters = {};

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
    when(() => client.initialize()).thenAnswer(
      (_) =>
          initializeCompleters[signer is NostrIdentity ? signer.pubkey : null]
              ?.future ??
          Future<void>.value(),
    );
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
  const pubkeyC =
      'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';

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
  late NostrIdentity identityC;

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
    identityC = buildIdentity(pubkeyC);

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

    test(
      'serializes auth transitions so older initialization cannot replace newer client',
      () async {
        when(() => mockAuth.currentIdentity).thenReturn(identityA);
        when(() => mockAuth.currentPublicKeyHex).thenReturn(pubkeyA);

        final container = createContainer();
        addTearDown(container.dispose);

        container.read(nostrServiceProvider);
        expect(factory.callCount, equals(1));
        expect(factory.clients.single.publicKey, equals(pubkeyA));

        final bInitialize = Completer<void>();
        factory.initializeCompleters[pubkeyB] = bInitialize;

        when(() => mockAuth.currentIdentity).thenReturn(identityB);
        when(() => mockAuth.currentPublicKeyHex).thenReturn(pubkeyB);
        authStream.add(AuthState.authenticated);
        await Future<void>.delayed(Duration.zero);

        expect(factory.callCount, equals(2));
        expect(
          container.read(nostrSessionProvider).phase,
          equals(NostrSessionPhase.identityKnown),
          reason:
              'B should be known but not ready while initialize is blocked.',
        );

        when(() => mockAuth.currentIdentity).thenReturn(identityC);
        when(() => mockAuth.currentPublicKeyHex).thenReturn(pubkeyC);
        authStream.add(AuthState.authenticated);
        await Future<void>.delayed(Duration.zero);

        expect(
          factory.callCount,
          equals(2),
          reason:
              'C must wait for the in-flight B transition instead of interleaving.',
        );

        bInitialize.complete();
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        expect(factory.callCount, equals(3));
        expect(factory.clients.last.publicKey, equals(pubkeyC));
        expect(
          container.read(nostrServiceProvider),
          same(factory.clients.last),
        );
        expect(container.read(nostrSessionProvider).pubkey, equals(pubkeyC));
        expect(
          container.read(nostrSessionProvider).phase,
          equals(NostrSessionPhase.nostrReady),
        );
      },
    );

    test(
      'does not expose disposed old client while replacement initializes',
      () async {
        when(() => mockAuth.currentIdentity).thenReturn(identityA);
        when(() => mockAuth.currentPublicKeyHex).thenReturn(pubkeyA);

        final container = createContainer();
        addTearDown(container.dispose);

        final oldClient = container.read(nostrServiceProvider);
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        final bInitialize = Completer<void>();
        factory.initializeCompleters[pubkeyB] = bInitialize;

        when(() => mockAuth.currentIdentity).thenReturn(identityB);
        when(() => mockAuth.currentPublicKeyHex).thenReturn(pubkeyB);
        authStream.add(AuthState.authenticated);
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        expect(factory.callCount, equals(2));
        expect(
          container.read(nostrServiceProvider),
          isNot(same(oldClient)),
          reason:
              'Once the old client is disposed, provider state must stop '
              'exposing it even while the replacement is still initializing.',
        );
        expect(
          container.read(nostrSessionProvider),
          isA<NostrSessionReadiness>()
              .having(
                (readiness) => readiness.phase,
                'phase',
                NostrSessionPhase.identityKnown,
              )
              .having((readiness) => readiness.pubkey, 'pubkey', pubkeyB),
          reason:
              'The replacement client is not ready until initialize passes.',
        );

        bInitialize.complete();
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        expect(
          container.read(nostrServiceProvider),
          same(factory.clients.last),
        );
        expect(
          container.read(nostrSessionProvider).phase,
          equals(NostrSessionPhase.nostrReady),
        );
      },
    );

    test(
      'drives session readiness from identity known to ready to signed out',
      () async {
        final bInitialize = Completer<void>();
        final signOutInitialize = Completer<void>();
        factory.initializeCompleters[pubkeyB] = bInitialize;
        factory.initializeCompleters[null] = signOutInitialize;

        final container = createContainer();
        addTearDown(container.dispose);

        final observedReadiness = <NostrSessionReadiness>[];
        final subscription = container.listen<NostrSessionReadiness>(
          nostrSessionProvider,
          (_, next) => observedReadiness.add(next),
          fireImmediately: true,
        );
        addTearDown(subscription.close);

        container.read(nostrServiceProvider);

        when(() => mockAuth.currentIdentity).thenReturn(identityB);
        when(() => mockAuth.currentPublicKeyHex).thenReturn(pubkeyB);
        authStream.add(AuthState.authenticated);
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        expect(
          container.read(nostrSessionProvider),
          isA<NostrSessionReadiness>()
              .having(
                (readiness) => readiness.phase,
                'phase',
                NostrSessionPhase.identityKnown,
              )
              .having((readiness) => readiness.pubkey, 'pubkey', pubkeyB),
          reason:
              'AuthState.authenticated identifies the user before the Nostr '
              'client can sign or publish.',
        );

        bInitialize.complete();
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        final readyClient = container.read(nostrServiceProvider);
        expect(
          container.read(nostrSessionProvider),
          isA<NostrSessionReadiness>()
              .having(
                (readiness) => readiness.phase,
                'phase',
                NostrSessionPhase.nostrReady,
              )
              .having((readiness) => readiness.pubkey, 'pubkey', pubkeyB)
              .having(
                (readiness) => readiness.client,
                'client',
                same(readyClient),
              ),
        );

        when(() => mockAuth.currentIdentity).thenReturn(null);
        when(() => mockAuth.currentPublicKeyHex).thenReturn(null);
        authStream.add(AuthState.unauthenticated);
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        expect(
          observedReadiness.map((readiness) => readiness.phase),
          containsAllInOrder([
            NostrSessionPhase.identityKnown,
            NostrSessionPhase.nostrReady,
            NostrSessionPhase.tearingDown,
            NostrSessionPhase.signedOut,
          ]),
        );
        expect(
          container.read(nostrSessionProvider).phase,
          NostrSessionPhase.signedOut,
        );
      },
    );

    test(
      'failed auth transition does not block later auth transitions',
      () async {
        when(() => mockAuth.currentIdentity).thenReturn(identityA);
        when(() => mockAuth.currentPublicKeyHex).thenReturn(pubkeyA);

        final container = createContainer();
        addTearDown(container.dispose);

        container.read(nostrServiceProvider);
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        final bInitialize = Completer<void>();
        factory.initializeCompleters[pubkeyB] = bInitialize;

        when(() => mockAuth.currentIdentity).thenReturn(identityB);
        when(() => mockAuth.currentPublicKeyHex).thenReturn(pubkeyB);
        authStream.add(AuthState.authenticated);
        await Future<void>.delayed(Duration.zero);

        when(() => mockAuth.currentIdentity).thenReturn(identityC);
        when(() => mockAuth.currentPublicKeyHex).thenReturn(pubkeyC);
        authStream.add(AuthState.authenticated);
        bInitialize.completeError(StateError('B initialize failed'));
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        expect(factory.callCount, equals(3));
        expect(factory.clients.last.publicKey, equals(pubkeyC));
        expect(
          container.read(nostrServiceProvider),
          same(factory.clients.last),
        );
        expect(
          container.read(nostrSessionProvider),
          isA<NostrSessionReadiness>()
              .having(
                (readiness) => readiness.phase,
                'phase',
                NostrSessionPhase.nostrReady,
              )
              .having((readiness) => readiness.pubkey, 'pubkey', pubkeyC)
              .having(
                (readiness) => readiness.client,
                'client',
                same(factory.clients.last),
              ),
        );
      },
    );

    test(
      'failed same-pubkey transition can retry client creation',
      () async {
        when(() => mockAuth.currentIdentity).thenReturn(identityA);
        when(() => mockAuth.currentPublicKeyHex).thenReturn(pubkeyA);

        final container = createContainer();
        addTearDown(container.dispose);

        container.read(nostrServiceProvider);
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);
        expect(factory.callCount, equals(1));

        final failedBInitialize = Completer<void>();
        factory.initializeCompleters[pubkeyB] = failedBInitialize;

        when(() => mockAuth.currentIdentity).thenReturn(identityB);
        when(() => mockAuth.currentPublicKeyHex).thenReturn(pubkeyB);
        authStream.add(AuthState.authenticated);
        await Future<void>.delayed(Duration.zero);

        expect(factory.callCount, equals(2));

        failedBInitialize.completeError(StateError('B initialize failed'));
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        factory.initializeCompleters.remove(pubkeyB);
        authStream.add(AuthState.authenticated);
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        expect(
          factory.callCount,
          equals(3),
          reason:
              'A failed transition must not mark pubkey B complete; a later '
              'auth emission for B should recreate and initialize a new client.',
        );
        expect(factory.clients.last.publicKey, equals(pubkeyB));
        expect(
          container.read(nostrServiceProvider),
          same(factory.clients.last),
        );
        expect(
          container.read(nostrSessionProvider),
          isA<NostrSessionReadiness>()
              .having(
                (readiness) => readiness.phase,
                'phase',
                NostrSessionPhase.nostrReady,
              )
              .having((readiness) => readiness.pubkey, 'pubkey', pubkeyB)
              .having(
                (readiness) => readiness.client,
                'client',
                same(factory.clients.last),
              ),
        );
      },
    );

    test(
      'failed initial same-pubkey build can retry client creation',
      () async {
        final failedInitialAInitialize = Completer<void>();
        factory.initializeCompleters[pubkeyA] = failedInitialAInitialize;
        when(() => mockAuth.currentIdentity).thenReturn(identityA);
        when(() => mockAuth.currentPublicKeyHex).thenReturn(pubkeyA);

        final container = createContainer();
        addTearDown(container.dispose);

        container.read(nostrServiceProvider);
        await Future<void>.delayed(Duration.zero);
        expect(factory.callCount, equals(1));

        failedInitialAInitialize.completeError(
          StateError('initial A initialize failed'),
        );
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        expect(
          container.read(nostrSessionProvider),
          isA<NostrSessionReadiness>()
              .having(
                (readiness) => readiness.phase,
                'phase',
                NostrSessionPhase.identityKnown,
              )
              .having((readiness) => readiness.pubkey, 'pubkey', pubkeyA),
          reason:
              'A failed initial client must leave readiness non-ready for the '
              'known identity.',
        );

        factory.initializeCompleters.remove(pubkeyA);
        authStream.add(AuthState.authenticated);
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        expect(
          factory.callCount,
          equals(2),
          reason:
              'A failed initial build must not mark pubkey A complete; a later '
              'auth emission for A should recreate and initialize a new client.',
        );
        expect(factory.clients.last.publicKey, equals(pubkeyA));
        expect(
          container.read(nostrServiceProvider),
          same(factory.clients.last),
        );
        expect(
          container.read(nostrSessionProvider),
          isA<NostrSessionReadiness>()
              .having(
                (readiness) => readiness.phase,
                'phase',
                NostrSessionPhase.nostrReady,
              )
              .having((readiness) => readiness.pubkey, 'pubkey', pubkeyA)
              .having(
                (readiness) => readiness.client,
                'client',
                same(factory.clients.last),
              ),
        );
      },
    );

    test(
      'stale build initialization cannot mark a disposed client ready',
      () async {
        final firstAInitialize = Completer<void>();
        factory.initializeCompleters[pubkeyA] = firstAInitialize;
        when(() => mockAuth.currentIdentity).thenReturn(identityA);
        when(() => mockAuth.currentPublicKeyHex).thenReturn(pubkeyA);

        final container = createContainer();
        addTearDown(container.dispose);

        final firstAClient = container.read(nostrServiceProvider);
        await Future<void>.delayed(Duration.zero);

        when(() => mockAuth.currentIdentity).thenReturn(null);
        when(() => mockAuth.currentPublicKeyHex).thenReturn(null);
        authStream.add(AuthState.unauthenticated);
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        factory.initializeCompleters.remove(pubkeyA);
        when(() => mockAuth.currentIdentity).thenReturn(identityA);
        when(() => mockAuth.currentPublicKeyHex).thenReturn(pubkeyA);
        authStream.add(AuthState.authenticated);
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        final currentAClient = container.read(nostrServiceProvider);
        expect(currentAClient, isNot(same(firstAClient)));
        expect(
          container.read(nostrSessionProvider).client,
          same(currentAClient),
        );

        firstAInitialize.complete();
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        expect(
          container.read(nostrSessionProvider),
          isA<NostrSessionReadiness>()
              .having(
                (readiness) => readiness.phase,
                'phase',
                NostrSessionPhase.nostrReady,
              )
              .having((readiness) => readiness.pubkey, 'pubkey', pubkeyA)
              .having(
                (readiness) => readiness.client,
                'client',
                same(currentAClient),
              ),
          reason:
              'A disposed build client must not be able to overwrite readiness '
              'after a later client for the same pubkey is current.',
        );
      },
    );

    test(
      'stale initial placeholder completion cannot sign out a ready session',
      () async {
        final initialPlaceholderInitialize = Completer<void>();
        factory.initializeCompleters[null] = initialPlaceholderInitialize;

        final container = createContainer();
        addTearDown(container.dispose);

        container.read(nostrServiceProvider);
        await Future<void>.delayed(Duration.zero);
        expect(factory.callCount, equals(1));
        expect(factory.signers.single, isNull);

        factory.initializeCompleters.remove(null);
        when(() => mockAuth.currentIdentity).thenReturn(identityA);
        when(() => mockAuth.currentPublicKeyHex).thenReturn(pubkeyA);
        authStream.add(AuthState.authenticated);
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        final readyClient = container.read(nostrServiceProvider);
        expect(
          container.read(nostrSessionProvider),
          isA<NostrSessionReadiness>()
              .having(
                (readiness) => readiness.phase,
                'phase',
                NostrSessionPhase.nostrReady,
              )
              .having((readiness) => readiness.pubkey, 'pubkey', pubkeyA)
              .having(
                (readiness) => readiness.client,
                'client',
                same(readyClient),
              ),
        );

        initialPlaceholderInitialize.complete();
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        expect(
          container.read(nostrSessionProvider),
          isA<NostrSessionReadiness>()
              .having(
                (readiness) => readiness.phase,
                'phase',
                NostrSessionPhase.nostrReady,
              )
              .having((readiness) => readiness.pubkey, 'pubkey', pubkeyA)
              .having(
                (readiness) => readiness.client,
                'client',
                same(readyClient),
              ),
          reason:
              'A stale initial placeholder client must not overwrite a later '
              'ready authenticated session with signedOut.',
        );
      },
    );

    test(
      'stale relay discovery callback cannot add relays to old client',
      () async {
        UserRelaysDiscoveredCallback? latestRelayCallback;
        when(
          () => mockAuth.registerUserRelaysDiscoveredCallback(any()),
        ).thenAnswer((invocation) {
          latestRelayCallback =
              invocation.positionalArguments.single
                  as UserRelaysDiscoveredCallback?;
        });

        when(() => mockAuth.currentIdentity).thenReturn(identityA);
        when(() => mockAuth.currentPublicKeyHex).thenReturn(pubkeyA);

        final container = createContainer();
        addTearDown(container.dispose);

        final oldClient = container.read(nostrServiceProvider);
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);
        final staleRelayCallback = latestRelayCallback!;

        when(() => mockAuth.currentIdentity).thenReturn(identityB);
        when(() => mockAuth.currentPublicKeyHex).thenReturn(pubkeyB);
        authStream.add(AuthState.authenticated);
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        expect(container.read(nostrServiceProvider), isNot(same(oldClient)));

        const staleRelays = ['wss://stale-relay.example'];
        staleRelayCallback(pubkeyA, staleRelays);
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        verifyNever(() => oldClient.addRelays(staleRelays));
      },
    );

    test(
      'session rebuild preserves ready state for the same identity',
      () async {
        when(() => mockAuth.currentIdentity).thenReturn(identityA);
        when(() => mockAuth.currentPublicKeyHex).thenReturn(pubkeyA);

        final container = createContainer();
        addTearDown(container.dispose);

        final client = container.read(nostrServiceProvider);
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        expect(
          container.read(nostrSessionProvider),
          isA<NostrSessionReadiness>()
              .having(
                (readiness) => readiness.phase,
                'phase',
                NostrSessionPhase.nostrReady,
              )
              .having((readiness) => readiness.pubkey, 'pubkey', pubkeyA)
              .having((readiness) => readiness.client, 'client', same(client)),
        );

        container.invalidate(nostrSessionProvider);
        await Future<void>.delayed(Duration.zero);

        expect(
          container.read(nostrSessionProvider),
          isA<NostrSessionReadiness>()
              .having(
                (readiness) => readiness.phase,
                'phase',
                NostrSessionPhase.nostrReady,
              )
              .having((readiness) => readiness.pubkey, 'pubkey', pubkeyA)
              .having((readiness) => readiness.client, 'client', same(client)),
          reason:
              'Rebuilding the session provider for the same identity must not '
              'downgrade the ready client back to identityKnown.',
        );
      },
    );
  });
}
