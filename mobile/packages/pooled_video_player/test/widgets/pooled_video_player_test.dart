import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pooled_video_player/pooled_video_player.dart';

import '../helpers/test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(registerTestFallbackValues);

  group('PooledVideoPlayer', () {
    late MockVideoFeedController mockController;
    late MockPlayer mockPlayer;
    late MockVideoController mockVideoController;

    setUp(() {
      mockController = MockVideoFeedController();
      mockPlayer = MockPlayer();
      mockVideoController = MockVideoController();

      // Default stubs
      when(() => mockController.getVideoController(any())).thenReturn(null);
      when(() => mockController.getPlayer(any())).thenReturn(null);
      when(() => mockController.isVideoReady(any())).thenReturn(false);
      when(() => mockController.getPreloadState(any()))
          .thenReturn(PreloadState.none);
      when(() => mockController.getError(any())).thenReturn(null);
      when(() => mockController.isPaused).thenReturn(false);
      when(() => mockController.addListener(any())).thenReturn(null);
      when(() => mockController.removeListener(any())).thenReturn(null);
    });

    Widget buildWidget({
      int index = 0,
      VideoFeedController? controller,
      WidgetBuilder? loadingBuilder,
      ErrorBuilder? errorBuilder,
      OverlayBuilder? overlayBuilder,
      bool enableTapToPause = false,
      VoidCallback? onTap,
      OnVideoReady? onVideoReady,
      OnVideoLoading? onVideoLoading,
      OnVideoError? onVideoError,
      OnPlayPauseChanged? onPlayPauseChanged,
      String? thumbnailUrl,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: PooledVideoPlayer(
            index: index,
            controller: controller ?? mockController,
            loadingBuilder: loadingBuilder,
            errorBuilder: errorBuilder,
            overlayBuilder: overlayBuilder,
            enableTapToPause: enableTapToPause,
            onTap: onTap,
            onVideoReady: onVideoReady,
            onVideoLoading: onVideoLoading,
            onVideoError: onVideoError,
            onPlayPauseChanged: onPlayPauseChanged,
            thumbnailUrl: thumbnailUrl,
            videoBuilder: (context, videoController, player) =>
                const ColoredBox(
              color: Colors.blue,
              child: Text('Video Content'),
            ),
          ),
        ),
      );
    }

    group('Loading State', () {
      testWidgets('shows default loading state when not ready', (tester) async {
        await tester.pumpWidget(buildWidget());

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      });

      testWidgets('shows custom loading builder when provided', (tester) async {
        await tester.pumpWidget(
          buildWidget(
            loadingBuilder: (context) => const Text('Custom Loading'),
          ),
        );

        expect(find.text('Custom Loading'), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsNothing);
      });

      testWidgets('calls onVideoLoading callback when loading', (tester) async {
        var loadingCalled = false;

        await tester.pumpWidget(
          buildWidget(
            onVideoLoading: () => loadingCalled = true,
          ),
        );

        expect(loadingCalled, true);
      });
    });

    group('Ready State', () {
      setUp(() {
        when(() => mockController.getVideoController(any()))
            .thenReturn(mockVideoController);
        when(() => mockController.getPlayer(any())).thenReturn(mockPlayer);
        when(() => mockController.isVideoReady(any())).thenReturn(true);
        when(() => mockController.getPreloadState(any()))
            .thenReturn(PreloadState.ready);
      });

      testWidgets('shows video content when ready', (tester) async {
        await tester.pumpWidget(buildWidget());

        expect(find.text('Video Content'), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsNothing);
      });

      testWidgets('shows overlay when overlayBuilder is provided',
          (tester) async {
        await tester.pumpWidget(
          buildWidget(
            overlayBuilder: (context, videoController, player) =>
                const Text('Overlay'),
          ),
        );

        expect(find.text('Video Content'), findsOneWidget);
        expect(find.text('Overlay'), findsOneWidget);
      });
    });

    group('Error State', () {
      late VideoLoadError testError;

      setUp(() {
        testError = VideoLoadError(
          index: 0,
          videoId: 'video-1',
          error: Exception('Test error'),
          timestamp: DateTime.now(),
        );

        when(() => mockController.getPreloadState(any()))
            .thenReturn(PreloadState.error);
        when(() => mockController.getError(any())).thenReturn(testError);
      });

      testWidgets('shows default error state when error occurs',
          (tester) async {
        await tester.pumpWidget(buildWidget());

        expect(find.text('Failed to load video'), findsOneWidget);
        expect(find.byIcon(Icons.error_outline), findsOneWidget);
      });

      testWidgets('shows custom error builder when provided', (tester) async {
        await tester.pumpWidget(
          buildWidget(
            errorBuilder: (context, error, onRetry) =>
                const Text('Custom Error'),
          ),
        );

        expect(find.text('Custom Error'), findsOneWidget);
        expect(find.text('Failed to load video'), findsNothing);
      });

      testWidgets('calls onVideoError callback when error occurs',
          (tester) async {
        VideoLoadError? receivedError;

        await tester.pumpWidget(
          buildWidget(
            onVideoError: (error) => receivedError = error,
          ),
        );

        expect(receivedError, testError);
      });

      testWidgets('shows retry button when retries available', (tester) async {
        await tester.pumpWidget(buildWidget());

        expect(find.text('Tap to retry'), findsOneWidget);
      });

      testWidgets('hides retry button when max retries exceeded',
          (tester) async {
        final maxRetriesError = VideoLoadError(
          index: 0,
          videoId: 'video-1',
          error: Exception('Test error'),
          timestamp: DateTime.now(),
          retryCount: 10, // Exceeds default maxRetryAttempts of 3
        );

        when(() => mockController.getError(any())).thenReturn(maxRetriesError);

        await tester.pumpWidget(buildWidget());

        expect(find.text('Failed to load video'), findsOneWidget);
        expect(find.text('Tap to retry'), findsNothing);
      });

      testWidgets('retry button calls retryPreload', (tester) async {
        when(() => mockController.retryPreload(any())).thenAnswer((_) async {});

        await tester.pumpWidget(buildWidget(index: 5));

        await tester.tap(find.text('Tap to retry'));
        await tester.pump();

        verify(() => mockController.retryPreload(5)).called(1);
      });
    });

    group('Tap Handling', () {
      setUp(() {
        when(() => mockController.getVideoController(any()))
            .thenReturn(mockVideoController);
        when(() => mockController.getPlayer(any())).thenReturn(mockPlayer);
        when(() => mockController.isVideoReady(any())).thenReturn(true);
        when(() => mockController.getPreloadState(any()))
            .thenReturn(PreloadState.ready);
        when(() => mockController.togglePlayPause()).thenReturn(null);
      });

      testWidgets('tap does nothing when enableTapToPause is false',
          (tester) async {
        await tester.pumpWidget(buildWidget());

        // Find the video content and tap it
        final videoContent = find.text('Video Content');
        expect(videoContent, findsOneWidget);

        await tester.tap(videoContent);
        await tester.pump();

        verifyNever(() => mockController.togglePlayPause());
      });

      testWidgets(
          'tap toggles play/pause when enableTapToPause is true '
          'and video is ready', (tester) async {
        await tester.pumpWidget(
          buildWidget(enableTapToPause: true),
        );

        await tester.tap(find.text('Video Content'));
        await tester.pump();

        verify(mockController.togglePlayPause).called(1);
      });

      testWidgets('tap calls onPlayPauseChanged callback', (tester) async {
        bool? receivedIsPlaying;

        await tester.pumpWidget(
          buildWidget(
            enableTapToPause: true,
            onPlayPauseChanged: ({required bool isPlaying}) =>
                receivedIsPlaying = isPlaying,
          ),
        );

        await tester.tap(find.text('Video Content'));
        await tester.pump();

        // isPaused is false, so isPlaying should be true after toggle
        expect(receivedIsPlaying, true);
      });

      testWidgets('custom onTap overrides enableTapToPause', (tester) async {
        var customTapCalled = false;

        await tester.pumpWidget(
          buildWidget(
            enableTapToPause: true,
            onTap: () => customTapCalled = true,
          ),
        );

        await tester.tap(find.text('Video Content'));
        await tester.pump();

        expect(customTapCalled, true);
        verifyNever(() => mockController.togglePlayPause());
      });
    });

    group('Index Handling', () {
      testWidgets('uses correct index for controller calls', (tester) async {
        await tester.pumpWidget(buildWidget(index: 7));

        verify(() => mockController.getVideoController(7))
            .called(greaterThan(0));
        verify(() => mockController.getPlayer(7)).called(greaterThan(0));
        verify(() => mockController.isVideoReady(7)).called(greaterThan(0));
        verify(() => mockController.getPreloadState(7))
            .called(greaterThan(0));
      });
    });

    group('Listenable Updates', () {
      testWidgets('rebuilds when controller notifies listeners',
          (tester) async {
        // Start with not ready
        when(() => mockController.isVideoReady(any())).thenReturn(false);

        await tester.pumpWidget(buildWidget());

        expect(find.byType(CircularProgressIndicator), findsOneWidget);

        // Capture the listener
        final captured = verify(
          () => mockController.addListener(captureAny()),
        ).captured;
        final listener = captured.first as VoidCallback;

        // Update state to ready
        when(() => mockController.getVideoController(any()))
            .thenReturn(mockVideoController);
        when(() => mockController.getPlayer(any())).thenReturn(mockPlayer);
        when(() => mockController.isVideoReady(any())).thenReturn(true);
        when(() => mockController.getPreloadState(any()))
            .thenReturn(PreloadState.ready);

        // Notify listeners
        listener();
        await tester.pump();

        // Should now show video content
        expect(find.text('Video Content'), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsNothing);
      });
    });
  });
}
