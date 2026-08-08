// ABOUTME: Tests for NIP-65 kind:10002 relay-list publishing.
// ABOUTME: Covers marker preservation, indexer acceptance, cache, and retry state.

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:openvine/models/environment_config.dart';
import 'package:openvine/repositories/relay_list_repository.dart';
import 'package:openvine/services/relay_discovery_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockNostrClient extends Mock implements NostrClient {}

class _MockRelayDiscoveryService extends Mock
    implements RelayDiscoveryService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockNostrClient nostrClient;
  late _MockRelayDiscoveryService relayDiscoveryService;
  late SharedPreferences prefs;
  late LocalNostrSigner signer;
  late String pubkey;
  late List<DiscoveredRelay> discoveredRelays;

  setUpAll(() {
    registerFallbackValue(
      Event('0' * 64, EventKind.relayListMetadata, const [], ''),
    );
    registerFallbackValue(Duration.zero);
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    nostrClient = _MockNostrClient();
    relayDiscoveryService = _MockRelayDiscoveryService();
    signer = LocalNostrSigner(generatePrivateKey());
    pubkey = (await signer.getPublicKey())!;
    discoveredRelays = const [];

    when(() => nostrClient.hasKeys).thenReturn(true);
    when(() => nostrClient.publicKey).thenReturn(pubkey);
    when(() => nostrClient.signer).thenReturn(signer);
    when(() => nostrClient.configuredRelays).thenReturn(const [
      'wss://relay.divine.video',
      'wss://read.example',
      'wss://write.example',
      'wss://new.example',
    ]);
    when(
      () => relayDiscoveryService.clearCache(any()),
    ).thenAnswer((_) async {});
    when(
      () => nostrClient.publishEventAwaitOk(
        any(),
        targetRelays: any(named: 'targetRelays'),
        timeout: any(named: 'timeout'),
      ),
    ).thenAnswer((invocation) async {
      final event = invocation.positionalArguments.first as Event;
      return PublishOutcome(
        eventId: event.id,
        acceptedBy: const ['wss://purplepag.es'],
        rejectedBy: const {},
        noResponseFrom: const [],
      );
    });
  });

  RelayListRepository buildRepository({
    EnvironmentConfig environment = EnvironmentConfig.production,
  }) {
    return RelayListRepository(
      nostrClient: nostrClient,
      environment: environment,
      relayDiscoveryService: relayDiscoveryService,
      sharedPreferences: prefs,
      discoveredRelays: () => discoveredRelays,
    );
  }

  test(
    'publishes configured relays as kind 10002 and preserves markers',
    () async {
      discoveredRelays = const [
        DiscoveredRelay(url: 'wss://read.example', write: false),
        DiscoveredRelay(url: 'wss://write.example', read: false),
      ];

      final result = await buildRepository().publishConfiguredRelayList();

      expect(result.status, RelayListPublishStatus.published);
      final captured = verify(
        () => nostrClient.publishEventAwaitOk(
          captureAny(),
          targetRelays: captureAny(named: 'targetRelays'),
          timeout: captureAny(named: 'timeout'),
        ),
      ).captured;
      // mocktail returns captures ordered by argument name, not call order.
      final event = captured[0] as Event;
      final timeout = captured[1] as Duration;
      final targetRelays = captured[2] as List<String>;

      expect(event.kind, EventKind.relayListMetadata);
      expect(event.pubkey, pubkey);
      expect(event.tags, [
        ['r', 'wss://relay.divine.video'],
        ['r', 'wss://read.example', 'read'],
        ['r', 'wss://write.example', 'write'],
        ['r', 'wss://new.example'],
      ]);
      expect(targetRelays, contains('wss://relay.divine.video'));
      expect(targetRelays, contains('wss://purplepag.es'));
      // Settings blocks on this publish, so it must not inherit the 15s
      // default on top of the signer timeout.
      expect(timeout, lessThan(const Duration(seconds: 15)));
      verify(
        () => relayDiscoveryService.clearCache(Nip19.encodePubKey(pubkey)),
      ).called(1);
      expect(buildRepository().isDirty(pubkey), isFalse);
    },
  );

  test('skips without dirtying when the client has no signing keys', () async {
    when(() => nostrClient.hasKeys).thenReturn(false);
    when(() => nostrClient.publicKey).thenReturn('');

    final result = await buildRepository().publishConfiguredRelayList();

    expect(result.status, RelayListPublishStatus.skippedNoKeys);
    verifyNever(
      () => nostrClient.publishEventAwaitOk(
        any(),
        targetRelays: any(named: 'targetRelays'),
        timeout: any(named: 'timeout'),
      ),
    );
    expect(buildRepository().isDirty(pubkey), isFalse);
  });

  test('skips publishing in non-production environments', () async {
    final result = await buildRepository(
      environment: const EnvironmentConfig(environment: AppEnvironment.staging),
    ).publishConfiguredRelayList();

    expect(result.status, RelayListPublishStatus.skippedNonProduction);
    verifyNever(
      () => nostrClient.publishEventAwaitOk(
        any(),
        targetRelays: any(named: 'targetRelays'),
        timeout: any(named: 'timeout'),
      ),
    );
    expect(buildRepository().isDirty(pubkey), isFalse);
  });

  test(
    'marks dirty and does not clear cache when no indexer accepts',
    () async {
      when(
        () => nostrClient.publishEventAwaitOk(
          any(),
          targetRelays: any(named: 'targetRelays'),
          timeout: any(named: 'timeout'),
        ),
      ).thenAnswer((invocation) async {
        final event = invocation.positionalArguments.first as Event;
        return PublishOutcome(
          eventId: event.id,
          acceptedBy: const ['wss://relay.divine.video'],
          rejectedBy: const {},
          noResponseFrom: const [],
        );
      });

      final repository = buildRepository();
      final result = await repository.publishConfiguredRelayList();

      expect(result.status, RelayListPublishStatus.failed);
      expect(repository.isDirty(pubkey), isTrue);
      verifyNever(() => relayDiscoveryService.clearCache(any()));
    },
  );

  test(
    'retryDirtyPublish republishes only when the dirty flag is set',
    () async {
      final repository = buildRepository();

      expect(
        await repository.retryDirtyPublish(),
        isA<RelayListPublishResult>()
            .having(
              (result) => result.status,
              'status',
              RelayListPublishStatus.skippedNotDirty,
            )
            .having((result) => result.localOnly, 'localOnly', isFalse),
      );
      verifyNever(
        () => nostrClient.publishEventAwaitOk(
          any(),
          targetRelays: any(named: 'targetRelays'),
          timeout: any(named: 'timeout'),
        ),
      );

      await prefs.setBool('relay_list_publish_dirty_$pubkey', true);
      final result = await repository.retryDirtyPublish();

      expect(result.status, RelayListPublishStatus.published);
      verify(
        () => nostrClient.publishEventAwaitOk(
          any(),
          targetRelays: any(named: 'targetRelays'),
          timeout: any(named: 'timeout'),
        ),
      ).called(1);
      expect(repository.isDirty(pubkey), isFalse);
    },
  );
}
