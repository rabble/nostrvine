import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/services/media_viewer_auth_service.dart';
import 'package:openvine/widgets/web_video_auth_header_provider.dart';

class _MockMediaViewerAuthService extends Mock
    implements MediaViewerAuthService {}

void main() {
  group(buildWebVideoAuthHeaderProvider, () {
    late _MockMediaViewerAuthService service;

    setUp(() {
      service = _MockMediaViewerAuthService();
    });

    test(
      'extracts sha256 and origin from a Blossom URL and forwards to the '
      'auth service',
      () async {
        const sha256 =
            'fedcba9876543210fedcba9876543210fedcba9876543210fedcba9876543210';
        const url = 'https://media.divine.video/$sha256';
        when(
          () => service.createAuthHeaders(
            sha256Hash: sha256,
            url: url,
            serverUrl: 'https://media.divine.video',
          ),
        ).thenAnswer(
          (_) async => const {'Authorization': 'Nostr signed-token'},
        );

        final provider = buildWebVideoAuthHeaderProvider(service);
        final header = await provider(url, 'GET');

        expect(header, equals('Nostr signed-token'));
        verify(
          () => service.createAuthHeaders(
            sha256Hash: sha256,
            url: url,
            serverUrl: 'https://media.divine.video',
          ),
        ).called(1);
      },
    );

    test('extracts sha256 from an hls manifest segment suffix', () async {
      const sha256 =
          'a9bbbce1b03958553a5ee1546140d5d930b8a86c1fa967ea874fb5241bd5e41c';
      const url = 'https://media.divine.video/$sha256/hls/master.m3u8';
      when(
        () => service.createAuthHeaders(
          sha256Hash: any(named: 'sha256Hash'),
          url: any(named: 'url'),
          serverUrl: any(named: 'serverUrl'),
        ),
      ).thenAnswer(
        (_) async => const {'Authorization': 'Nostr signed-manifest'},
      );

      final provider = buildWebVideoAuthHeaderProvider(service);
      final header = await provider(url, 'GET');

      expect(header, equals('Nostr signed-manifest'));
      verify(
        () => service.createAuthHeaders(
          sha256Hash: sha256,
          url: url,
          serverUrl: 'https://media.divine.video',
        ),
      ).called(1);
    });

    test('returns null when the auth service returns null', () async {
      when(
        () => service.createAuthHeaders(
          sha256Hash: any(named: 'sha256Hash'),
          url: any(named: 'url'),
          serverUrl: any(named: 'serverUrl'),
        ),
      ).thenAnswer((_) async => null);

      final provider = buildWebVideoAuthHeaderProvider(service);
      final header = await provider(
        'https://media.divine.video/'
            'fedcba9876543210fedcba9876543210fedcba9876543210fedcba9876543210',
        'GET',
      );

      expect(header, isNull);
    });

    test('returns null when the Authorization header is absent', () async {
      when(
        () => service.createAuthHeaders(
          sha256Hash: any(named: 'sha256Hash'),
          url: any(named: 'url'),
          serverUrl: any(named: 'serverUrl'),
        ),
      ).thenAnswer((_) async => const {'X-Other': 'value'});

      final provider = buildWebVideoAuthHeaderProvider(service);
      final header = await provider(
        'https://media.divine.video/'
            'fedcba9876543210fedcba9876543210fedcba9876543210fedcba9876543210',
        'GET',
      );

      expect(header, isNull);
    });

    test(
      'passes null sha256 for URLs without a 64-char hex segment',
      () async {
        const url = 'https://example.com/video.mp4';
        String? capturedSha256 = 'sentinel';
        when(
          () => service.createAuthHeaders(
            sha256Hash: any(named: 'sha256Hash'),
            url: url,
            serverUrl: 'https://example.com',
          ),
        ).thenAnswer((invocation) async {
          capturedSha256 = invocation.namedArguments[#sha256Hash] as String?;
          return null;
        });

        final provider = buildWebVideoAuthHeaderProvider(service);
        await provider(url, 'GET');

        expect(capturedSha256, isNull);
      },
    );
  });
}
