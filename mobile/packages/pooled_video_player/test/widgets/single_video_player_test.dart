import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pooled_video_player/pooled_video_player.dart';

import '../helpers/mocks.dart';
import '../helpers/test_helpers.dart';

void main() {
  setUpAll(setUpMocktail);

  group('SingleVideoPlayer', () {
    late TestablePlayerPool pool;
    late Map<String, MockPlayerSetup> playerSetups;

    setUp(() {
      playerSetups = {};
      pool = TestablePlayerPool(
        maxPlayers: 10,
        mockPlayerFactory: (url) {
          final setup = createMockPlayerSetup();
          playerSetups[url] = setup;

          final mockPooledPlayer = MockPooledPlayer();
          when(() => mockPooledPlayer.player).thenReturn(setup.player);
          when(
            () => mockPooledPlayer.videoController,
          ).thenReturn(createMockVideoController());
          when(() => mockPooledPlayer.isDisposed).thenReturn(false);
          when(mockPooledPlayer.dispose).thenAnswer((_) async {});

          return mockPooledPlayer;
        },
      );
    });

    tearDown(() async {
      for (final setup in playerSetups.values) {
        await setup.dispose();
      }
      await pool.dispose();
      await PlayerPool.reset();
    });

    Widget buildWidget({
      VideoItem? video,
      WidgetBuilder? loadingBuilder,
      SingleErrorBuilder? errorBuilder,
      bool autoPlay = true,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: SingleVideoPlayer(
            video: video ?? createTestVideo(),
            pool: pool,
            loadingBuilder: loadingBuilder,
            errorBuilder: errorBuilder,
            autoPlay: autoPlay,
            videoBuilder: (context, videoController, player) {
              return Container(
                key: const Key('video_widget'),
                color: Colors.blue,
              );
            },
          ),
        ),
      );
    }

    group('constructor', () {
      testWidgets('creates with required parameters', (tester) async {
        await tester.pumpWidget(buildWidget());

        expect(find.byType(SingleVideoPlayer), findsOneWidget);
      });

      testWidgets('default autoPlay is true', (tester) async {
        await tester.pumpWidget(buildWidget());

        // Starts in loading state
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      });
    });

    group('Loading State', () {
      testWidgets('starts in loading state', (tester) async {
        await tester.pumpWidget(buildWidget());

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      });

      testWidgets('shows custom loadingBuilder when provided', (tester) async {
        await tester.pumpWidget(
          buildWidget(
            loadingBuilder: (context) => const Text('Custom Loading'),
          ),
        );

        expect(find.text('Custom Loading'), findsOneWidget);
      });

      testWidgets('shows default loading when no loadingBuilder', (
        tester,
      ) async {
        await tester.pumpWidget(buildWidget());

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      });
    });

    group('Video Loading', () {
      testWidgets('gets player from pool', (tester) async {
        final video = createTestVideo();

        await tester.pumpWidget(buildWidget(video: video));
        await tester.pump();

        expect(pool.hasPlayer('https://example.com/test.mp4'), isTrue);
      });

      testWidgets('opens media with correct URL', (tester) async {
        final video = createTestVideo(url: 'https://example.com/video.mp4');

        await tester.pumpWidget(buildWidget(video: video));
        await tester.pump();

        final setup = playerSetups['https://example.com/video.mp4']!;
        verify(
          () => setup.player.open(any(), play: false),
        ).called(1);
      });

      testWidgets('sets playlist mode to single', (tester) async {
        final video = createTestVideo(url: 'https://example.com/video.mp4');

        await tester.pumpWidget(buildWidget(video: video));
        await tester.pump();

        final setup = playerSetups['https://example.com/video.mp4']!;
        verify(
          () => setup.player.setPlaylistMode(PlaylistMode.single),
        ).called(1);
      });

      testWidgets('starts playback muted for buffering', (tester) async {
        final video = createTestVideo(url: 'https://example.com/video.mp4');

        await tester.pumpWidget(buildWidget(video: video));
        await tester.pump();

        final setup = playerSetups['https://example.com/video.mp4']!;
        verify(() => setup.player.setVolume(0)).called(1);
        verify(setup.player.play).called(1);
      });
    });

    group('Ready State', () {
      testWidgets('transitions to ready when buffered', (tester) async {
        final video = createTestVideo(url: 'https://example.com/video.mp4');

        await tester.pumpWidget(buildWidget(video: video));
        await tester.pump();

        // Simulate buffer complete
        final setup = playerSetups['https://example.com/video.mp4']!;
        setup.bufferingController.add(false);
        await tester.pump();

        expect(find.byKey(const Key('video_widget')), findsOneWidget);
      });

      testWidgets('shows videoBuilder when ready', (tester) async {
        final video = createTestVideo(url: 'https://example.com/video.mp4');

        await tester.pumpWidget(buildWidget(video: video));
        await tester.pump();

        final setup = playerSetups['https://example.com/video.mp4']!;
        setup.bufferingController.add(false);
        await tester.pump();

        expect(find.byKey(const Key('video_widget')), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsNothing);
      });

      testWidgets('sets volume to 100 when autoPlay is true', (tester) async {
        final video = createTestVideo(url: 'https://example.com/video.mp4');

        await tester.pumpWidget(buildWidget(video: video));
        await tester.pump();

        final setup = playerSetups['https://example.com/video.mp4']!;
        setup.bufferingController.add(false);
        await tester.pump();

        // First setVolume(0) for buffering, then setVolume(100) for playback
        verify(() => setup.player.setVolume(100)).called(1);
      });

      testWidgets('pauses when autoPlay is false', (tester) async {
        final video = createTestVideo(url: 'https://example.com/video.mp4');

        await tester.pumpWidget(buildWidget(video: video, autoPlay: false));
        await tester.pump();

        final setup = playerSetups['https://example.com/video.mp4']!;
        setup.bufferingController.add(false);
        await tester.pump();

        verify(setup.player.pause).called(1);
      });
    });

    group('Error State', () {
      testWidgets('transitions to error on exception', (tester) async {
        // Create a pool that throws on getPlayer
        final errorPool = TestablePlayerPool(
          mockPlayerFactory: (url) {
            throw Exception('Failed to load');
          },
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleVideoPlayer(
                video: createTestVideo(),
                pool: errorPool,
                videoBuilder: (context, controller, player) {
                  return const SizedBox();
                },
              ),
            ),
          ),
        );

        await tester.pump();
        await tester.pump();

        expect(find.text('Failed to load video'), findsOneWidget);

        await errorPool.dispose();
      });

      testWidgets('shows custom errorBuilder when provided', (tester) async {
        final errorPool = TestablePlayerPool(
          mockPlayerFactory: (url) {
            throw Exception('Failed');
          },
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleVideoPlayer(
                video: createTestVideo(),
                pool: errorPool,
                errorBuilder: (context, onRetry) {
                  return TextButton(
                    key: const Key('custom_retry'),
                    onPressed: onRetry,
                    child: const Text('Custom Retry'),
                  );
                },
                videoBuilder: (context, controller, player) {
                  return const SizedBox();
                },
              ),
            ),
          ),
        );

        await tester.pump();
        await tester.pump();

        expect(find.byKey(const Key('custom_retry')), findsOneWidget);
        expect(find.text('Custom Retry'), findsOneWidget);

        await errorPool.dispose();
      });

      testWidgets('default error shows retry button', (tester) async {
        final errorPool = TestablePlayerPool(
          mockPlayerFactory: (url) {
            throw Exception('Failed');
          },
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleVideoPlayer(
                video: createTestVideo(),
                pool: errorPool,
                videoBuilder: (context, controller, player) {
                  return const SizedBox();
                },
              ),
            ),
          ),
        );

        await tester.pump();
        await tester.pump();

        expect(find.text('Tap to retry'), findsOneWidget);
        expect(find.byIcon(Icons.refresh), findsOneWidget);

        await errorPool.dispose();
      });
    });

    group('Video Change', () {
      testWidgets('reloads when video URL changes', (tester) async {
        final video1 = createTestVideo(
          id: 'v1',
          url: 'https://example.com/video1.mp4',
        );
        final video2 = createTestVideo(
          id: 'v2',
          url: 'https://example.com/video2.mp4',
        );

        await tester.pumpWidget(buildWidget(video: video1));
        await tester.pump();

        expect(pool.hasPlayer('https://example.com/video1.mp4'), isTrue);

        // Change video
        await tester.pumpWidget(buildWidget(video: video2));
        await tester.pump();

        expect(pool.hasPlayer('https://example.com/video2.mp4'), isTrue);
      });

      testWidgets('maintains state when video unchanged', (tester) async {
        final video = createTestVideo(url: 'https://example.com/video.mp4');

        await tester.pumpWidget(buildWidget(video: video));
        await tester.pump();

        final setup = playerSetups['https://example.com/video.mp4']!;
        setup.bufferingController.add(false);
        await tester.pump();

        expect(find.byKey(const Key('video_widget')), findsOneWidget);

        // Rebuild with same video
        await tester.pumpWidget(buildWidget(video: video));
        await tester.pump();

        // Should still be ready
        expect(find.byKey(const Key('video_widget')), findsOneWidget);
      });
    });

    group('Lifecycle', () {
      testWidgets('player stays in pool after dispose', (tester) async {
        final video = createTestVideo(url: 'https://example.com/video.mp4');

        await tester.pumpWidget(buildWidget(video: video));
        await tester.pump();

        expect(pool.hasPlayer('https://example.com/video.mp4'), isTrue);

        // Remove widget
        await tester.pumpWidget(const MaterialApp(home: SizedBox()));

        // Player should still be in pool (LRU handles cleanup)
        expect(pool.hasPlayer('https://example.com/video.mp4'), isTrue);
      });
    });

    group('autoPlay', () {
      testWidgets('video plays when autoPlay is true', (tester) async {
        final video = createTestVideo(url: 'https://example.com/video.mp4');

        await tester.pumpWidget(buildWidget(video: video));
        await tester.pump();

        final setup = playerSetups['https://example.com/video.mp4']!;
        setup.bufferingController.add(false);
        await tester.pump();

        // Play was called for buffering, setVolume(100) for playback
        verify(setup.player.play).called(1);
        verify(() => setup.player.setVolume(100)).called(1);
      });

      testWidgets('video pauses when autoPlay is false', (tester) async {
        final video = createTestVideo(url: 'https://example.com/video.mp4');

        await tester.pumpWidget(buildWidget(video: video, autoPlay: false));
        await tester.pump();

        final setup = playerSetups['https://example.com/video.mp4']!;
        setup.bufferingController.add(false);
        await tester.pump();

        verify(setup.player.pause).called(1);
        verify(() => setup.player.setVolume(100)).called(1);
      });
    });

    group('Buffer subscription edge cases', () {
      testWidgets('ignores buffering false when already ready', (
        tester,
      ) async {
        final video = createTestVideo(url: 'https://example.com/video.mp4');

        await tester.pumpWidget(buildWidget(video: video));
        await tester.pump();

        final setup = playerSetups['https://example.com/video.mp4']!;

        // Transition to ready
        setup.bufferingController.add(false);
        await tester.pump();

        expect(find.byKey(const Key('video_widget')), findsOneWidget);

        // Send another buffering = false (should be ignored since already ready)
        setup.bufferingController.add(false);
        await tester.pump();

        // Still in ready state
        expect(find.byKey(const Key('video_widget')), findsOneWidget);
      });

      testWidgets('buffer subscription callback transitions state', (
        tester,
      ) async {
        // Create a pool with buffering initially true
        final bufferingSetups = <String, MockPlayerSetup>{};
        final bufferingPool = TestablePlayerPool(
          maxPlayers: 10,
          mockPlayerFactory: (url) {
            // Create setup with buffering: true initially
            final setup = createMockPlayerSetup(isBuffering: true);
            bufferingSetups[url] = setup;

            final mockPooledPlayer = MockPooledPlayer();
            when(() => mockPooledPlayer.player).thenReturn(setup.player);
            when(
              () => mockPooledPlayer.videoController,
            ).thenReturn(createMockVideoController());
            when(() => mockPooledPlayer.isDisposed).thenReturn(false);
            when(mockPooledPlayer.dispose).thenAnswer((_) async {});

            return mockPooledPlayer;
          },
        );

        final video = createTestVideo(url: 'https://example.com/video.mp4');

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleVideoPlayer(
                video: video,
                pool: bufferingPool,
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
        await tester.pump();

        // Still in loading since buffering is true
        expect(find.byType(CircularProgressIndicator), findsOneWidget);

        final setup = bufferingSetups['https://example.com/video.mp4']!;

        // Trigger buffer complete via subscription
        setup.bufferingController.add(false);
        await tester.pump();

        // Now should be ready
        expect(find.byKey(const Key('video_widget')), findsOneWidget);

        for (final s in bufferingSetups.values) {
          await s.dispose();
        }
        await bufferingPool.dispose();
      });
    });

    group('Default widgets', () {
      testWidgets('default error state shows retry button', (tester) async {
        final errorPool = TestablePlayerPool(
          mockPlayerFactory: (url) {
            throw Exception('Failed');
          },
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleVideoPlayer(
                video: createTestVideo(),
                pool: errorPool,
                videoBuilder: (context, controller, player) {
                  return const SizedBox();
                },
              ),
            ),
          ),
        );

        await tester.pump();
        await tester.pump();

        // Verify default error state components
        expect(find.byIcon(Icons.error_outline), findsOneWidget);
        expect(find.text('Failed to load video'), findsOneWidget);
        expect(find.byIcon(Icons.refresh), findsOneWidget);
        expect(find.text('Tap to retry'), findsOneWidget);

        await errorPool.dispose();
      });

      testWidgets('default loading state shows progress indicator', (
        tester,
      ) async {
        await tester.pumpWidget(buildWidget());

        // Default loading shows CircularProgressIndicator
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      });
    });
  });
}
