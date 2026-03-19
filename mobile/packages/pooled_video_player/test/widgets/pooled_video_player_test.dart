// ABOUTME: Tests for PooledVideoPlayer widget
// ABOUTME: Validates loading, ready, error states and tap handling

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pooled_video_player/pooled_video_player.dart';

import '../helpers/test_helpers.dart';

class _MockVideoFeedController extends Mock implements VideoFeedController {}

class _MockVideoController extends Mock implements VideoController {}

class _MockPlayer extends Mock implements Player {}

class _MockPlayerState extends Mock implements PlayerState {}

class _MockPlayerStream extends Mock implements PlayerStream {}

class _FakeVideoItem extends Fake implements VideoItem {}

void _setUpFallbacks() {
  registerFallbackValue(Duration.zero);
  registerFallbackValue(_FakeVideoItem());
}

_MockPlayer _createMockPlayer() {
  final mockPlayer = _MockPlayer();
  final mockState = _MockPlayerState();
  final mockStream = _MockPlayerStream();

  when(() => mockState.playing).thenReturn(false);
  when(() => mockState.buffering).thenReturn(false);
  when(() => mockState.position).thenReturn(Duration.zero);
  when(() => mockPlayer.state).thenReturn(mockState);
  when(() => mockPlayer.stream).thenReturn(mockStream);

  return mockPlayer;
}

/// Creates a mock controller with a real ValueNotifier for the given index.
///
/// The returned map contains the notifier that can be updated to trigger
/// widget rebuilds.
({
  _MockVideoFeedController controller,
  Map<int, ValueNotifier<VideoIndexState>> notifiers,
})
_createMockVideoFeedControllerWithNotifier() {
  final mockController = _MockVideoFeedController();
  final videoList = createTestVideos();
  final notifiers = <int, ValueNotifier<VideoIndexState>>{};

  when(() => mockController.videos).thenReturn(videoList);
  when(() => mockController.videoCount).thenReturn(videoList.length);
  when(() => mockController.currentIndex).thenReturn(0);
  when(() => mockController.isPaused).thenReturn(false);
  when(() => mockController.isActive).thenReturn(true);
  when(() => mockController.getVideoController(any())).thenReturn(null);
  when(() => mockController.getPlayer(any())).thenReturn(null);
  when(() => mockController.getLoadState(any())).thenReturn(LoadState.none);
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

  // Set up getIndexNotifier to return a real ValueNotifier
  when(() => mockController.getIndexNotifier(any())).thenAnswer((invocation) {
    final index = invocation.positionalArguments[0] as int;
    return notifiers.putIfAbsent(
      index,
      () => ValueNotifier(const VideoIndexState()),
    );
  });

  return (controller: mockController, notifiers: notifiers);
}

void main() {
  setUpAll(_setUpFallbacks);

  group('PooledVideoPlayer', () {
    late _MockVideoFeedController mockController;
    late Map<int, ValueNotifier<VideoIndexState>> indexNotifiers;
    late _MockVideoController mockVideoController;
    late _MockPlayer mockPlayer;
    late ValueNotifier<int?> textureIdNotifier;
    late ValueNotifier<Rect?> textureRectNotifier;

    setUp(() {
      final result = _createMockVideoFeedControllerWithNotifier();
      mockController = result.controller;
      indexNotifiers = result.notifiers;
      mockVideoController = _MockVideoController();
      textureIdNotifier = ValueNotifier<int?>(1);
      textureRectNotifier = ValueNotifier<Rect?>(
        const Rect.fromLTWH(0, 0, 1920, 1080),
      );
      when(() => mockVideoController.id).thenReturn(textureIdNotifier);
      when(() => mockVideoController.rect).thenReturn(textureRectNotifier);
      when(
        () => mockVideoController.waitUntilFirstFrameRendered,
      ).thenAnswer((_) => Future<void>.value());
      mockPlayer = _createMockPlayer();
    });

    Widget buildWidget({
      int index = 0,
      VideoFeedController? controller,
      String? thumbnailUrl,
      WidgetBuilder? loadingBuilder,
      ErrorBuilder? errorBuilder,
      OverlayBuilder? overlayBuilder,
      bool enableTapToPause = false,
      bool isActive = true,
      VoidCallback? onTap,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: VideoPoolProvider(
            feedController: controller ?? mockController,
            child: PooledVideoPlayer(
              index: index,
              isActive: isActive,
              controller: controller ?? mockController,
              thumbnailUrl: thumbnailUrl,
              loadingBuilder: loadingBuilder,
              errorBuilder: errorBuilder,
              overlayBuilder: overlayBuilder,
              enableTapToPause: enableTapToPause,
              onTap: onTap,
              videoBuilder: (context, videoController, player) {
                return Container(
                  key: const Key('video_widget'),
                  color: Colors.blue,
                );
              },
            ),
          ),
        ),
      );
    }

    group('constructor', () {
      testWidgets('creates with required parameters', (tester) async {
        await tester.pumpWidget(buildWidget());

        expect(find.byType(PooledVideoPlayer), findsOneWidget);
      });

      testWidgets('default enableTapToPause is false', (tester) async {
        await tester.pumpWidget(buildWidget());

        expect(find.byType(GestureDetector), findsNothing);
      });
    });

    group('loading state', () {
      testWidgets('shows default loading when LoadState is loading', (
        tester,
      ) async {
        // Pre-create notifier with loading state
        indexNotifiers[0] = ValueNotifier(
          const VideoIndexState(loadState: LoadState.loading),
        );

        await tester.pumpWidget(buildWidget());

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      });

      testWidgets('shows default loading when LoadState is none', (
        tester,
      ) async {
        // Default state is LoadState.none
        await tester.pumpWidget(buildWidget());

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      });

      testWidgets('shows custom loadingBuilder when provided', (tester) async {
        // Default state is LoadState.none
        await tester.pumpWidget(
          buildWidget(
            loadingBuilder: (context) => const Text('Custom Loading'),
          ),
        );

        expect(find.text('Custom Loading'), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsNothing);
      });

      testWidgets('shows thumbnail in default loading state', (tester) async {
        indexNotifiers[0] = ValueNotifier(
          const VideoIndexState(loadState: LoadState.loading),
        );

        await tester.pumpWidget(
          buildWidget(thumbnailUrl: 'https://example.com/thumb.jpg'),
        );

        expect(find.byType(Image), findsOneWidget);
      });

      testWidgets('shows overlay while loading when player already exists', (
        tester,
      ) async {
        indexNotifiers[0] = ValueNotifier(
          VideoIndexState(
            loadState: LoadState.loading,
            videoController: mockVideoController,
            player: mockPlayer,
          ),
        );

        await tester.pumpWidget(
          buildWidget(
            overlayBuilder: (context, controller, player) =>
                const Text('Overlay'),
          ),
        );

        expect(find.text('Overlay'), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      });

      testWidgets('renders video layer while loading when player exists', (
        tester,
      ) async {
        final firstFrameCompleter = Completer<void>();
        when(
          () => mockVideoController.waitUntilFirstFrameRendered,
        ).thenAnswer((_) => firstFrameCompleter.future);

        indexNotifiers[0] = ValueNotifier(
          VideoIndexState(
            loadState: LoadState.loading,
            videoController: mockVideoController,
            player: mockPlayer,
          ),
        );

        await tester.pumpWidget(buildWidget());

        expect(find.byKey(const Key('video_widget')), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);

        final opacityFinder = find.ancestor(
          of: find.byKey(const Key('video_widget')),
          matching: find.byType(AnimatedOpacity),
        );

        expect(opacityFinder, findsOneWidget);
        expect(
          tester.widget<AnimatedOpacity>(opacityFinder).opacity,
          equals(0),
        );

        firstFrameCompleter.complete();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 120));

        expect(
          tester.widget<AnimatedOpacity>(opacityFinder).opacity,
          equals(1),
        );
      });

      testWidgets('shows overlay while loading before player exists', (
        tester,
      ) async {
        indexNotifiers[0] = ValueNotifier(
          const VideoIndexState(loadState: LoadState.loading),
        );

        await tester.pumpWidget(
          buildWidget(
            overlayBuilder: (context, controller, player) =>
                const Text('Overlay'),
          ),
        );

        expect(find.text('Overlay'), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      });

      testWidgets('thumbnail errorBuilder returns SizedBox.shrink', (
        tester,
      ) async {
        indexNotifiers[0] = ValueNotifier(
          const VideoIndexState(loadState: LoadState.loading),
        );

        await tester.pumpWidget(
          buildWidget(thumbnailUrl: 'https://invalid-url.com/thumb.jpg'),
        );

        final image = tester.widget<Image>(find.byType(Image));
        expect(image.errorBuilder, isNotNull);

        final errorWidget = image.errorBuilder!(
          tester.element(find.byType(Image)),
          Exception('Failed to load'),
          StackTrace.current,
        );

        expect(errorWidget, isA<SizedBox>());
      });
    });

    group('ready state', () {
      setUp(() {
        // Set up notifier with ready state and mock controllers/player
        indexNotifiers[0] = ValueNotifier(
          VideoIndexState(
            loadState: LoadState.ready,
            videoController: mockVideoController,
            player: mockPlayer,
          ),
        );
      });

      testWidgets('shows videoBuilder when LoadState is ready', (tester) async {
        await tester.pumpWidget(buildWidget());

        expect(find.byKey(const Key('video_widget')), findsOneWidget);
      });

      testWidgets('shows overlayBuilder when provided', (tester) async {
        await tester.pumpWidget(
          buildWidget(
            overlayBuilder: (context, controller, player) {
              return Container(
                key: const Key('overlay_widget'),
                color: Colors.red.withValues(alpha: 0.5),
              );
            },
          ),
        );

        expect(find.byKey(const Key('overlay_widget')), findsOneWidget);
        expect(find.byKey(const Key('video_widget')), findsOneWidget);
      });

      testWidgets('stacks video and overlay correctly', (tester) async {
        await tester.pumpWidget(
          buildWidget(
            overlayBuilder: (context, controller, player) {
              return Container(key: const Key('overlay_widget'));
            },
          ),
        );

        expect(find.byKey(const Key('video_widget')), findsOneWidget);
        expect(find.byKey(const Key('overlay_widget')), findsOneWidget);
      });

      testWidgets('renders default loading placeholder behind video to prevent '
          'black flash', (tester) async {
        await tester.pumpWidget(buildWidget());

        // Both the video widget AND the default loading placeholder
        // (CircularProgressIndicator) should be in the widget tree.
        // The placeholder stays behind the video so the thumbnail
        // remains visible until the first video frame renders.
        expect(find.byKey(const Key('video_widget')), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      });

      testWidgets(
        'renders custom loadingBuilder behind video to prevent black flash',
        (tester) async {
          await tester.pumpWidget(
            buildWidget(
              loadingBuilder: (context) =>
                  const Text('Custom Loading', key: Key('custom_loading')),
            ),
          );

          // Both the video widget AND the custom loading builder output
          // should be present in the widget tree when ready.
          expect(find.byKey(const Key('video_widget')), findsOneWidget);
          expect(find.byKey(const Key('custom_loading')), findsOneWidget);
        },
      );

      testWidgets('keeps video transparent until first frame renders', (
        tester,
      ) async {
        final firstFrameCompleter = Completer<void>();
        when(
          () => mockVideoController.waitUntilFirstFrameRendered,
        ).thenAnswer((_) => firstFrameCompleter.future);

        await tester.pumpWidget(buildWidget());

        final opacityFinder = find.ancestor(
          of: find.byKey(const Key('video_widget')),
          matching: find.byType(AnimatedOpacity),
        );

        expect(opacityFinder, findsOneWidget);
        expect(
          tester.widget<AnimatedOpacity>(opacityFinder).opacity,
          equals(0),
        );
        expect(find.byType(CircularProgressIndicator), findsOneWidget);

        firstFrameCompleter.complete();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 120));

        expect(
          tester.widget<AnimatedOpacity>(opacityFinder).opacity,
          equals(1),
        );
      });

      testWidgets('does not reveal video from timeout while still loading', (
        tester,
      ) async {
        final firstFrameCompleter = Completer<void>();
        when(
          () => mockVideoController.waitUntilFirstFrameRendered,
        ).thenAnswer((_) => firstFrameCompleter.future);

        indexNotifiers[0] = ValueNotifier(
          VideoIndexState(
            loadState: LoadState.loading,
            videoController: mockVideoController,
            player: mockPlayer,
          ),
        );

        await tester.pumpWidget(buildWidget());

        final opacityFinder = find.ancestor(
          of: find.byKey(const Key('video_widget')),
          matching: find.byType(AnimatedOpacity),
        );

        expect(opacityFinder, findsOneWidget);
        expect(
          tester.widget<AnimatedOpacity>(opacityFinder).opacity,
          equals(0),
        );

        await tester.pump(const Duration(seconds: 2));
        await tester.pump(const Duration(milliseconds: 120));

        expect(
          tester.widget<AnimatedOpacity>(opacityFinder).opacity,
          equals(0),
        );
      });

      testWidgets('reveals video after timeout when ready and first frame '
          'stalls', (tester) async {
        final firstFrameCompleter = Completer<void>();
        when(
          () => mockVideoController.waitUntilFirstFrameRendered,
        ).thenAnswer((_) => firstFrameCompleter.future);

        await tester.pumpWidget(buildWidget());

        final opacityFinder = find.ancestor(
          of: find.byKey(const Key('video_widget')),
          matching: find.byType(AnimatedOpacity),
        );

        expect(opacityFinder, findsOneWidget);
        expect(
          tester.widget<AnimatedOpacity>(opacityFinder).opacity,
          equals(0),
        );

        await tester.pump(const Duration(seconds: 2));
        await tester.pump(const Duration(milliseconds: 120));

        expect(
          tester.widget<AnimatedOpacity>(opacityFinder).opacity,
          equals(1),
        );
      });
    });

    group('error state', () {
      setUp(() {
        indexNotifiers[0] = ValueNotifier(
          const VideoIndexState(loadState: LoadState.error),
        );
      });

      testWidgets('shows default error when LoadState is error', (
        tester,
      ) async {
        await tester.pumpWidget(buildWidget());

        expect(find.byIcon(Icons.error_outline), findsOneWidget);
        expect(find.text('Failed to load video'), findsOneWidget);
      });

      testWidgets('shows custom errorBuilder when provided', (tester) async {
        await tester.pumpWidget(
          buildWidget(
            errorBuilder: (context, onRetry) {
              return TextButton(
                key: const Key('retry_button'),
                onPressed: onRetry,
                child: const Text('Retry'),
              );
            },
          ),
        );

        expect(find.byKey(const Key('retry_button')), findsOneWidget);
        expect(find.text('Retry'), findsOneWidget);
      });

      testWidgets('errorBuilder receives onRetry callback', (tester) async {
        var retryPressed = false;

        when(() => mockController.currentIndex).thenReturn(0);

        await tester.pumpWidget(
          buildWidget(
            errorBuilder: (context, onRetry) {
              return TextButton(
                key: const Key('retry_button'),
                onPressed: () {
                  retryPressed = true;
                  onRetry();
                },
                child: const Text('Retry'),
              );
            },
          ),
        );

        await tester.tap(find.byKey(const Key('retry_button')));

        expect(retryPressed, isTrue);
        verify(() => mockController.onPageChanged(0)).called(1);
      });
    });

    group('tap handling', () {
      setUp(() {
        indexNotifiers[0] = ValueNotifier(
          VideoIndexState(
            loadState: LoadState.ready,
            videoController: mockVideoController,
            player: mockPlayer,
          ),
        );
      });

      testWidgets(
        'no gesture detector when enableTapToPause is false and no onTap',
        (tester) async {
          await tester.pumpWidget(buildWidget());

          expect(find.byType(GestureDetector), findsNothing);
        },
      );

      testWidgets('gesture detector added when enableTapToPause is true', (
        tester,
      ) async {
        await tester.pumpWidget(buildWidget(enableTapToPause: true));

        expect(find.byType(GestureDetector), findsOneWidget);
      });

      testWidgets('gesture detector added when onTap provided', (tester) async {
        await tester.pumpWidget(buildWidget(onTap: () {}));

        expect(find.byType(GestureDetector), findsOneWidget);
      });

      testWidgets('tap toggles play/pause when enableTapToPause', (
        tester,
      ) async {
        await tester.pumpWidget(buildWidget(enableTapToPause: true));

        await tester.tap(find.byType(GestureDetector));

        verify(() => mockController.togglePlayPause()).called(1);
      });

      testWidgets('tap calls onTap when provided', (tester) async {
        var tapped = false;

        await tester.pumpWidget(buildWidget(onTap: () => tapped = true));

        await tester.tap(find.byType(GestureDetector));

        expect(tapped, isTrue);
      });

      testWidgets('onTap takes precedence over enableTapToPause', (
        tester,
      ) async {
        var tapped = false;

        await tester.pumpWidget(
          buildWidget(enableTapToPause: true, onTap: () => tapped = true),
        );

        await tester.tap(find.byType(GestureDetector));

        expect(tapped, isTrue);
        verifyNever(() => mockController.togglePlayPause());
      });
    });

    group('ValueListenableBuilder', () {
      testWidgets('rebuilds when index notifier value changes', (tester) async {
        // Start with loading state
        await tester.pumpWidget(buildWidget());

        expect(find.byType(CircularProgressIndicator), findsOneWidget);

        // Update notifier to ready state
        indexNotifiers[0]!.value = VideoIndexState(
          loadState: LoadState.ready,
          videoController: mockVideoController,
          player: mockPlayer,
        );
        await tester.pump();

        expect(find.byKey(const Key('video_widget')), findsOneWidget);
      });

      testWidgets('only rebuilds for its own index notifier', (tester) async {
        // Set up notifiers for index 0 and 1
        indexNotifiers[0] = ValueNotifier(const VideoIndexState());
        indexNotifiers[1] = ValueNotifier(const VideoIndexState());

        // Build widget for index 0
        await tester.pumpWidget(buildWidget());

        expect(find.byType(CircularProgressIndicator), findsOneWidget);

        // Update notifier for index 1 (should NOT affect widget at index 0)
        indexNotifiers[1]!.value = VideoIndexState(
          loadState: LoadState.ready,
          videoController: mockVideoController,
          player: mockPlayer,
        );
        await tester.pump();

        // Widget at index 0 should still show loading
        expect(find.byType(CircularProgressIndicator), findsOneWidget);

        // Now update notifier for index 0
        indexNotifiers[0]!.value = VideoIndexState(
          loadState: LoadState.ready,
          videoController: mockVideoController,
          player: mockPlayer,
        );
        await tester.pump();

        // Widget at index 0 should now show video
        expect(find.byKey(const Key('video_widget')), findsOneWidget);
      });
    });
    group('isActive texture bleeding prevention', () {
      setUp(() {
        indexNotifiers[0] = ValueNotifier(
          VideoIndexState(
            loadState: LoadState.ready,
            videoController: mockVideoController,
            player: mockPlayer,
          ),
        );
      });

      testWidgets('hides video texture when isActive is false', (tester) async {
        await tester.pumpWidget(buildWidget(isActive: false));

        final opacityFinder = find.ancestor(
          of: find.byType(AnimatedOpacity),
          matching: find.byType(Opacity),
        );

        expect(opacityFinder, findsOneWidget);
        expect(tester.widget<Opacity>(opacityFinder).opacity, equals(0));
      });

      testWidgets('shows video texture when isActive is true', (tester) async {
        await tester.pumpWidget(buildWidget());

        final opacityFinder = find.ancestor(
          of: find.byType(AnimatedOpacity),
          matching: find.byType(Opacity),
        );

        expect(opacityFinder, findsOneWidget);
        expect(tester.widget<Opacity>(opacityFinder).opacity, equals(1));
      });

      testWidgets('video widget stays in tree when inactive', (tester) async {
        await tester.pumpWidget(buildWidget(isActive: false));

        expect(find.byKey(const Key('video_widget')), findsOneWidget);
      });
    });

    group('surface recreation green frame prevention', () {
      setUp(() {
        indexNotifiers[0] = ValueNotifier(
          VideoIndexState(
            loadState: LoadState.ready,
            videoController: mockVideoController,
            player: mockPlayer,
          ),
        );
      });

      testWidgets('hides video when texture ID changes after first frame', (
        tester,
      ) async {
        await tester.pumpWidget(buildWidget());
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 120));

        final opacityFinder = find.ancestor(
          of: find.byKey(const Key('video_widget')),
          matching: find.byType(AnimatedOpacity),
        );

        // Video should be visible after first frame
        expect(
          tester.widget<AnimatedOpacity>(opacityFinder).opacity,
          equals(1),
        );

        // Simulate surface recreation: texture ID changes
        textureIdNotifier.value = 2;
        await tester.pump();

        // Video should be hidden during surface recreation
        expect(
          tester.widget<AnimatedOpacity>(opacityFinder).opacity,
          equals(0),
        );
      });

      testWidgets(
        'reveals video after rect update following surface recreation',
        (tester) async {
          await tester.pumpWidget(buildWidget());
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 120));

          final opacityFinder = find.ancestor(
            of: find.byKey(const Key('video_widget')),
            matching: find.byType(AnimatedOpacity),
          );

          // Simulate surface recreation
          textureIdNotifier.value = 2;
          await tester.pump();
          expect(
            tester.widget<AnimatedOpacity>(opacityFinder).opacity,
            equals(0),
          );

          // Simulate new frame rendered: rect notifier fires with new value
          textureRectNotifier.value = const Rect.fromLTWH(0, 0, 1280, 720);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 120));

          // Video should be visible again
          expect(
            tester.widget<AnimatedOpacity>(opacityFinder).opacity,
            equals(1),
          );
        },
      );

      testWidgets('reveals video after timeout if no rect update arrives', (
        tester,
      ) async {
        await tester.pumpWidget(buildWidget());
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 120));

        final opacityFinder = find.ancestor(
          of: find.byKey(const Key('video_widget')),
          matching: find.byType(AnimatedOpacity),
        );

        // Simulate surface recreation
        textureIdNotifier.value = 2;
        await tester.pump();
        expect(
          tester.widget<AnimatedOpacity>(opacityFinder).opacity,
          equals(0),
        );

        // Wait for fallback timeout (500ms)
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pump(const Duration(milliseconds: 120));

        // Video should be visible via timeout fallback
        expect(
          tester.widget<AnimatedOpacity>(opacityFinder).opacity,
          equals(1),
        );
      });

      testWidgets('does not hide video when initial texture ID is set', (
        tester,
      ) async {
        // Start with null texture ID
        textureIdNotifier.value = null;

        await tester.pumpWidget(buildWidget());
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 120));

        final opacityFinder = find.ancestor(
          of: find.byKey(const Key('video_widget')),
          matching: find.byType(AnimatedOpacity),
        );

        // First texture ID assignment should NOT trigger hiding
        textureIdNotifier.value = 1;
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 120));

        expect(
          tester.widget<AnimatedOpacity>(opacityFinder).opacity,
          equals(1),
        );
      });
    });
  });
}
