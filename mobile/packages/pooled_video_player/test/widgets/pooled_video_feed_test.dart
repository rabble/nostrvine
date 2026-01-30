import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pooled_video_player/pooled_video_player.dart';

import '../helpers/mocks.dart';
import '../helpers/test_helpers.dart';

void main() {
  setUpAll(setUpMocktail);

  group('PooledVideoFeed', () {
    late TestablePlayerPool pool;

    setUp(() {
      pool = TestablePlayerPool(
        maxPlayers: 10,
        mockPlayerFactory: (_) => createMockPooledPlayer(),
      );
    });

    tearDown(() async {
      await pool.dispose();
      await PlayerPool.reset();
    });

    Widget buildFeed({
      List<VideoItem>? videos,
      VideoFeedController? controller,
      int initialIndex = 0,
      Axis scrollDirection = Axis.vertical,
      int preloadAhead = 2,
      int preloadBehind = 1,
      OnActiveVideoChanged? onActiveVideoChanged,
      void Function(int)? onNearEnd,
      int nearEndThreshold = 3,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: PooledVideoFeed(
            videos: videos ?? createTestVideos(),
            pool: pool,
            controller: controller,
            initialIndex: initialIndex,
            scrollDirection: scrollDirection,
            preloadAhead: preloadAhead,
            preloadBehind: preloadBehind,
            onActiveVideoChanged: onActiveVideoChanged,
            onNearEnd: onNearEnd,
            nearEndThreshold: nearEndThreshold,
            itemBuilder: (context, video, index, {required bool isActive}) {
              return ColoredBox(
                key: Key('video_item_$index'),
                color: isActive ? Colors.blue : Colors.grey,
                child: Center(
                  child: Text('Video $index${isActive ? ' (active)' : ''}'),
                ),
              );
            },
          ),
        ),
      );
    }

    group('constructor', () {
      testWidgets('creates with required parameters', (tester) async {
        await tester.pumpWidget(buildFeed());

        expect(find.byType(PooledVideoFeed), findsOneWidget);
      });

      testWidgets('default initialIndex is 0', (tester) async {
        await tester.pumpWidget(buildFeed());

        expect(find.text('Video 0 (active)'), findsOneWidget);
      });

      testWidgets('default scrollDirection is vertical', (tester) async {
        await tester.pumpWidget(buildFeed());

        final pageView = tester.widget<PageView>(find.byType(PageView));
        expect(pageView.scrollDirection, equals(Axis.vertical));
      });

      testWidgets('respects custom initialIndex', (tester) async {
        await tester.pumpWidget(buildFeed(initialIndex: 2));

        expect(find.text('Video 2 (active)'), findsOneWidget);
      });

      testWidgets('respects horizontal scrollDirection', (tester) async {
        await tester.pumpWidget(buildFeed(scrollDirection: Axis.horizontal));

        final pageView = tester.widget<PageView>(find.byType(PageView));
        expect(pageView.scrollDirection, equals(Axis.horizontal));
      });
    });

    group('Controller Management', () {
      testWidgets('creates internal controller when not provided', (
        tester,
      ) async {
        await tester.pumpWidget(buildFeed());

        // The feed should be working with an internal controller
        expect(find.text('Video 0 (active)'), findsOneWidget);
      });

      testWidgets('uses provided controller', (tester) async {
        final controller = VideoFeedController(
          videos: createTestVideos(count: 3),
          pool: pool,
        );

        await tester.pumpWidget(buildFeed(controller: controller));

        expect(find.text('Video 0 (active)'), findsOneWidget);

        controller.dispose();
      });
    });

    group('PageView', () {
      testWidgets('creates PageView with correct itemCount', (tester) async {
        final videos = createTestVideos(count: 7);
        await tester.pumpWidget(buildFeed(videos: videos));

        final pageView = tester.widget<PageView>(find.byType(PageView));
        expect(pageView.childrenDelegate.estimatedChildCount, equals(7));
      });

      testWidgets('PageView starts at initialIndex', (tester) async {
        await tester.pumpWidget(buildFeed(initialIndex: 3));

        expect(find.text('Video 3 (active)'), findsOneWidget);
      });
    });

    group('Page Changes', () {
      testWidgets('calls onActiveVideoChanged callback', (tester) async {
        VideoItem? changedVideo;
        int? changedIndex;

        await tester.pumpWidget(
          buildFeed(
            onActiveVideoChanged: (video, index) {
              changedVideo = video;
              changedIndex = index;
            },
          ),
        );

        // Swipe to next page
        await tester.drag(find.byType(PageView), const Offset(0, -500));
        await tester.pumpAndSettle();

        expect(changedIndex, equals(1));
        expect(changedVideo?.id, equals('video_1'));
      });

      testWidgets('passes correct video and index to callback', (
        tester,
      ) async {
        final receivedVideos = <VideoItem>[];
        final receivedIndices = <int>[];

        await tester.pumpWidget(
          buildFeed(
            onActiveVideoChanged: (video, index) {
              receivedVideos.add(video);
              receivedIndices.add(index);
            },
          ),
        );

        // Swipe through pages
        await tester.drag(find.byType(PageView), const Offset(0, -500));
        await tester.pumpAndSettle();

        await tester.drag(find.byType(PageView), const Offset(0, -500));
        await tester.pumpAndSettle();

        expect(receivedIndices, equals([1, 2]));
        expect(receivedVideos.map((v) => v.id), equals(['video_1', 'video_2']));
      });

      testWidgets('calls onNearEnd when near end of list', (tester) async {
        var nearEndCalled = false;
        int? nearEndIndex;

        await tester.pumpWidget(
          buildFeed(
            videos: createTestVideos(),
            nearEndThreshold: 2,
            onNearEnd: (index) {
              nearEndCalled = true;
              nearEndIndex = index;
            },
          ),
        );

        // Navigate to index 2 (5-2-1 = 2 from end)
        await tester.drag(find.byType(PageView), const Offset(0, -500));
        await tester.pumpAndSettle();
        await tester.drag(find.byType(PageView), const Offset(0, -500));
        await tester.pumpAndSettle();

        expect(nearEndCalled, isTrue);
        expect(nearEndIndex, equals(2));
      });

      testWidgets('itemBuilder receives isActive correctly', (tester) async {
        await tester.pumpWidget(buildFeed());

        // Initial page is active
        expect(find.text('Video 0 (active)'), findsOneWidget);

        // Swipe to next
        await tester.drag(find.byType(PageView), const Offset(0, -500));
        await tester.pumpAndSettle();

        // New page is active
        expect(find.text('Video 1 (active)'), findsOneWidget);
      });
    });

    group('VideoPoolProvider', () {
      testWidgets('wraps content with VideoPoolProvider', (tester) async {
        await tester.pumpWidget(buildFeed());

        expect(find.byType(VideoPoolProvider), findsOneWidget);
      });
    });

    group('itemBuilder', () {
      testWidgets('receives correct context', (tester) async {
        await tester.pumpWidget(buildFeed());

        // Widget renders correctly with context
        expect(find.byType(ColoredBox), findsWidgets);
      });

      testWidgets('receives correct video', (tester) async {
        final videos = [
          createTestVideo(id: 'custom_1', url: 'https://example.com/c1.mp4'),
          createTestVideo(id: 'custom_2', url: 'https://example.com/c2.mp4'),
        ];

        await tester.pumpWidget(buildFeed(videos: videos));

        expect(find.text('Video 0 (active)'), findsOneWidget);
      });

      testWidgets('receives correct index', (tester) async {
        await tester.pumpWidget(buildFeed(initialIndex: 2));

        expect(find.byKey(const Key('video_item_2')), findsOneWidget);
      });
    });

    group('State Access', () {
      testWidgets('controller getter returns feed controller', (tester) async {
        await tester.pumpWidget(buildFeed());

        final state = tester.state<PooledVideoFeedState>(
          find.byType(PooledVideoFeed),
        );

        expect(state.controller, isA<VideoFeedController>());
        expect(state.controller.videoCount, equals(5));
      });
    });

    group('Lifecycle', () {
      testWidgets('proper cleanup on dispose', (tester) async {
        await tester.pumpWidget(buildFeed());

        // Dispose by removing the widget
        await tester.pumpWidget(const MaterialApp(home: SizedBox()));

        // Should not throw
      });

      testWidgets('handles empty videos list', (tester) async {
        await tester.pumpWidget(buildFeed(videos: []));

        expect(find.byType(PageView), findsOneWidget);
      });
    });
  });
}
