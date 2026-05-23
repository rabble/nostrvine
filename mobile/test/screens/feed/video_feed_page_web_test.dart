import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/video_feed/video_feed_bloc.dart';
import 'package:openvine/blocs/video_playback_status/video_playback_status_cubit.dart';
import 'package:openvine/blocs/video_volume/video_volume_cubit.dart';
import 'package:openvine/router/router.dart';
import 'package:openvine/screens/feed/video_feed_page.dart';
import 'package:openvine/widgets/video_feed_item/video_feed_item.dart';
import 'package:openvine/widgets/video_metrics_tracker.dart';
import 'package:openvine/widgets/web_video_feed.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart'
    as video_platform;

import '../../helpers/test_provider_overrides.dart';
import '../../helpers/web_video_player_test_doubles.dart';
import '../../test_data/video_test_data.dart';

class MockVideoFeedBloc extends MockBloc<VideoFeedEvent, VideoFeedBlocState>
    implements VideoFeedBloc {}

class _MockVideoVolumeCubit extends MockCubit<VideoVolumeState>
    implements VideoVolumeCubit {}

void main() {
  group('VideoFeedView web', () {
    late MockVideoFeedBloc mockBloc;
    late MockProfileRepository mockProfileRepository;
    late _MockVideoVolumeCubit videoVolumeCubit;
    late video_platform.VideoPlayerPlatform originalPlatform;
    late FakeVideoPlayerController webController;

    setUpAll(() {
      registerFallbackValue(const VideoFeedStarted());
    });

    setUp(() {
      mockBloc = MockVideoFeedBloc();
      mockProfileRepository = createMockProfileRepository();
      videoVolumeCubit = _MockVideoVolumeCubit();
      originalPlatform = video_platform.VideoPlayerPlatform.instance;
      video_platform.VideoPlayerPlatform.instance = FakeVideoPlayerPlatform();
      webController = FakeVideoPlayerController();
      when(() => mockBloc.stream).thenAnswer((_) => const Stream.empty());
      when(() => videoVolumeCubit.state).thenReturn(const VideoVolumeState());
    });

    tearDown(() {
      video_platform.VideoPlayerPlatform.instance = originalPlatform;
    });

    testWidgets('renders action column in the home web overlay', (
      tester,
    ) async {
      final video = createTestVideoEvent(
        id: 'a1b2c3d4e5f6789012345678901234567890abcdef123456789012345678901234',
        pubkey:
            'd4e5f6789012345678901234567890abcdef123456789012345678901234a1b2c3',
        videoUrl: 'https://example.com/video1.mp4',
      );
      final state = VideoFeedBlocState(
        status: VideoFeedStatus.success,
        videos: [video],
      );
      when(() => mockBloc.state).thenReturn(state);

      await tester.pumpWidget(
        testMaterialApp(
          additionalOverrides: [
            routerLocationStreamProvider.overrideWith(
              (ref) => Stream.value('/home'),
            ),
          ],
          mockProfileRepository: mockProfileRepository,
          home: MultiBlocProvider(
            providers: [
              BlocProvider<VideoFeedBloc>.value(value: mockBloc),
              BlocProvider<VideoPlaybackStatusCubit>(
                create: (_) => VideoPlaybackStatusCubit(),
              ),
              BlocProvider<VideoVolumeCubit>.value(value: videoVolumeCubit),
            ],
            child: VideoFeedView(
              webControllerFactory: ({required url, required headers}) =>
                  webController,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(WebVideoFeed), findsOneWidget);
      expect(find.byType(VideoMetricsTracker), findsOneWidget);
      expect(find.byType(VideoOverlayActionColumn), findsOneWidget);
    }, skip: !kIsWeb);
  });
}
