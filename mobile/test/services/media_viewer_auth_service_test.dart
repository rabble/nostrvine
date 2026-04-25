import 'package:blossom_upload_service/blossom_upload_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_sdk/event.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/media_viewer_auth_service.dart';
import 'package:openvine/services/nip98_auth_service.dart';

class MockAuthService extends Mock implements AuthService {}

class MockBlossomAuthService extends Mock implements BlossomAuthService {}

class MockNip98AuthService extends Mock implements Nip98AuthService {}

void main() {
  late MockAuthService mockAuthService;
  late MockBlossomAuthService mockBlossomAuthService;
  late MockNip98AuthService mockNip98AuthService;
  late MediaViewerAuthService service;

  setUpAll(() {
    registerFallbackValue(HttpMethod.get);
  });

  setUp(() {
    mockAuthService = MockAuthService();
    mockBlossomAuthService = MockBlossomAuthService();
    mockNip98AuthService = MockNip98AuthService();
    service = MediaViewerAuthService(
      authService: mockAuthService,
      blossomAuthService: mockBlossomAuthService,
      nip98AuthService: mockNip98AuthService,
    );
  });

  group('MediaViewerAuthService', () {
    test('prefers Blossom auth when a SHA-256 hash is known', () async {
      when(() => mockAuthService.isAuthenticated).thenReturn(true);
      when(
        () => mockBlossomAuthService.createGetAuthHeader(
          sha256Hash: any(named: 'sha256Hash'),
          serverUrl: any(named: 'serverUrl'),
        ),
      ).thenAnswer((_) async => 'Nostr blossom-token');

      final headers = await service.createAuthHeaders(
        sha256Hash: 'abc123',
        url: 'https://media.divine.video/abc123/720p.mp4',
        serverUrl: 'https://media.divine.video',
      );

      expect(headers, equals({'Authorization': 'Nostr blossom-token'}));
      verify(
        () => mockBlossomAuthService.createGetAuthHeader(
          sha256Hash: 'abc123',
          serverUrl: 'https://media.divine.video',
        ),
      ).called(1);
      verifyNever(
        () => mockNip98AuthService.createAuthToken(
          url: any(named: 'url'),
          method: any(named: 'method'),
        ),
      );
    });

    test('falls back to NIP-98 auth when only a URL is available', () async {
      when(() => mockAuthService.isAuthenticated).thenReturn(true);
      when(
        () => mockNip98AuthService.createAuthToken(
          url: any(named: 'url'),
          method: any(named: 'method'),
        ),
      ).thenAnswer(
        (_) async => Nip98Token(
          token: 'nip98-token',
          signedEvent: _createMockEvent(),
          createdAt: DateTime.now(),
          expiresAt: DateTime.now().add(const Duration(minutes: 10)),
        ),
      );

      final headers = await service.createAuthHeaders(
        url: 'https://media.divine.video/no-hash/playlist.m3u8',
      );

      expect(headers, equals({'Authorization': 'Nostr nip98-token'}));
      verify(
        () => mockNip98AuthService.createAuthToken(
          url: 'https://media.divine.video/no-hash/playlist.m3u8',
          method: HttpMethod.get,
        ),
      ).called(1);
      verifyNever(
        () => mockBlossomAuthService.createGetAuthHeader(
          sha256Hash: any(named: 'sha256Hash'),
          serverUrl: any(named: 'serverUrl'),
        ),
      );
    });

    test('returns null when the user is unauthenticated', () async {
      when(() => mockAuthService.isAuthenticated).thenReturn(false);

      final headers = await service.createAuthHeaders(
        sha256Hash: 'abc123',
        url: 'https://media.divine.video/abc123/720p.mp4',
      );

      expect(headers, isNull);
      verifyNever(
        () => mockBlossomAuthService.createGetAuthHeader(
          sha256Hash: any(named: 'sha256Hash'),
          serverUrl: any(named: 'serverUrl'),
        ),
      );
      verifyNever(
        () => mockNip98AuthService.createAuthToken(
          url: any(named: 'url'),
          method: any(named: 'method'),
        ),
      );
    });

    test('never returns both protocols for a single request', () async {
      when(() => mockAuthService.isAuthenticated).thenReturn(true);
      when(
        () => mockBlossomAuthService.createGetAuthHeader(
          sha256Hash: any(named: 'sha256Hash'),
          serverUrl: any(named: 'serverUrl'),
        ),
      ).thenAnswer((_) async => 'Nostr blossom-token');

      final headers = await service.createAuthHeaders(
        sha256Hash: 'abc123',
        url: 'https://media.divine.video/abc123/720p.mp4',
      );

      expect(headers, equals({'Authorization': 'Nostr blossom-token'}));
      verify(
        () => mockBlossomAuthService.createGetAuthHeader(sha256Hash: 'abc123'),
      ).called(1);
      verifyNever(
        () => mockNip98AuthService.createAuthToken(
          url: any(named: 'url'),
          method: any(named: 'method'),
        ),
      );
    });
  });
}

Event _createMockEvent() {
  final timestamp = (DateTime.now().millisecondsSinceEpoch / 1000).round();
  return Event.fromJson({
    'id': 'abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789',
    'kind': 27235,
    'pubkey':
        'aabbccdd0123456789abcdef0123456789abcdef0123456789abcdef01234567',
    'created_at': timestamp,
    'content': '',
    'tags': const <List<String>>[
      ['u', 'https://media.divine.video/no-hash/playlist.m3u8'],
      ['method', 'GET'],
    ],
    'sig':
        'deadbeef0123456789abcdef0123456789abcdef0123456789abcdef01234567'
        '89abcdef0123456789abcdef0123456789abcdef0123456789abcdef01234567'
        '89ab',
  });
}
