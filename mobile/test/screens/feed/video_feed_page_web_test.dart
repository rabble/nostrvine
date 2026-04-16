import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/video_feed/video_feed_bloc.dart';
import 'package:openvine/blocs/video_playback_status/video_playback_status_cubit.dart';
import 'package:openvine/router/router.dart';
import 'package:openvine/screens/feed/video_feed_page.dart';
import 'package:openvine/widgets/video_feed_item/actions/actions.dart';
import 'package:openvine/widgets/web_video_feed.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart'
    as video_platform;

import '../../helpers/test_provider_overrides.dart';
import '../../helpers/web_video_player_test_doubles.dart';
import '../../test_data/video_test_data.dart';

class MockVideoFeedBloc extends MockBloc<VideoFeedEvent, VideoFeedState>
    implements VideoFeedBloc {}

void main() {
  group('VideoFeedView web', () {
    late MockVideoFeedBloc mockBloc;
    late MockProfileRepository mockProfileRepository;
    late video_platform.VideoPlayerPlatform originalPlatform;
    late FakeVideoPlayerController webController;

    setUpAll(() {
      registerFallbackValue(const VideoFeedStarted());
    });

    setUp(() {
      mockBloc = MockVideoFeedBloc();
      mockProfileRepository = createMockProfileRepository();
      originalPlatform = video_platform.VideoPlayerPlatform.instance;
      video_platform.VideoPlayerPlatform.instance = FakeVideoPlayerPlatform();
      webController = FakeVideoPlayerController();
      when(() => mockBloc.stream).thenAnswer((_) => const Stream.empty());
    });

    tearDown(() {
      video_platform.VideoPlayerPlatform.instance = originalPlatform;
    });

    testWidgets(
      'renders Auto action in the home web overlay',
      (tester) async {
        final video = createTestVideoEvent(
          id: 'a1b2c3d4e5f6789012345678901234567890abcdef123456789012345678901234',
          pubkey:
              'd4e5f6789012345678901234567890abcdef123456789012345678901234a1b2c3',
          videoUrl: 'https://example.com/video1.mp4',
        );
        final state = VideoFeedState(
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
              ],
              child: VideoFeedView(
                webControllerFactory:
                    ({
                      required url,
                      required headers,
                    }) => webController,
              ),
            ),
          ),
        );
        await tester.pump();

        expect(find.byType(WebVideoFeed), findsOneWidget);
        expect(find.byType(AutoActionButton), findsOneWidget);
      },
      skip: !kIsWeb,
    );
  });
}
