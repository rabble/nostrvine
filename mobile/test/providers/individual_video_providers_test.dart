import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/providers/individual_video_providers.dart';
import 'package:openvine/services/media_viewer_auth_service.dart';

class MockMediaViewerAuthService extends Mock
    implements MediaViewerAuthService {}

void main() {
  late MockMediaViewerAuthService mockMediaViewerAuthService;

  setUp(() {
    mockMediaViewerAuthService = MockMediaViewerAuthService();
  });

  group('createViewerAuthHeadersForVideo', () {
    test('prefers the event sha256 when it is present', () async {
      final params = VideoControllerParams(
        videoId: 'video-1',
        videoUrl:
            'https://media.divine.video/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa/720p.mp4',
        videoEvent: _videoEvent(
          sha256:
              'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
        ),
      );
      when(
        () => mockMediaViewerAuthService.createAuthHeaders(
          sha256Hash: any(named: 'sha256Hash'),
          url: any(named: 'url'),
          serverUrl: any(named: 'serverUrl'),
        ),
      ).thenAnswer((_) async => {'Authorization': 'Nostr blossom'});

      final headers = await createViewerAuthHeadersForVideo(
        mediaViewerAuthService: mockMediaViewerAuthService,
        params: params,
      );

      expect(headers, equals({'Authorization': 'Nostr blossom'}));
      verify(
        () => mockMediaViewerAuthService.createAuthHeaders(
          sha256Hash:
              'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
          url:
              'https://media.divine.video/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa/720p.mp4',
          serverUrl: 'https://media.divine.video',
        ),
      ).called(1);
    });

    test('falls back to the sha256 embedded in the media URL', () async {
      const params = VideoControllerParams(
        videoId: 'video-2',
        videoUrl:
            'https://media.divine.video/cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc/720p.mp4',
      );
      when(
        () => mockMediaViewerAuthService.createAuthHeaders(
          sha256Hash: any(named: 'sha256Hash'),
          url: any(named: 'url'),
          serverUrl: any(named: 'serverUrl'),
        ),
      ).thenAnswer((_) async => {'Authorization': 'Nostr extracted'});

      final headers = await createViewerAuthHeadersForVideo(
        mediaViewerAuthService: mockMediaViewerAuthService,
        params: params,
      );

      expect(headers, equals({'Authorization': 'Nostr extracted'}));
      verify(
        () => mockMediaViewerAuthService.createAuthHeaders(
          sha256Hash:
              'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc',
          url:
              'https://media.divine.video/cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc/720p.mp4',
          serverUrl: 'https://media.divine.video',
        ),
      ).called(1);
    });

    test(
      'falls back to URL-only auth when no sha256 can be resolved',
      () async {
        const params = VideoControllerParams(
          videoId: 'video-3',
          videoUrl: 'https://cdn.example.com/protected/video/master.m3u8',
        );
        when(
          () => mockMediaViewerAuthService.createAuthHeaders(
            sha256Hash: any(named: 'sha256Hash'),
            url: any(named: 'url'),
            serverUrl: any(named: 'serverUrl'),
          ),
        ).thenAnswer((_) async => {'Authorization': 'Nostr nip98'});

        final headers = await createViewerAuthHeadersForVideo(
          mediaViewerAuthService: mockMediaViewerAuthService,
          params: params,
        );

        expect(headers, equals({'Authorization': 'Nostr nip98'}));
        verify(
          () => mockMediaViewerAuthService.createAuthHeaders(
            url: 'https://cdn.example.com/protected/video/master.m3u8',
            serverUrl: 'https://cdn.example.com',
          ),
        ).called(1);
      },
    );
  });
}

VideoEvent _videoEvent({String? sha256}) {
  return VideoEvent(
    id: 'event-id',
    pubkey: '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
    createdAt: 1,
    content: 'content',
    timestamp: DateTime.fromMillisecondsSinceEpoch(1000),
    sha256: sha256,
  );
}
