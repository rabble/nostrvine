import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pooled_video_player/pooled_video_player.dart';

import '../helpers/mocks.dart';
import '../helpers/test_helpers.dart';

void main() {
  setUpAll(setUpMocktail);

  group('PooledVideoPlayer', () {
    late MockVideoFeedController mockController;
    late MockVideoController mockVideoController;
    late MockPlayer mockPlayer;

    setUp(() {
      mockController = createMockVideoFeedController();
      mockVideoController = createMockVideoController();
      mockPlayer = createMockPlayer();
    });

    Widget buildWidget({
      int index = 0,
      VideoFeedController? controller,
      String? thumbnailUrl,
      WidgetBuilder? loadingBuilder,
      ErrorBuilder? errorBuilder,
      OverlayBuilder? overlayBuilder,
      bool enableTapToPause = false,
      VoidCallback? onTap,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: VideoPoolProvider(
            feedController: controller ?? mockController,
            child: PooledVideoPlayer(
              index: index,
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

        // No gesture detector when enableTapToPause is false
        // and load state is not ready
        expect(find.byType(GestureDetector), findsNothing);
      });
    });

    group('Loading State', () {
      testWidgets('shows default loading when LoadState is loading', (
        tester,
      ) async {
        when(
          () => mockController.getLoadState(0),
        ).thenReturn(LoadState.loading);

        await tester.pumpWidget(buildWidget());

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      });

      testWidgets('shows default loading when LoadState is none', (
        tester,
      ) async {
        when(() => mockController.getLoadState(0)).thenReturn(LoadState.none);

        await tester.pumpWidget(buildWidget());

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      });

      testWidgets('shows custom loadingBuilder when provided', (tester) async {
        when(() => mockController.getLoadState(0)).thenReturn(LoadState.none);

        await tester.pumpWidget(
          buildWidget(
            loadingBuilder: (context) => const Text('Custom Loading'),
          ),
        );

        expect(find.text('Custom Loading'), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsNothing);
      });

      testWidgets('shows thumbnail in default loading state', (tester) async {
        when(
          () => mockController.getLoadState(0),
        ).thenReturn(LoadState.loading);

        await tester.pumpWidget(
          buildWidget(thumbnailUrl: 'https://example.com/thumb.jpg'),
        );

        expect(find.byType(Image), findsOneWidget);
      });

      testWidgets('thumbnail errorBuilder returns SizedBox.shrink', (
        tester,
      ) async {
        when(
          () => mockController.getLoadState(0),
        ).thenReturn(LoadState.loading);

        await tester.pumpWidget(
          buildWidget(thumbnailUrl: 'https://invalid-url.com/thumb.jpg'),
        );

        // Find the Image widget
        final image = tester.widget<Image>(find.byType(Image));

        // Verify errorBuilder is configured (it returns SizedBox.shrink)
        expect(image.errorBuilder, isNotNull);

        // Call the errorBuilder to ensure it's covered
        final errorWidget = image.errorBuilder!(
          tester.element(find.byType(Image)),
          Exception('Failed to load'),
          StackTrace.current,
        );

        expect(errorWidget, isA<SizedBox>());
      });
    });

    group('Ready State', () {
      setUp(() {
        when(() => mockController.getLoadState(0)).thenReturn(LoadState.ready);
        when(
          () => mockController.getVideoController(0),
        ).thenReturn(mockVideoController);
        when(() => mockController.getPlayer(0)).thenReturn(mockPlayer);
      });

      testWidgets('shows videoBuilder when LoadState is ready', (
        tester,
      ) async {
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
              return Container(
                key: const Key('overlay_widget'),
              );
            },
          ),
        );

        // Both video and overlay should be present in a stack
        expect(find.byKey(const Key('video_widget')), findsOneWidget);
        expect(find.byKey(const Key('overlay_widget')), findsOneWidget);
      });
    });

    group('Error State', () {
      setUp(() {
        when(() => mockController.getLoadState(0)).thenReturn(LoadState.error);
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

    group('Tap Handling', () {
      setUp(() {
        when(() => mockController.getLoadState(0)).thenReturn(LoadState.ready);
        when(
          () => mockController.getVideoController(0),
        ).thenReturn(mockVideoController);
        when(() => mockController.getPlayer(0)).thenReturn(mockPlayer);
      });

      testWidgets(
        'no gesture detector when enableTapToPause is false and no onTap',
        (tester) async {
          await tester.pumpWidget(buildWidget());

          // The GestureDetector is only added for ready state with tap handling
          expect(find.byType(GestureDetector), findsNothing);
        },
      );

      testWidgets(
        'gesture detector added when enableTapToPause is true',
        (tester) async {
          await tester.pumpWidget(buildWidget(enableTapToPause: true));

          expect(find.byType(GestureDetector), findsOneWidget);
        },
      );

      testWidgets('gesture detector added when onTap provided', (
        tester,
      ) async {
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
          buildWidget(
            enableTapToPause: true,
            onTap: () => tapped = true,
          ),
        );

        await tester.tap(find.byType(GestureDetector));

        expect(tapped, isTrue);
        verifyNever(() => mockController.togglePlayPause());
      });
    });

    group('ListenableBuilder', () {
      testWidgets('rebuilds when controller notifies', (tester) async {
        final listeners = <VoidCallback>[];

        when(() => mockController.addListener(any())).thenAnswer((invocation) {
          listeners.add(invocation.positionalArguments[0] as VoidCallback);
        });

        await tester.pumpWidget(buildWidget());

        // Initial state shows loading
        expect(find.byType(CircularProgressIndicator), findsOneWidget);

        // Change to ready state
        when(() => mockController.getLoadState(0)).thenReturn(LoadState.ready);
        when(
          () => mockController.getVideoController(0),
        ).thenReturn(mockVideoController);
        when(() => mockController.getPlayer(0)).thenReturn(mockPlayer);

        // Notify listeners
        for (final listener in listeners) {
          listener();
        }
        await tester.pump();

        // Now shows video
        expect(find.byKey(const Key('video_widget')), findsOneWidget);
      });
    });
  });
}
