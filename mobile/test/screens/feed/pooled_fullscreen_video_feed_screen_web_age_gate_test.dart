import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/fullscreen_feed/fullscreen_feed_bloc.dart';
import 'package:openvine/blocs/video_playback_status/video_playback_status_cubit.dart';
import 'package:openvine/blocs/video_playback_status/video_playback_status_state.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/screens/feed/pooled_fullscreen_video_feed_screen.dart';
import 'package:openvine/services/media_auth_interceptor.dart';
import 'package:openvine/services/web_video_access_service.dart';
import 'package:openvine/widgets/video_feed_item/moderated_content_overlay.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart'
    as video_platform;

import '../../helpers/test_provider_overrides.dart';
import '../../helpers/web_video_player_test_doubles.dart';
import '../../test_data/video_test_data.dart';

class _MockFullscreenFeedBloc
    extends MockBloc<FullscreenFeedEvent, FullscreenFeedState>
    implements FullscreenFeedBloc {}

class _MockMediaAuthInterceptor extends Mock implements MediaAuthInterceptor {}

class _MockWebVideoAccessService extends Mock
    implements WebVideoAccessService {}

class _FailingVideoPlayerController extends FakeVideoPlayerController {
  _FailingVideoPlayerController({required super.source});

  @override
  Future<void> initialize() async {
    throw Exception('401 protected media');
  }
}

const _testVideoId =
    'a1b2c3d4e5f6789012345678901234567890abcdef123456789012345678901234';
const _testPubkey =
    'd4e5f6789012345678901234567890abcdef123456789012345678901234a1b2c3';

void main() {
  group('PooledFullscreenVideoFeedScreen web age-gated playback', () {
    late _MockFullscreenFeedBloc mockBloc;
    late MockAuthService mockAuthService;
    late MockProfileRepository mockProfileRepository;
    late video_platform.VideoPlayerPlatform originalPlatform;
    late _MockMediaAuthInterceptor mockMediaAuthInterceptor;
    late _MockWebVideoAccessService mockWebVideoAccessService;

    setUpAll(() {
      registerFallbackValue(const FullscreenFeedStarted());
    });

    setUp(() {
      mockBloc = _MockFullscreenFeedBloc();
      mockAuthService = createMockAuthService();
      mockProfileRepository = createMockProfileRepository();
      originalPlatform = video_platform.VideoPlayerPlatform.instance;
      video_platform.VideoPlayerPlatform.instance = FakeVideoPlayerPlatform();
      mockMediaAuthInterceptor = _MockMediaAuthInterceptor();
      mockWebVideoAccessService = _MockWebVideoAccessService();

      when(() => mockBloc.stream).thenAnswer((_) => const Stream.empty());
      when(() => mockAuthService.currentPublicKeyHex).thenReturn(null);
    });

    tearDown(() {
      video_platform.VideoPlayerPlatform.instance = originalPlatform;
    });

    testWidgets(
      'shows Verify age and retries web playback with an authenticated object URL',
      (tester) async {
        const sha256 =
            'bf8b2b09a0ec795b362a4b2445f40118028ac138335894e0f2e16d97e428e564';
        const videoUrl = 'https://media.divine.video/$sha256';
        const headers = {'Authorization': 'Nostr viewer-token'};
        final video = createTestVideoEvent(
          id: _testVideoId,
          pubkey: _testPubkey,
          videoUrl: videoUrl,
          sha256: sha256,
          mimeType: 'video/mp4',
        );
        final state = FullscreenFeedState(
          status: FullscreenFeedStatus.ready,
          videos: [video],
        );
        when(() => mockBloc.state).thenReturn(state);

        when(
          () => mockWebVideoAccessService.confirmFailureStatus(videoUrl),
        ).thenAnswer((_) async => PlaybackStatus.ageRestricted);
        when(
          () => mockMediaAuthInterceptor.handleUnauthorizedMedia(
            context: any(named: 'context'),
            sha256Hash: sha256,
            url: videoUrl,
            serverUrl: 'https://media.divine.video',
            category: 'video',
          ),
        ).thenAnswer((_) async => headers);
        when(
          () => mockWebVideoAccessService.resolveAuthenticatedPlayback(
            url: videoUrl,
            headers: headers,
            fallbackMimeType: 'video/mp4',
          ),
        ).thenAnswer(
          (_) async => const ResolvedWebVideoSource(
            url: 'blob:verified-video',
            isObjectUrl: true,
          ),
        );

        final requestedUrls = <String>[];

        await tester.pumpWidget(
          testMaterialApp(
            mockAuthService: mockAuthService,
            mockProfileRepository: mockProfileRepository,
            additionalOverrides: [
              mediaAuthInterceptorProvider.overrideWithValue(
                mockMediaAuthInterceptor,
              ),
              webVideoAccessServiceProvider.overrideWithValue(
                mockWebVideoAccessService,
              ),
            ],
            home: MultiBlocProvider(
              providers: [
                BlocProvider<FullscreenFeedBloc>.value(value: mockBloc),
                BlocProvider<VideoPlaybackStatusCubit>(
                  create: (_) => VideoPlaybackStatusCubit(),
                ),
              ],
              child: FullscreenFeedContent(
                webControllerFactory: ({required url, required headers}) {
                  requestedUrls.add(url.toString());
                  if (url.toString() == 'blob:verified-video') {
                    return FakeVideoPlayerController(source: url.toString());
                  }
                  return _FailingVideoPlayerController(source: url.toString());
                },
              ),
            ),
          ),
        );

        await tester.pump();
        await tester.pump();

        expect(find.byType(ModeratedContentOverlay), findsOneWidget);
        expect(
          find.text(ModeratedContentOverlayStrings.verifyAgeLabel),
          findsOneWidget,
        );

        await tester.tap(
          find.text(ModeratedContentOverlayStrings.verifyAgeLabel),
        );
        await tester.pump();
        await tester.pump();

        verify(
          () => mockWebVideoAccessService.confirmFailureStatus(videoUrl),
        ).called(1);
        verify(
          () => mockMediaAuthInterceptor.handleUnauthorizedMedia(
            context: any(named: 'context'),
            sha256Hash: sha256,
            url: videoUrl,
            serverUrl: 'https://media.divine.video',
            category: 'video',
          ),
        ).called(1);
        verify(
          () => mockWebVideoAccessService.resolveAuthenticatedPlayback(
            url: videoUrl,
            headers: headers,
            fallbackMimeType: 'video/mp4',
          ),
        ).called(1);
        expect(requestedUrls, contains('blob:verified-video'));
      },
      skip: !kIsWeb,
    );
  });
}
