import 'package:http/testing.dart';
import 'package:nostr_app_bridge_repository/nostr_app_bridge_repository.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/signer/nostr_signer.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:test/test.dart';

void main() {
  group('NostrAppBridgeService', () {
    late SharedPreferences sharedPreferences;
    late NostrAppGrantStore grantStore;
    late NostrAppBridgePolicy policy;
    late _FakeAuthProvider authProvider;
    late _FakeSigner signer;
    late NostrAppBridgeService service;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      sharedPreferences = await SharedPreferences.getInstance();
      grantStore = NostrAppGrantStore(
        sharedPreferences: sharedPreferences,
      );
      policy = NostrAppBridgePolicy(
        grantStore: grantStore,
        currentUserPubkey: 'f' * 64,
      );
      authProvider = _FakeAuthProvider();
      signer = _FakeSigner();

      service = NostrAppBridgeService(
        authProvider: authProvider,
        policy: policy,
        signerFactory: () => signer,
      );
    });

    test(
      'returns the current public key for getPublicKey',
      () async {
        final result = await service.handleRequest(
          app: _app(),
          origin: Uri.parse('https://primal.net'),
          method: 'getPublicKey',
          args: const {},
        );

        expect(result.success, isTrue);
        expect(result.data, 'f' * 64);
      },
    );

    test(
      'returns the current relay map for getRelays',
      () async {
        final result = await service.handleRequest(
          app: _app(
            allowedMethods: const [
              'getPublicKey',
              'signEvent',
              'getRelays',
            ],
          ),
          origin: Uri.parse('https://primal.net'),
          method: 'getRelays',
          args: const {},
        );

        expect(result.success, isTrue);
        expect(result.data, {
          'wss://relay.divine.video': {
            'read': true,
            'write': true,
          },
          'wss://relay.primal.net': {
            'read': true,
            'write': false,
          },
        });
      },
    );

    test(
      'fails closed when signEvent requests a blocked kind',
      () async {
        final result = await service.handleRequest(
          app: _app(),
          origin: Uri.parse('https://primal.net'),
          method: 'signEvent',
          args: {
            'event': {
              'kind': 4,
              'content': 'hello',
              'tags': const <List<String>>[],
            },
          },
        );

        expect(result.success, isFalse);
        expect(result.errorCode, 'blocked_event_kind');
      },
    );

    test(
      'prompts once for signEvent and remembers the grant',
      () async {
        final app = _app(promptRequiredFor: const ['signEvent']);

        final firstResult = await service.handleRequest(
          app: app,
          origin: Uri.parse('https://primal.net'),
          method: 'signEvent',
          args: {
            'event': {
              'kind': 1,
              'content': 'hello',
              'tags': const <List<String>>[],
            },
          },
          promptForPermission: (_) async => true,
        );

        final secondResult = await service.handleRequest(
          app: app,
          origin: Uri.parse('https://primal.net'),
          method: 'signEvent',
          args: {
            'event': {
              'kind': 1,
              'content': 'again',
              'tags': const <List<String>>[],
            },
          },
        );

        expect(firstResult.success, isTrue);
        expect(secondResult.success, isTrue);
        expect(
          grantStore.hasGrant(
            userPubkey: 'f' * 64,
            appId: app.slug,
            origin: 'https://primal.net',
            capability: 'signEvent:1',
          ),
          isTrue,
        );
      },
    );

    test(
      'routes nip44.encrypt through the signer',
      () async {
        final result = await service.handleRequest(
          app: _app(
            allowedMethods: const [
              'getPublicKey',
              'signEvent',
              'nip44.encrypt',
            ],
          ),
          origin: Uri.parse('https://primal.net'),
          method: 'nip44.encrypt',
          args: const {
            'pubkey':
                'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
                'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
            'plaintext': 'top secret',
          },
        );

        expect(result.success, isTrue);
        expect(result.data, 'ciphertext-for-top secret');
      },
    );

    test(
      'records audit events when the app id is numeric',
      () async {
        final auditService = NostrAppAuditService(
          workerBaseUri: Uri.parse('https://apps.divine.video'),
          authTokenProvider:
              ({
                required url,
                required method,
                required payload,
              }) async => null,
          httpClient: MockClient(
            (_) async => throw UnimplementedError(),
          ),
        );
        service = NostrAppBridgeService(
          authProvider: authProvider,
          policy: policy,
          signerFactory: () => signer,
          auditService: auditService,
        );

        final result = await service.handleRequest(
          app: _app(id: '17'),
          origin: Uri.parse('https://primal.net'),
          method: 'getPublicKey',
          args: const {},
        );

        expect(result.success, isTrue);
        expect(auditService.queuedEvents, hasLength(1));
        expect(auditService.queuedEvents.single.appId, 17);
        expect(
          auditService.queuedEvents.single.decision,
          NostrAppAuditDecision.allowed,
        );
      },
    );
  });
}

NostrAppDirectoryEntry _app({
  String id = 'primal-app',
  List<String> allowedMethods = const [
    'getPublicKey',
    'signEvent',
  ],
  List<String> promptRequiredFor = const [],
}) {
  return NostrAppDirectoryEntry(
    id: id,
    slug: 'primal',
    name: 'Primal',
    tagline: 'A social client',
    description: 'A vetted Nostr app.',
    iconUrl: 'https://primal.net/icon.png',
    launchUrl: 'https://primal.net/app',
    allowedOrigins: const ['https://primal.net'],
    allowedMethods: allowedMethods,
    allowedSignEventKinds: const [1],
    promptRequiredFor: promptRequiredFor,
    status: 'approved',
    sortOrder: 1,
    createdAt: DateTime.utc(2026, 3, 25),
    updatedAt: DateTime.utc(2026, 3, 25),
  );
}

class _FakeAuthProvider implements BridgeAuthProvider {
  @override
  String? get currentPublicKeyHex => 'f' * 64;

  @override
  List<BridgeRelay> get userRelays => const [
    BridgeRelay(url: 'wss://relay.divine.video'),
    BridgeRelay(
      url: 'wss://relay.primal.net',
      write: false,
    ),
  ];

  @override
  Future<BridgeSignedEvent?> createAndSignEvent({
    required int kind,
    required String content,
    required List<List<String>> tags,
    int? createdAt,
  }) async {
    final event = Event(
      'f' * 64,
      kind,
      tags,
      content,
      createdAt: createdAt,
    );
    return BridgeSignedEvent(json: event.toJson());
  }
}

class _FakeSigner implements NostrSigner {
  @override
  void close() {}

  @override
  Future<String?> decrypt(
    String pubkey,
    String ciphertext,
  ) async {
    return 'decrypted-$ciphertext';
  }

  @override
  Future<String?> encrypt(
    String pubkey,
    String plaintext,
  ) async {
    return 'encrypted-$plaintext';
  }

  @override
  Future<String?> getPublicKey() async {
    return 'f' * 64;
  }

  @override
  Future<Map<dynamic, dynamic>?> getRelays() async {
    return null;
  }

  @override
  Future<String?> nip44Decrypt(
    String pubkey,
    String ciphertext,
  ) async {
    return 'plaintext-for-$ciphertext';
  }

  @override
  Future<String?> nip44Encrypt(
    String pubkey,
    String plaintext,
  ) async {
    return 'ciphertext-for-$plaintext';
  }

  @override
  Future<Event?> signEvent(Event event) async {
    return event;
  }
}
