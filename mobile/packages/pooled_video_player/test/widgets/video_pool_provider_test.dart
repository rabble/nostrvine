// ABOUTME: Tests for VideoPoolProvider widget
// ABOUTME: Validates pool and feed controller access via InheritedWidget

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pooled_video_player/pooled_video_player.dart';

import '../helpers/test_helpers.dart';

class _FakeMedia extends Fake implements Media {}

void _setUpFallbacks() {
  registerFallbackValue(_FakeMedia());
  registerFallbackValue(Duration.zero);
  registerFallbackValue(PlaylistMode.single);
}

void main() {
  setUpAll(_setUpFallbacks);

  group('VideoPoolProvider', () {
    late TestablePlayerPool pool;

    setUp(() {
      pool = TestablePlayerPool(
        mockPlayerFactory: (_) => createMockPooledPlayer(),
      );
    });

    tearDown(() async {
      await pool.dispose();
      await PlayerPool.reset();
    });

    group('constructor', () {
      testWidgets('creates with only child', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: VideoPoolProvider(child: Text('Child')),
          ),
        );

        expect(find.text('Child'), findsOneWidget);
      });

      testWidgets('creates with pool', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: VideoPoolProvider(
              pool: pool,
              child: const Text('Child'),
            ),
          ),
        );

        expect(find.text('Child'), findsOneWidget);
      });

      testWidgets('creates with feedController', (tester) async {
        final controller = VideoFeedController(
          videos: createTestVideos(),
          pool: pool,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: VideoPoolProvider(
              feedController: controller,
              child: const Text('Child'),
            ),
          ),
        );

        expect(find.text('Child'), findsOneWidget);

        controller.dispose();
      });

      testWidgets('creates with both pool and feedController', (tester) async {
        final controller = VideoFeedController(
          videos: createTestVideos(),
          pool: pool,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: VideoPoolProvider(
              pool: pool,
              feedController: controller,
              child: const Text('Child'),
            ),
          ),
        );

        expect(find.text('Child'), findsOneWidget);

        controller.dispose();
      });
    });

    group('poolOf', () {
      testWidgets('returns pool from provider', (tester) async {
        PlayerPool? foundPool;

        await tester.pumpWidget(
          MaterialApp(
            home: VideoPoolProvider(
              pool: pool,
              child: Builder(
                builder: (context) {
                  foundPool = VideoPoolProvider.poolOf(context);
                  return const SizedBox();
                },
              ),
            ),
          ),
        );

        expect(foundPool, equals(pool));
      });

      testWidgets('returns PlayerPool.instance when no provider', (
        tester,
      ) async {
        await PlayerPool.init();
        PlayerPool? foundPool;

        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) {
                foundPool = VideoPoolProvider.poolOf(context);
                return const SizedBox();
              },
            ),
          ),
        );

        expect(foundPool, equals(PlayerPool.instance));
      });

      testWidgets(
        'returns PlayerPool.instance when provider has no pool',
        (tester) async {
          await PlayerPool.init();
          PlayerPool? foundPool;

          await tester.pumpWidget(
            MaterialApp(
              home: VideoPoolProvider(
                child: Builder(
                  builder: (context) {
                    foundPool = VideoPoolProvider.poolOf(context);
                    return const SizedBox();
                  },
                ),
              ),
            ),
          );

          expect(foundPool, equals(PlayerPool.instance));
        },
      );

      testWidgets('finds nearest ancestor provider', (tester) async {
        final innerPool = TestablePlayerPool(
          mockPlayerFactory: (_) => createMockPooledPlayer(),
        );
        PlayerPool? foundPool;

        await tester.pumpWidget(
          MaterialApp(
            home: VideoPoolProvider(
              pool: pool,
              child: VideoPoolProvider(
                pool: innerPool,
                child: Builder(
                  builder: (context) {
                    foundPool = VideoPoolProvider.poolOf(context);
                    return const SizedBox();
                  },
                ),
              ),
            ),
          ),
        );

        expect(foundPool, equals(innerPool));

        await innerPool.dispose();
      });
    });

    group('feedOf', () {
      testWidgets('returns feedController from provider', (tester) async {
        final controller = VideoFeedController(
          videos: createTestVideos(),
          pool: pool,
        );
        VideoFeedController? foundController;

        await tester.pumpWidget(
          MaterialApp(
            home: VideoPoolProvider(
              feedController: controller,
              child: Builder(
                builder: (context) {
                  foundController = VideoPoolProvider.feedOf(context);
                  return const SizedBox();
                },
              ),
            ),
          ),
        );

        expect(foundController, equals(controller));

        controller.dispose();
      });

      testWidgets('throws StateError when no provider', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) {
                expect(
                  () => VideoPoolProvider.feedOf(context),
                  throwsA(
                    isA<StateError>().having(
                      (e) => e.message,
                      'message',
                      contains('No VideoPoolProvider with feedController'),
                    ),
                  ),
                );
                return const SizedBox();
              },
            ),
          ),
        );
      });

      testWidgets(
        'throws StateError when provider has no feedController',
        (tester) async {
          await tester.pumpWidget(
            MaterialApp(
              home: VideoPoolProvider(
                pool: pool,
                child: Builder(
                  builder: (context) {
                    expect(
                      () => VideoPoolProvider.feedOf(context),
                      throwsA(isA<StateError>()),
                    );
                    return const SizedBox();
                  },
                ),
              ),
            ),
          );
        },
      );

      testWidgets('finds nearest ancestor provider', (tester) async {
        final outerController = VideoFeedController(
          videos: createTestVideos(),
          pool: pool,
        );
        final innerController = VideoFeedController(
          videos: createTestVideos(count: 3),
          pool: pool,
        );
        VideoFeedController? foundController;

        await tester.pumpWidget(
          MaterialApp(
            home: VideoPoolProvider(
              feedController: outerController,
              child: VideoPoolProvider(
                feedController: innerController,
                child: Builder(
                  builder: (context) {
                    foundController = VideoPoolProvider.feedOf(context);
                    return const SizedBox();
                  },
                ),
              ),
            ),
          ),
        );

        expect(foundController, equals(innerController));

        outerController.dispose();
        innerController.dispose();
      });
    });

    group('maybePoolOf', () {
      testWidgets('returns pool when available', (tester) async {
        PlayerPool? foundPool;

        await tester.pumpWidget(
          MaterialApp(
            home: VideoPoolProvider(
              pool: pool,
              child: Builder(
                builder: (context) {
                  foundPool = VideoPoolProvider.maybePoolOf(context);
                  return const SizedBox();
                },
              ),
            ),
          ),
        );

        expect(foundPool, equals(pool));
      });

      testWidgets('returns null when no provider', (tester) async {
        PlayerPool? foundPool;

        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) {
                foundPool = VideoPoolProvider.maybePoolOf(context);
                return const SizedBox();
              },
            ),
          ),
        );

        expect(foundPool, isNull);
      });

      testWidgets('returns null when provider has no pool', (tester) async {
        PlayerPool? foundPool;

        await tester.pumpWidget(
          MaterialApp(
            home: VideoPoolProvider(
              child: Builder(
                builder: (context) {
                  foundPool = VideoPoolProvider.maybePoolOf(context);
                  return const SizedBox();
                },
              ),
            ),
          ),
        );

        expect(foundPool, isNull);
      });
    });

    group('maybeFeedOf', () {
      testWidgets('returns feedController when available', (tester) async {
        final controller = VideoFeedController(
          videos: createTestVideos(),
          pool: pool,
        );
        VideoFeedController? foundController;

        await tester.pumpWidget(
          MaterialApp(
            home: VideoPoolProvider(
              feedController: controller,
              child: Builder(
                builder: (context) {
                  foundController = VideoPoolProvider.maybeFeedOf(context);
                  return const SizedBox();
                },
              ),
            ),
          ),
        );

        expect(foundController, equals(controller));

        controller.dispose();
      });

      testWidgets('returns null when no provider', (tester) async {
        VideoFeedController? foundController;

        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) {
                foundController = VideoPoolProvider.maybeFeedOf(context);
                return const SizedBox();
              },
            ),
          ),
        );

        expect(foundController, isNull);
      });

      testWidgets(
        'returns null when provider has no feedController',
        (tester) async {
          VideoFeedController? foundController;

          await tester.pumpWidget(
            MaterialApp(
              home: VideoPoolProvider(
                pool: pool,
                child: Builder(
                  builder: (context) {
                    foundController = VideoPoolProvider.maybeFeedOf(context);
                    return const SizedBox();
                  },
                ),
              ),
            ),
          );

          expect(foundController, isNull);
        },
      );
    });

    group('updateShouldNotify', () {
      testWidgets('returns true when pool changes', (tester) async {
        var buildCount = 0;
        final newPool = TestablePlayerPool(
          mockPlayerFactory: (_) => createMockPooledPlayer(),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: VideoPoolProvider(
              pool: pool,
              child: Builder(
                builder: (context) {
                  buildCount++;
                  VideoPoolProvider.maybePoolOf(context);
                  return const SizedBox();
                },
              ),
            ),
          ),
        );

        expect(buildCount, equals(1));

        await tester.pumpWidget(
          MaterialApp(
            home: VideoPoolProvider(
              pool: newPool,
              child: Builder(
                builder: (context) {
                  buildCount++;
                  VideoPoolProvider.maybePoolOf(context);
                  return const SizedBox();
                },
              ),
            ),
          ),
        );

        expect(buildCount, equals(2));

        await newPool.dispose();
      });

      testWidgets('returns true when feedController changes', (tester) async {
        final controller1 = VideoFeedController(
          videos: createTestVideos(),
          pool: pool,
        );
        final controller2 = VideoFeedController(
          videos: createTestVideos(count: 3),
          pool: pool,
        );
        var buildCount = 0;

        await tester.pumpWidget(
          MaterialApp(
            home: VideoPoolProvider(
              feedController: controller1,
              child: Builder(
                builder: (context) {
                  buildCount++;
                  VideoPoolProvider.maybeFeedOf(context);
                  return const SizedBox();
                },
              ),
            ),
          ),
        );

        expect(buildCount, equals(1));

        await tester.pumpWidget(
          MaterialApp(
            home: VideoPoolProvider(
              feedController: controller2,
              child: Builder(
                builder: (context) {
                  buildCount++;
                  VideoPoolProvider.maybeFeedOf(context);
                  return const SizedBox();
                },
              ),
            ),
          ),
        );

        expect(buildCount, equals(2));

        controller1.dispose();
        controller2.dispose();
      });

      testWidgets('returns false when neither changes', (tester) async {
        final controller = VideoFeedController(
          videos: createTestVideos(),
          pool: pool,
        );
        var buildCount = 0;

        await tester.pumpWidget(
          MaterialApp(
            home: VideoPoolProvider(
              pool: pool,
              feedController: controller,
              child: Builder(
                builder: (context) {
                  buildCount++;
                  VideoPoolProvider.maybePoolOf(context);
                  return const SizedBox();
                },
              ),
            ),
          ),
        );

        expect(buildCount, equals(1));

        await tester.pumpWidget(
          MaterialApp(
            home: VideoPoolProvider(
              pool: pool,
              feedController: controller,
              child: Builder(
                builder: (context) {
                  buildCount++;
                  VideoPoolProvider.maybePoolOf(context);
                  return const SizedBox();
                },
              ),
            ),
          ),
        );

        // Builder always rebuilds, but updateShouldNotify returns false
        expect(buildCount, equals(2));

        controller.dispose();
      });
    });
  });
}
