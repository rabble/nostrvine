// ABOUTME: Widget tests for PooledFullscreenVideoFeedScreen
// ABOUTME: Tests state rendering and BLoC event dispatching

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/fullscreen_feed/fullscreen_feed_bloc.dart';
import 'package:openvine/screens/feed/pooled_fullscreen_video_feed_screen.dart';
import 'package:openvine/widgets/branded_loading_indicator.dart';
import 'package:openvine/widgets/video_feed_item/video_feed_item.dart';
import 'package:openvine/widgets/web_video_feed.dart';
import 'package:pooled_video_player/pooled_video_player.dart';

import '../../helpers/test_provider_overrides.dart';
import '../../test_data/video_test_data.dart';

class MockFullscreenFeedBloc
    extends MockBloc<FullscreenFeedEvent, FullscreenFeedState>
    implements FullscreenFeedBloc {}

class MockVideoFeedController extends Mock implements VideoFeedController {}

class MockPlayer extends Mock implements Player {}

// Full 64-character test IDs
const testVideoId1 =
    'a1b2c3d4e5f6789012345678901234567890abcdef123456789012345678901234';
const testVideoId2 =
    'b2c3d4e5f6789012345678901234567890abcdef123456789012345678901234a1';
const testVideoId3 =
    'c3d4e5f6789012345678901234567890abcdef123456789012345678901234a1b2';
const testPubkey =
    'd4e5f6789012345678901234567890abcdef123456789012345678901234a1b2c3';

void stubVideoFeedController(
  MockVideoFeedController controller,
  Map<int, ValueNotifier<VideoIndexState>> indexNotifiers,
) {
  when(() => controller.videos).thenReturn([]);
  when(() => controller.videoCount).thenReturn(0);
  when(() => controller.currentIndex).thenReturn(0);
  when(() => controller.isPaused).thenReturn(false);
  when(() => controller.isActive).thenReturn(true);
  when(() => controller.getVideoController(any())).thenReturn(null);
  when(() => controller.getPlayer(any())).thenReturn(null);
  when(() => controller.getLoadState(any())).thenReturn(LoadState.none);
  when(() => controller.isVideoReady(any())).thenReturn(false);
  when(() => controller.onPageChanged(any())).thenReturn(null);
  when(controller.play).thenReturn(null);
  when(controller.pause).thenReturn(null);
  when(controller.togglePlayPause).thenReturn(null);
  when(() => controller.seek(any())).thenAnswer((_) async {});
  when(() => controller.setVolume(any())).thenReturn(null);
  when(() => controller.setPlaybackSpeed(any())).thenReturn(null);
  when(
    () => controller.setActive(active: any(named: 'active')),
  ).thenReturn(null);
  when(() => controller.addVideos(any())).thenReturn(null);
  when(() => controller.addListener(any())).thenReturn(null);
  when(() => controller.removeListener(any())).thenReturn(null);
  when(controller.dispose).thenReturn(null);

  when(() => controller.getIndexNotifier(any())).thenAnswer((inv) {
    final index = inv.positionalArguments[0] as int;
    return indexNotifiers.putIfAbsent(
      index,
      () => ValueNotifier(const VideoIndexState()),
    );
  });
}

void main() {
  group('PooledFullscreenVideoFeedScreen', () {
    late MockFullscreenFeedBloc mockBloc;
    late MockVideoFeedController defaultController;
    late MockProfileRepository mockProfileRepository;
    late MockNip05VerificationService mockNip05VerificationService;
    late Map<int, ValueNotifier<VideoIndexState>> defaultIndexNotifiers;
    late StreamController<FullscreenFeedState> stateController;

    setUpAll(() {
      registerFallbackValue(const FullscreenFeedStarted());
      registerFallbackValue(const FullscreenFeedIndexChanged(0));
      registerFallbackValue(const FullscreenFeedLoadMoreRequested());
      registerFallbackValue(const FullscreenFeedVideoCacheStarted(index: 0));
      registerFallbackValue(Duration.zero);
      registerFallbackValue(LoadState.none);
    });

    setUp(() async {
      await PlayerPool.init();
      mockBloc = MockFullscreenFeedBloc();
      defaultController = MockVideoFeedController();
      mockProfileRepository = createMockProfileRepository();
      mockNip05VerificationService = createMockNip05VerificationService();
      defaultIndexNotifiers = <int, ValueNotifier<VideoIndexState>>{};
      stateController = StreamController<FullscreenFeedState>.broadcast();
      stubVideoFeedController(defaultController, defaultIndexNotifiers);

      // Default stream setup
      when(() => mockBloc.stream).thenAnswer((_) => stateController.stream);
    });

    tearDown(() async {
      await stateController.close();
      await PlayerPool.reset();
    });

    List<VideoEvent> createTestVideos({int count = 3}) {
      return [
        createTestVideoEvent(
          id: testVideoId1,
          pubkey: testPubkey,
          videoUrl: 'https://example.com/video1.mp4',
        ),
        if (count > 1)
          createTestVideoEvent(
            id: testVideoId2,
            pubkey: testPubkey,
            videoUrl: 'https://example.com/video2.mp4',
          ),
        if (count > 2)
          createTestVideoEvent(
            id: testVideoId3,
            pubkey: testPubkey,
            videoUrl: 'https://example.com/video3.mp4',
          ),
      ];
    }

    Widget buildSubject({
      FullscreenFeedState? state,
      List<dynamic>? additionalOverrides,
      VideoFeedControllerFactory? controllerFactory,
      String? contextTitle,
    }) {
      final effectiveState = state ?? const FullscreenFeedState();
      when(() => mockBloc.state).thenReturn(effectiveState);
      when(
        () => defaultController.videos,
      ).thenReturn(effectiveState.pooledVideos);
      when(
        () => defaultController.videoCount,
      ).thenReturn(effectiveState.pooledVideos.length);
      when(
        () => defaultController.currentIndex,
      ).thenReturn(effectiveState.currentIndex);

      return testMaterialApp(
        additionalOverrides: additionalOverrides,
        mockProfileRepository: mockProfileRepository,
        mockNip05VerificationService: mockNip05VerificationService,
        home: BlocProvider<FullscreenFeedBloc>.value(
          value: mockBloc,
          child: FullscreenFeedContent(
            contextTitle: contextTitle,
            controllerFactory:
                controllerFactory ??
                ((videos, initialIndex) => defaultController),
          ),
        ),
      );
    }

    group('state rendering', () {
      testWidgets('shows loading indicator when status is initial', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildSubject(state: const FullscreenFeedState()),
        );

        expect(find.byType(BrandedLoadingIndicator), findsOneWidget);
        expect(find.byType(PooledVideoFeed), findsNothing);
      });

      testWidgets('shows loading indicator when videos list is empty', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildSubject(
            state: const FullscreenFeedState(
              status: FullscreenFeedStatus.ready,
            ),
          ),
        );

        expect(find.byType(BrandedLoadingIndicator), findsOneWidget);
        expect(find.byType(PooledVideoFeed), findsNothing);
      });

      testWidgets('shows "No videos available" when videos have no videoUrl', (
        tester,
      ) async {
        final videosWithoutUrl = [
          createTestVideoEvent(
            id: testVideoId1,
            pubkey: testPubkey,
            videoUrl: null,
          ),
        ];

        await tester.pumpWidget(
          buildSubject(
            state: FullscreenFeedState(
              status: FullscreenFeedStatus.ready,
              videos: videosWithoutUrl,
            ),
          ),
        );

        expect(find.text('No videos available'), findsOneWidget);
        expect(find.byType(PooledVideoFeed), findsNothing);
      });

      testWidgets('shows PooledVideoFeed when videos are available', (
        tester,
      ) async {
        final videos = createTestVideos();

        await tester.pumpWidget(
          buildSubject(
            state: FullscreenFeedState(
              status: FullscreenFeedStatus.ready,
              videos: videos,
            ),
          ),
        );

        // PooledVideoFeed should be rendered when videos are available
        // Note: Individual video items may still show their own loading states
        expect(find.byType(PooledVideoFeed), findsOneWidget);
      });

      testWidgets(
        'shows the category title in the fullscreen app bar when provided',
        (
          tester,
        ) async {
          final videos = createTestVideos();

          await tester.pumpWidget(
            buildSubject(
              state: FullscreenFeedState(
                status: FullscreenFeedStatus.ready,
                videos: videos,
              ),
              contextTitle: 'Animals',
            ),
          );

          expect(find.text('Animals'), findsOneWidget);
        },
      );

      testWidgets('shows social overlay actions on web', (tester) async {
        final videos = createTestVideos();

        await tester.pumpWidget(
          buildSubject(
            state: FullscreenFeedState(
              status: FullscreenFeedStatus.ready,
              videos: videos,
            ),
          ),
        );
        await tester.pump();

        expect(find.byType(WebVideoFeed), findsOneWidget);
        expect(find.byType(VideoOverlayActions), findsOneWidget);
      }, skip: !kIsWeb);
    });

    group('BLoC event dispatching', () {
      testWidgets('dispatches FullscreenFeedIndexChanged when video changes', (
        tester,
      ) async {
        final videos = createTestVideos();

        await tester.pumpWidget(
          buildSubject(
            state: FullscreenFeedState(
              status: FullscreenFeedStatus.ready,
              videos: videos,
            ),
          ),
        );

        // Find the PooledVideoFeed and trigger onActiveVideoChanged
        final pooledVideoFeed = tester.widget<PooledVideoFeed>(
          find.byType(PooledVideoFeed),
        );

        // Simulate video change callback
        pooledVideoFeed.onActiveVideoChanged?.call(
          const VideoItem(
            id: testVideoId2,
            url: 'https://example.com/video2.mp4',
          ),
          1,
        );

        verify(
          () => mockBloc.add(const FullscreenFeedIndexChanged(1)),
        ).called(1);
      });

      testWidgets('dispatches FullscreenFeedLoadMoreRequested on near end', (
        tester,
      ) async {
        final videos = createTestVideos();

        await tester.pumpWidget(
          buildSubject(
            state: FullscreenFeedState(
              status: FullscreenFeedStatus.ready,
              videos: videos,
              canLoadMore: true,
            ),
          ),
        );

        // Find the PooledVideoFeed and trigger onNearEnd
        final pooledVideoFeed = tester.widget<PooledVideoFeed>(
          find.byType(PooledVideoFeed),
        );

        // Simulate near end callback
        pooledVideoFeed.onNearEnd?.call(2);

        verify(
          () => mockBloc.add(const FullscreenFeedLoadMoreRequested()),
        ).called(1);
      });
    });

    group('hook wiring', () {
      late MockVideoFeedController mockController;
      late Map<int, ValueNotifier<VideoIndexState>> indexNotifiers;

      setUp(() {
        mockController = MockVideoFeedController();
        indexNotifiers = <int, ValueNotifier<VideoIndexState>>{};
        stubVideoFeedController(mockController, indexNotifiers);
      });

      testWidgets('controller factory is called with correct videos', (
        tester,
      ) async {
        final videos = createTestVideos();
        final pooledVideos = videos
            .map((v) => VideoItem(id: v.id, url: v.videoUrl!))
            .toList();

        List<VideoItem>? factoryVideos;
        int? factoryIndex;

        when(() => mockBloc.state).thenReturn(
          FullscreenFeedState(
            status: FullscreenFeedStatus.ready,
            videos: videos,
            currentIndex: 1,
          ),
        );
        when(() => mockController.videos).thenReturn(pooledVideos);
        when(() => mockController.videoCount).thenReturn(pooledVideos.length);

        await tester.pumpWidget(
          testMaterialApp(
            home: BlocProvider<FullscreenFeedBloc>.value(
              value: mockBloc,
              child: FullscreenFeedContent(
                controllerFactory: (videos, initialIndex) {
                  factoryVideos = videos;
                  factoryIndex = initialIndex;
                  return mockController;
                },
              ),
            ),
          ),
        );

        // Verify factory was called with correct parameters
        expect(factoryVideos, isNotNull);
        expect(factoryVideos!.length, equals(3));
        expect(factoryVideos![0].id, equals(testVideoId1));
        expect(factoryIndex, equals(1));
      });

      testWidgets(
        'renders with a single video when controller factory is injected',
        (tester) async {
          final videos = createTestVideos(count: 1);
          final pooledVideos = videos
              .map((v) => VideoItem(id: v.id, url: v.videoUrl!))
              .toList();

          when(() => mockBloc.state).thenReturn(
            FullscreenFeedState(
              status: FullscreenFeedStatus.ready,
              videos: videos,
            ),
          );
          when(() => mockController.videos).thenReturn(pooledVideos);
          when(() => mockController.videoCount).thenReturn(pooledVideos.length);

          await tester.pumpWidget(
            testMaterialApp(
              home: BlocProvider<FullscreenFeedBloc>.value(
                value: mockBloc,
                child: FullscreenFeedContent(
                  controllerFactory: (videos, initialIndex) => mockController,
                ),
              ),
            ),
          );

          expect(find.byType(PooledVideoFeed), findsOneWidget);
        },
      );

      testWidgets(
        'renders with a single video for position callback scenarios',
        (tester) async {
          final videos = createTestVideos(count: 1);
          final pooledVideos = videos
              .map((v) => VideoItem(id: v.id, url: v.videoUrl!))
              .toList();

          when(() => mockBloc.state).thenReturn(
            FullscreenFeedState(
              status: FullscreenFeedStatus.ready,
              videos: videos,
            ),
          );
          when(() => mockController.videos).thenReturn(pooledVideos);
          when(() => mockController.videoCount).thenReturn(pooledVideos.length);

          await tester.pumpWidget(
            testMaterialApp(
              home: BlocProvider<FullscreenFeedBloc>.value(
                value: mockBloc,
                child: FullscreenFeedContent(
                  controllerFactory: (videos, initialIndex) => mockController,
                ),
              ),
            ),
          );

          expect(find.byType(PooledVideoFeed), findsOneWidget);
        },
      );
    });
  });
}
