import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/models/viewer_auth_result.dart';
import 'package:openvine/providers/individual_video_providers.dart';
import 'package:openvine/providers/upload_media_providers.dart';
import 'package:openvine/services/media_viewer_auth_service.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart'
    as video_platform;

import '../helpers/web_video_player_test_doubles.dart';

class MockMediaViewerAuthService extends Mock
    implements MediaViewerAuthService {}

/// A [FakeVideoPlayerPlatform] that records the order of `pause` and `dispose`
/// and reports the player as initialized so `controller.pause()` reaches the
/// platform (an uninitialized controller's pause is a no-op).
class _RecordingVideoPlayerPlatform extends FakeVideoPlayerPlatform {
  _RecordingVideoPlayerPlatform(this.calls);

  final List<String> calls;

  @override
  Stream<video_platform.VideoEvent> videoEventsFor(int playerId) =>
      Stream.value(
        video_platform.VideoEvent(
          eventType: video_platform.VideoEventType.initialized,
          duration: const Duration(seconds: 1),
          size: const Size(1, 1),
        ),
      );

  @override
  Future<void> pause(int playerId) async => calls.add('pause');

  @override
  Future<void> dispose(int playerId) async => calls.add('dispose');
}

void main() {
  late MockMediaViewerAuthService mockMediaViewerAuthService;

  setUp(() {
    mockMediaViewerAuthService = MockMediaViewerAuthService();
  });

  group('fvpLiveControllerCount', () {
    test('rises when a controller is read and falls after disposal', () {
      // Controller construction reads mediaViewerAuthServiceProvider for
      // sync auth headers; override it so the read doesn't pull the whole
      // auth/Nostr graph into the test.
      final authService = MockMediaViewerAuthService();
      when(() => authService.canCreateHeaders).thenReturn(false);

      final baseline = fvpLiveControllerCount;
      final container = ProviderContainer(
        overrides: [
          mediaViewerAuthServiceProvider.overrideWithValue(authService),
        ],
      );

      const params = VideoControllerParams(
        videoId: 'gauge-video',
        videoUrl: 'https://example.com/gauge.mp4',
      );

      // Reading the provider constructs the controller (no initialize()),
      // which increments the gauge.
      container.read(individualVideoControllerProvider(params));
      expect(fvpLiveControllerCount, equals(baseline + 1));

      container.dispose();
      expect(fvpLiveControllerCount, equals(baseline));
    });
  });

  group('kMaxFvpControllers cap', () {
    ProviderContainer buildContainer() {
      final authService = MockMediaViewerAuthService();
      when(() => authService.canCreateHeaders).thenReturn(false);
      return ProviderContainer(
        overrides: [
          mediaViewerAuthServiceProvider.overrideWithValue(authService),
        ],
      );
    }

    test('caps live controllers when many idle videos are read', () async {
      final container = buildContainer();
      addTearDown(container.dispose);

      for (var i = 0; i < 20; i++) {
        container.read(
          individualVideoControllerProvider(
            VideoControllerParams(
              videoId: 'cap-video-$i',
              videoUrl: 'https://example.com/cap-$i.mp4',
            ),
          ),
        );
      }
      await Future<void>.delayed(Duration.zero);

      expect(fvpLiveControllerCount, lessThanOrEqualTo(kMaxFvpControllers));
    });

    test('never evicts an actively-listened controller under flood', () async {
      final container = buildContainer();
      addTearDown(container.dispose);

      const listenedParams = VideoControllerParams(
        videoId: 'v0',
        videoUrl: 'https://example.com/v0.mp4',
      );

      // Keep v0 on-screen via an active listener.
      final subscription = container.listen(
        individualVideoControllerProvider(listenedParams),
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(subscription.close);

      // Flood the registry with idle reads that must not evict v0.
      for (var i = 1; i <= 30; i++) {
        container.read(
          individualVideoControllerProvider(
            VideoControllerParams(
              videoId: 'flood-$i',
              videoUrl: 'https://example.com/flood-$i.mp4',
            ),
          ),
        );
      }
      await Future<void>.delayed(Duration.zero);

      // v0 was never torn down and still reads normally.
      expect(disposedControllersTracker.contains('v0'), isFalse);
      expect(
        () => container.read(individualVideoControllerProvider(listenedParams)),
        returnsNormally,
      );
    });

    test('tracks alternate params for the same video independently', () {
      final baseline = fvpLiveControllerCount;
      final container = buildContainer();

      const mediumParams = VideoControllerParams(
        videoId: 'same-video',
        videoUrl: 'https://example.com/same-video-720p.mp4',
      );
      const fallbackParams = VideoControllerParams(
        videoId: 'same-video',
        videoUrl: 'https://example.com/same-video-fallback.mp4',
      );

      container
        ..read(individualVideoControllerProvider(mediumParams))
        ..read(individualVideoControllerProvider(fallbackParams));

      expect(fvpLiveControllerCount, equals(baseline + 2));

      container.dispose();
      expect(fvpLiveControllerCount, equals(baseline));
    });
  });

  group('onDispose teardown', () {
    test('pauses the controller before disposing it', () async {
      final calls = <String>[];
      final previousPlatform = video_platform.VideoPlayerPlatform.instance;
      video_platform.VideoPlayerPlatform.instance =
          _RecordingVideoPlayerPlatform(calls);
      addTearDown(() {
        video_platform.VideoPlayerPlatform.instance = previousPlatform;
      });

      final authService = MockMediaViewerAuthService();
      when(() => authService.canCreateHeaders).thenReturn(false);
      final container = ProviderContainer(
        overrides: [
          mediaViewerAuthServiceProvider.overrideWithValue(authService),
        ],
      );
      addTearDown(container.dispose);

      const params = VideoControllerParams(
        videoId: 'dispose-order',
        videoUrl: 'https://example.com/dispose-order.mp4',
      );

      container.read(individualVideoControllerProvider(params));
      // Let create()/initialize() resolve so the controller is initialized.
      await Future<void>.delayed(const Duration(milliseconds: 50));

      container.dispose();
      // Flush the onDispose microtask (pause then dispose).
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(calls, containsAllInOrder(['pause', 'dispose']));
    });
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
      ).thenAnswer(
        (_) async =>
            const ViewerAuthAuthorized({'Authorization': 'Nostr blossom'}),
      );

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
      ).thenAnswer(
        (_) async =>
            const ViewerAuthAuthorized({'Authorization': 'Nostr extracted'}),
      );

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
        ).thenAnswer(
          (_) async =>
              const ViewerAuthAuthorized({'Authorization': 'Nostr nip98'}),
        );

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
