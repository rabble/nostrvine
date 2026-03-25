import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/signer/nostr_signer.dart';
import 'package:openvine/models/nostr_app_audit_event.dart';
import 'package:openvine/models/nostr_app_directory_entry.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/nip98_auth_service.dart';
import 'package:openvine/services/nostr_app_audit_service.dart';
import 'package:openvine/services/nostr_app_bridge_policy.dart';
import 'package:openvine/services/nostr_app_bridge_service.dart';
import 'package:openvine/services/nostr_app_grant_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockAuthService extends Mock implements AuthService {}

class _MockNip98AuthService extends Mock implements Nip98AuthService {}

void main() {
  group('NostrAppBridgeService', () {
    late SharedPreferences sharedPreferences;
    late NostrAppGrantStore grantStore;
    late NostrAppBridgePolicy policy;
    late _MockAuthService authService;
    late _FakeSigner signer;
    late _MockNip98AuthService nip98AuthService;
    late NostrAppBridgeService service;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      sharedPreferences = await SharedPreferences.getInstance();
      grantStore = NostrAppGrantStore(sharedPreferences: sharedPreferences);
      policy = NostrAppBridgePolicy(
        grantStore: grantStore,
        currentUserPubkey: 'f' * 64,
      );
      authService = _MockAuthService();
      signer = _FakeSigner();
      nip98AuthService = _MockNip98AuthService();

      when(() => authService.currentPublicKeyHex).thenReturn('f' * 64);
      when(() => authService.isAuthenticated).thenReturn(true);
      when(
        () => authService.createAndSignEvent(
          kind: any(named: 'kind'),
          content: any(named: 'content'),
          tags: any(named: 'tags'),
          biometricPrompt: any(named: 'biometricPrompt'),
          createdAt: any(named: 'createdAt'),
        ),
      ).thenAnswer((invocation) async {
        return Event(
          'f' * 64,
          invocation.namedArguments[#kind] as int,
          (invocation.namedArguments[#tags] as List<List<String>>?) ?? const [],
          invocation.namedArguments[#content] as String,
          createdAt: invocation.namedArguments[#createdAt] as int?,
        );
      });

      service = NostrAppBridgeService(
        authService: authService,
        policy: policy,
        signerFactory: (_) => signer,
      );
    });

    test('returns the current public key for getPublicKey', () async {
      final result = await service.handleRequest(
        app: _app(),
        origin: Uri.parse('https://primal.net'),
        method: 'getPublicKey',
        args: const {},
      );

      expect(result.success, isTrue);
      expect(result.data, 'f' * 64);
    });

    test('returns unsupported_method for unknown bridge methods', () async {
      final result = await service.handleRequest(
        app: _app(),
        origin: Uri.parse('https://primal.net'),
        method: 'getRelays',
        args: const {},
      );

      expect(result.success, isFalse);
      expect(result.errorCode, 'unsupported_method');
    });

    test('fails closed when signEvent requests a blocked kind', () async {
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
    });

    test('prompts once for signEvent and remembers the grant', () async {
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
          appId: app.id,
          origin: 'https://primal.net',
          capability: 'signEvent:1',
        ),
        isTrue,
      );
    });

    test('routes nip44.encrypt through the signer', () async {
      final result = await service.handleRequest(
        app: _app(
          allowedMethods: const ['getPublicKey', 'signEvent', 'nip44.encrypt'],
        ),
        origin: Uri.parse('https://primal.net'),
        method: 'nip44.encrypt',
        args: const {
          'pubkey':
              'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
          'plaintext': 'top secret',
        },
      );

      expect(result.success, isTrue);
      expect(result.data, 'ciphertext-for-top secret');
    });

    test('records audit events when the app id is numeric', () async {
      when(
        () => nip98AuthService.createAuthToken(
          url: any(named: 'url'),
          method: HttpMethod.post,
          payload: any(named: 'payload'),
        ),
      ).thenAnswer((_) async => null);
      final auditService = NostrAppAuditService(
        workerBaseUri: Uri.parse('https://apps.divine.video'),
        nip98AuthService: nip98AuthService,
        httpClient: MockClient((_) async => throw UnimplementedError()),
      );
      service = NostrAppBridgeService(
        authService: authService,
        policy: policy,
        signerFactory: (_) => signer,
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
    });
  });
}

NostrAppDirectoryEntry _app({
  String id = 'primal-app',
  List<String> allowedMethods = const ['getPublicKey', 'signEvent'],
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

class _FakeSigner implements NostrSigner {
  @override
  void close() {}

  @override
  Future<String?> decrypt(String pubkey, String ciphertext) async {
    return 'decrypted-$ciphertext';
  }

  @override
  Future<String?> encrypt(String pubkey, String plaintext) async {
    return 'encrypted-$plaintext';
  }

  @override
  Future<String?> getPublicKey() async {
    return 'f' * 64;
  }

  @override
  Future<Map?> getRelays() async {
    return null;
  }

  @override
  Future<String?> nip44Decrypt(String pubkey, String ciphertext) async {
    return 'plaintext-for-$ciphertext';
  }

  @override
  Future<String?> nip44Encrypt(String pubkey, String plaintext) async {
    return 'ciphertext-for-$plaintext';
  }

  @override
  Future<Event?> signEvent(Event event) async {
    return event;
  }
}
