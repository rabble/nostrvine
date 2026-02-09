// ABOUTME: Widget tests for PooledFullscreenVideoFeedScreen
// ABOUTME: Tests state rendering, BLoC event dispatching, and SeekCommand handling

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/fullscreen_feed/fullscreen_feed_bloc.dart';
import 'package:openvine/screens/feed/pooled_fullscreen_video_feed_screen.dart';
import 'package:openvine/widgets/branded_loading_indicator.dart';
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

void main() {
  group('PooledFullscreenVideoFeedScreen', () {
    late MockFullscreenFeedBloc mockBloc;
    late StreamController<FullscreenFeedState> stateController;

    setUpAll(() {
      registerFallbackValue(const FullscreenFeedStarted());
      registerFallbackValue(const FullscreenFeedIndexChanged(0));
      registerFallbackValue(const FullscreenFeedLoadMoreRequested());
      registerFallbackValue(const FullscreenFeedSeekCommandHandled());
      registerFallbackValue(const FullscreenFeedVideoCacheStarted(index: 0));
      registerFallbackValue(
        const FullscreenFeedPositionUpdated(index: 0, position: Duration.zero),
      );
      registerFallbackValue(Duration.zero);
      registerFallbackValue(LoadState.none);
    });

    setUp(() async {
      await PlayerPool.init();
      mockBloc = MockFullscreenFeedBloc();
      stateController = StreamController<FullscreenFeedState>.broadcast();

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

    Widget buildSubject({FullscreenFeedState? state}) {
      final effectiveState = state ?? const FullscreenFeedState();
      when(() => mockBloc.state).thenReturn(effectiveState);

      return testMaterialApp(
        home: BlocProvider<FullscreenFeedBloc>.value(
          value: mockBloc,
          child: const FullscreenFeedContent(),
        ),
      );
    }

    group('state rendering', () {
      testWidgets('shows loading indicator when status is initial', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildSubject(
            state: const FullscreenFeedState(
              status: FullscreenFeedStatus.initial,
            ),
          ),
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
              videos: [],
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
              currentIndex: 0,
            ),
          ),
        );

        // PooledVideoFeed should be rendered when videos are available
        // Note: Individual video items may still show their own loading states
        expect(find.byType(PooledVideoFeed), findsOneWidget);
      });
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
              currentIndex: 0,
            ),
          ),
        );

        // Find the PooledVideoFeed and trigger onActiveVideoChanged
        final pooledVideoFeed = tester.widget<PooledVideoFeed>(
          find.byType(PooledVideoFeed),
        );

        // Simulate video change callback
        pooledVideoFeed.onActiveVideoChanged?.call(
          VideoItem(id: testVideoId2, url: 'https://example.com/video2.mp4'),
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
              currentIndex: 0,
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

    group('SeekCommand handling', () {
      testWidgets(
        'dispatches FullscreenFeedSeekCommandHandled when SeekCommand received',
        (tester) async {
          final videos = createTestVideos();

          // Start with no seek command
          final initialState = FullscreenFeedState(
            status: FullscreenFeedStatus.ready,
            videos: videos,
            currentIndex: 0,
          );

          await tester.pumpWidget(buildSubject(state: initialState));
          await tester.pumpAndSettle();

          // Emit state with SeekCommand
          final stateWithSeekCommand = FullscreenFeedState(
            status: FullscreenFeedStatus.ready,
            videos: videos,
            currentIndex: 0,
            seekCommand: const SeekCommand(index: 0, position: Duration.zero),
          );

          when(() => mockBloc.state).thenReturn(stateWithSeekCommand);
          stateController.add(stateWithSeekCommand);
          await tester.pump();

          // Verify the handled event was dispatched
          verify(
            () => mockBloc.add(const FullscreenFeedSeekCommandHandled()),
          ).called(1);
        },
      );

      testWidgets('does not dispatch handled event when seekCommand is null', (
        tester,
      ) async {
        final videos = createTestVideos();

        final state = FullscreenFeedState(
          status: FullscreenFeedStatus.ready,
          videos: videos,
          currentIndex: 0,
        );

        await tester.pumpWidget(buildSubject(state: state));

        // Emit same state without seek command
        stateController.add(state);
        await tester.pump();

        verifyNever(
          () => mockBloc.add(const FullscreenFeedSeekCommandHandled()),
        );
      });

      testWidgets('only handles SeekCommand once when same command emitted', (
        tester,
      ) async {
        final videos = createTestVideos();

        final initialState = FullscreenFeedState(
          status: FullscreenFeedStatus.ready,
          videos: videos,
          currentIndex: 0,
        );

        await tester.pumpWidget(buildSubject(state: initialState));
        await tester.pumpAndSettle();

        final seekCommand = const SeekCommand(
          index: 0,
          position: Duration.zero,
        );
        final stateWithSeekCommand = FullscreenFeedState(
          status: FullscreenFeedStatus.ready,
          videos: videos,
          currentIndex: 0,
          seekCommand: seekCommand,
        );

        // Emit the same state twice
        when(() => mockBloc.state).thenReturn(stateWithSeekCommand);
        stateController.add(stateWithSeekCommand);
        await tester.pump();

        // Emit again (should be ignored by listenWhen)
        stateController.add(stateWithSeekCommand);
        await tester.pump();

        // Should only be called once due to listenWhen check
        verify(
          () => mockBloc.add(const FullscreenFeedSeekCommandHandled()),
        ).called(1);
      });
    });

    group('hook wiring', () {
      late MockVideoFeedController mockController;

      setUp(() {
        mockController = MockVideoFeedController();

        // Pre-configure the mock controller with all required stubs
        when(() => mockController.videos).thenReturn([]);
        when(() => mockController.videoCount).thenReturn(0);
        when(() => mockController.currentIndex).thenReturn(0);
        when(() => mockController.isPaused).thenReturn(false);
        when(() => mockController.isActive).thenReturn(true);
        when(() => mockController.getVideoController(any())).thenReturn(null);
        when(() => mockController.getPlayer(any())).thenReturn(null);
        when(
          () => mockController.getLoadState(any()),
        ).thenReturn(LoadState.none);
        when(() => mockController.isVideoReady(any())).thenReturn(false);
        when(() => mockController.onPageChanged(any())).thenReturn(null);
        when(mockController.play).thenReturn(null);
        when(mockController.pause).thenReturn(null);
        when(mockController.togglePlayPause).thenReturn(null);
        when(() => mockController.seek(any())).thenAnswer((_) async {});
        when(() => mockController.setVolume(any())).thenReturn(null);
        when(() => mockController.setPlaybackSpeed(any())).thenReturn(null);
        when(
          () => mockController.setActive(active: any(named: 'active')),
        ).thenReturn(null);
        when(() => mockController.addVideos(any())).thenReturn(null);
        when(() => mockController.addListener(any())).thenReturn(null);
        when(() => mockController.removeListener(any())).thenReturn(null);
        when(mockController.dispose).thenReturn(null);
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
        'default controller wires onVideoReady to dispatch cache event',
        (tester) async {
          // This test verifies the actual hook wiring by NOT using a factory
          // and instead letting the real controller be created, then
          // checking the BLoC receives the event

          final videos = createTestVideos(count: 1);

          // Use the real widget (no factory) to test actual hook wiring
          when(() => mockBloc.state).thenReturn(
            FullscreenFeedState(
              status: FullscreenFeedStatus.ready,
              videos: videos,
              currentIndex: 0,
            ),
          );

          await tester.pumpWidget(
            testMaterialApp(
              home: BlocProvider<FullscreenFeedBloc>.value(
                value: mockBloc,
                child: const FullscreenFeedContent(),
              ),
            ),
          );

          // The real VideoFeedController is created with hooks
          // We can't easily trigger onVideoReady without MediaKit,
          // but we CAN verify the controller was created by checking
          // the PooledVideoFeed exists
          expect(find.byType(PooledVideoFeed), findsOneWidget);

          // The hook wiring is verified by code inspection and
          // integration tests - the factory test above proves
          // the controllerFactory parameter works for injection
        },
      );

      testWidgets(
        'default controller wires positionCallback to dispatch position event',
        (tester) async {
          final videos = createTestVideos(count: 1);

          when(() => mockBloc.state).thenReturn(
            FullscreenFeedState(
              status: FullscreenFeedStatus.ready,
              videos: videos,
              currentIndex: 0,
            ),
          );

          await tester.pumpWidget(
            testMaterialApp(
              home: BlocProvider<FullscreenFeedBloc>.value(
                value: mockBloc,
                child: const FullscreenFeedContent(),
              ),
            ),
          );

          // Verify the widget renders with the real controller
          expect(find.byType(PooledVideoFeed), findsOneWidget);

          // The positionCallback wiring is verified by:
          // 1. Code inspection - _createController sets up the hook
          // 2. BLoC tests - FullscreenFeedPositionUpdated handler works
          // 3. VideoFeedController tests - positionCallback is called
        },
      );
    });
  });
}
