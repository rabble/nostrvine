import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/fullscreen_feed/fullscreen_feed_bloc.dart';
import 'package:openvine/blocs/video_playback_status/video_playback_status_cubit.dart';
import 'package:openvine/blocs/video_volume/video_volume_cubit.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/screens/feed/feed_settings_menu.dart';
import 'package:openvine/screens/feed/pooled_fullscreen_video_feed_screen.dart';
import 'package:openvine/services/media_auth_interceptor.dart';
import 'package:openvine/services/video_moderation_status_service.dart';
import 'package:openvine/widgets/video_feed_item/video_feed_item.dart';
import 'package:openvine/widgets/video_metrics_tracker.dart';
import 'package:openvine/widgets/web_video_feed.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart'
    as video_platform;

import '../../helpers/test_provider_overrides.dart';
import '../../helpers/web_video_player_test_doubles.dart';
import '../../test_data/video_test_data.dart';

class MockFullscreenFeedBloc
    extends MockBloc<FullscreenFeedEvent, FullscreenFeedState>
    implements FullscreenFeedBloc {}

class _MockVideoModerationStatusService extends Mock
    implements VideoModerationStatusService {}

class _MockVideoVolumeCubit extends MockCubit<VideoVolumeState>
    implements VideoVolumeCubit {}

class _FakeMediaAuthInterceptor implements MediaAuthInterceptor {
  bool didHandleUnauthorizedMedia = false;

  @override
  bool get canCreateAuthHeaders => true;

  @override
  Future<Map<String, String>?> handleUnauthorizedMedia({
    required BuildContext context,
    String? sha256Hash,
    String? url,
    String? serverUrl,
    String? category,
  }) async {
    didHandleUnauthorizedMedia = true;
    return {'Authorization': 'Bearer test'};
  }
}

const _testVideoId =
    'a1b2c3d4e5f6789012345678901234567890abcdef123456789012345678901234';
const _testPubkey =
    'd4e5f6789012345678901234567890abcdef123456789012345678901234a1b2c3';

void main() {
  group('PooledFullscreenVideoFeedScreen web', () {
    late MockFullscreenFeedBloc mockBloc;
    late MockAuthService mockAuthService;
    late MockProfileRepository mockProfileRepository;
    late _MockVideoVolumeCubit videoVolumeCubit;
    late StreamController<FullscreenFeedState> stateController;
    late video_platform.VideoPlayerPlatform originalPlatform;
    late FakeVideoPlayerController webController;

    setUpAll(() {
      registerFallbackValue(const FullscreenFeedStarted());
    });

    setUp(() {
      mockBloc = MockFullscreenFeedBloc();
      mockAuthService = createMockAuthService();
      mockProfileRepository = createMockProfileRepository();
      videoVolumeCubit = _MockVideoVolumeCubit();
      stateController = StreamController<FullscreenFeedState>.broadcast();
      originalPlatform = video_platform.VideoPlayerPlatform.instance;
      video_platform.VideoPlayerPlatform.instance = FakeVideoPlayerPlatform();
      webController = FakeVideoPlayerController();

      when(() => mockBloc.stream).thenAnswer((_) => stateController.stream);
      when(() => videoVolumeCubit.state).thenReturn(const VideoVolumeState());
      when(() => mockAuthService.currentPublicKeyHex).thenReturn(null);
    });

    tearDown(() async {
      video_platform.VideoPlayerPlatform.instance = originalPlatform;
      await stateController.close();
    });

    testWidgets('renders social controls overlay for web video feed', (
      tester,
    ) async {
      final video = createTestVideoEvent(id: _testVideoId, pubkey: _testPubkey);
      final state = FullscreenFeedState(
        status: FullscreenFeedStatus.ready,
        videos: [video],
      );
      when(() => mockBloc.state).thenReturn(state);

      await tester.pumpWidget(
        testMaterialApp(
          mockAuthService: mockAuthService,
          mockProfileRepository: mockProfileRepository,
          home: MultiBlocProvider(
            providers: [
              BlocProvider<FullscreenFeedBloc>.value(value: mockBloc),
              BlocProvider<VideoVolumeCubit>.value(value: videoVolumeCubit),
              BlocProvider<VideoPlaybackStatusCubit>(
                create: (_) => VideoPlaybackStatusCubit(),
              ),
            ],
            child: FullscreenFeedContent(
              webControllerFactory: ({required url, required headers}) =>
                  webController,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(WebVideoFeed), findsOneWidget);
      expect(find.byType(VideoMetricsTracker), findsOneWidget);
      expect(find.byType(VideoOverlayActions), findsOneWidget);
    }, skip: !kIsWeb);

    testWidgets('renders settings menu in the fullscreen web overlay', (
      tester,
    ) async {
      final video = createTestVideoEvent(id: _testVideoId, pubkey: _testPubkey);
      final state = FullscreenFeedState(
        status: FullscreenFeedStatus.ready,
        videos: [video],
      );
      when(() => mockBloc.state).thenReturn(state);

      await tester.pumpWidget(
        testMaterialApp(
          mockAuthService: mockAuthService,
          mockProfileRepository: mockProfileRepository,
          home: MultiBlocProvider(
            providers: [
              BlocProvider<FullscreenFeedBloc>.value(value: mockBloc),
              BlocProvider<VideoVolumeCubit>.value(value: videoVolumeCubit),
              BlocProvider<VideoPlaybackStatusCubit>(
                create: (_) => VideoPlaybackStatusCubit(),
              ),
            ],
            child: FullscreenFeedContent(
              webControllerFactory: ({required url, required headers}) =>
                  webController,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(FeedSettingsMenu), findsOneWidget);
    }, skip: !kIsWeb);

    testWidgets('renders restricted content while web video is loading', (
      tester,
    ) async {
      const sha256 =
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
      final video = createTestVideoEvent(
        id: _testVideoId,
        pubkey: _testPubkey,
        sha256: sha256,
        videoUrl: 'https://media.divine.video/$sha256',
      );
      final state = FullscreenFeedState(
        status: FullscreenFeedStatus.ready,
        videos: [video],
      );
      final moderationService = _MockVideoModerationStatusService();
      when(() => mockBloc.state).thenReturn(state);
      when(() => moderationService.fetchStatus(sha256)).thenAnswer(
        (_) async => const VideoModerationStatus(
          moderated: true,
          blocked: true,
          quarantined: false,
          ageRestricted: false,
          needsReview: false,
          aiGenerated: false,
        ),
      );

      await tester.pumpWidget(
        testMaterialApp(
          additionalOverrides: [
            videoModerationStatusServiceProvider.overrideWithValue(
              moderationService,
            ),
          ],
          mockAuthService: mockAuthService,
          mockProfileRepository: mockProfileRepository,
          home: MultiBlocProvider(
            providers: [
              BlocProvider<FullscreenFeedBloc>.value(value: mockBloc),
              BlocProvider<VideoVolumeCubit>.value(value: videoVolumeCubit),
              BlocProvider<VideoPlaybackStatusCubit>(
                create: (_) => VideoPlaybackStatusCubit(),
              ),
            ],
            child: FullscreenFeedContent(
              webControllerFactory: ({required url, required headers}) =>
                  webController,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      final l10n = lookupAppLocalizations(const Locale('en'));
      expect(find.text(l10n.videoErrorContentRestricted), findsOneWidget);
      expect(find.text(l10n.videoErrorContentRestrictedBody), findsOneWidget);
      verify(
        () => moderationService.fetchStatus(sha256),
      ).called(greaterThan(0));
    }, skip: !kIsWeb);

    testWidgets(
      'renders verify age action for age-restricted web loading overlay',
      (tester) async {
        const sha256 =
            'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
        final video = createTestVideoEvent(
          id: _testVideoId,
          pubkey: _testPubkey,
          sha256: sha256,
          videoUrl: 'https://media.divine.video/$sha256',
        );
        final state = FullscreenFeedState(
          status: FullscreenFeedStatus.ready,
          videos: [video],
        );
        final moderationService = _MockVideoModerationStatusService();
        final mediaAuthInterceptor = _FakeMediaAuthInterceptor();
        when(() => mockBloc.state).thenReturn(state);
        when(() => moderationService.fetchStatus(sha256)).thenAnswer(
          (_) async => const VideoModerationStatus(
            moderated: true,
            blocked: false,
            quarantined: false,
            ageRestricted: true,
            needsReview: false,
            aiGenerated: false,
          ),
        );

        await tester.pumpWidget(
          testMaterialApp(
            additionalOverrides: [
              videoModerationStatusServiceProvider.overrideWithValue(
                moderationService,
              ),
              mediaAuthInterceptorProvider.overrideWith(
                (ref) => mediaAuthInterceptor,
              ),
            ],
            mockAuthService: mockAuthService,
            mockProfileRepository: mockProfileRepository,
            home: MultiBlocProvider(
              providers: [
                BlocProvider<FullscreenFeedBloc>.value(value: mockBloc),
                BlocProvider<VideoVolumeCubit>.value(value: videoVolumeCubit),
                BlocProvider<VideoPlaybackStatusCubit>(
                  create: (_) => VideoPlaybackStatusCubit(),
                ),
              ],
              child: FullscreenFeedContent(
                webControllerFactory: ({required url, required headers}) =>
                    webController,
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump();

        final l10n = lookupAppLocalizations(const Locale('en'));
        expect(find.text(l10n.videoErrorAgeRestricted), findsOneWidget);
        expect(find.text(l10n.videoErrorVerifyAgeButton), findsOneWidget);

        await tester.tap(find.text(l10n.videoErrorVerifyAgeButton));
        await tester.pump();

        expect(mediaAuthInterceptor.didHandleUnauthorizedMedia, isTrue);
        expect(find.text(l10n.videoErrorAgeRestricted), findsNothing);
      },
      skip: !kIsWeb,
    );
  });
}
