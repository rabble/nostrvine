import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pooled_video_player/pooled_video_player.dart';

import '../helpers/test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(registerTestFallbackValues);

  group('PooledVideoFeed', () {
    setUp(() async {
      await initializeTestPoolManager();
    });

    tearDown(() async {
      await cleanupPoolManager();
    });

    Widget buildFeed({
      String feedId = 'test-feed',
      List<VideoItem>? videos,
      VideoFeedController? controller,
      int initialIndex = 0,
      Axis scrollDirection = Axis.vertical,
      OnActiveVideoChanged? onActiveVideoChanged,
      OnVideoTapped? onVideoTapped,
      void Function(int)? onNearEnd,
      int nearEndThreshold = 3,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: PooledVideoFeed(
            feedId: feedId,
            videos: videos ?? const [],
            controller: controller,
            initialIndex: initialIndex,
            scrollDirection: scrollDirection,
            onActiveVideoChanged: onActiveVideoChanged,
            onVideoTapped: onVideoTapped,
            onNearEnd: onNearEnd,
            nearEndThreshold: nearEndThreshold,
            itemBuilder: (context, video, index, {required bool isActive}) =>
                Container(
              key: ValueKey('video-$index'),
              color: isActive ? Colors.blue : Colors.grey,
              child: Center(
                child: Text('Video ${video.id}'),
              ),
            ),
          ),
        ),
      );
    }

    group('Constructor', () {
      testWidgets('renders with empty video list', (tester) async {
        await tester.pumpWidget(buildFeed());

        expect(find.byType(PageView), findsOneWidget);
      });

      testWidgets('renders videos in PageView', (tester) async {
        final videos = createTestVideos(3);

        await tester.pumpWidget(buildFeed(videos: videos));
        await tester.pumpAndSettle();

        // First video should be visible
        expect(find.text('Video video-0'), findsOneWidget);
      });

      testWidgets('uses vertical scroll direction by default', (tester) async {
        await tester.pumpWidget(buildFeed());

        final pageView = tester.widget<PageView>(find.byType(PageView));
        expect(pageView.scrollDirection, Axis.vertical);
      });

      testWidgets('uses horizontal scroll direction when specified',
          (tester) async {
        await tester.pumpWidget(
          buildFeed(scrollDirection: Axis.horizontal),
        );

        final pageView = tester.widget<PageView>(find.byType(PageView));
        expect(pageView.scrollDirection, Axis.horizontal);
      });

      testWidgets('starts at initialIndex', (tester) async {
        final videos = createTestVideos(5);

        await tester.pumpWidget(buildFeed(videos: videos, initialIndex: 2));
        await tester.pumpAndSettle();

        // Video at index 2 should be visible
        expect(find.text('Video video-2'), findsOneWidget);
      });
    });

    group('Controller Management', () {
      testWidgets('creates internal controller when none provided',
          (tester) async {
        await tester.pumpWidget(buildFeed());
        await tester.pumpAndSettle();

        final state = tester.state<PooledVideoFeedState>(
          find.byType(PooledVideoFeed),
        );

        expect(state.controller, isNotNull);
        expect(state.controller.feedId, 'test-feed');
      });

      testWidgets('uses external controller when provided', (tester) async {
        final controller = VideoFeedController(
          feedId: 'external-feed',
          videos: const [],
        );

        await tester.pumpWidget(buildFeed(controller: controller));
        await tester.pumpAndSettle();

        final state = tester.state<PooledVideoFeedState>(
          find.byType(PooledVideoFeed),
        );

        expect(state.controller, controller);
        expect(state.controller.feedId, 'external-feed');

        await controller.disposeAsync();
      });

      testWidgets('exposes controller via state', (tester) async {
        await tester.pumpWidget(buildFeed(feedId: 'my-feed'));
        await tester.pumpAndSettle();

        final state = tester.state<PooledVideoFeedState>(
          find.byType(PooledVideoFeed),
        );

        expect(state.controller, isA<VideoFeedController>());
        expect(state.controller.feedId, 'my-feed');
      });
    });

    group('Page Navigation', () {
      testWidgets('page changes update currentIndex via onPageChanged',
          (tester) async {
        final videos = createTestVideos(5);

        await tester.pumpWidget(buildFeed(videos: videos));
        await tester.pumpAndSettle();

        final state = tester.state<PooledVideoFeedState>(
          find.byType(PooledVideoFeed),
        );

        expect(state.controller.currentIndex, 0);

        // Simulate page change by swiping (vertical)
        await tester.fling(
          find.byType(PageView),
          const Offset(0, -300),
          1000,
        );
        await tester.pumpAndSettle();

        expect(state.controller.currentIndex, 1);
      });
    });

    group('Callbacks', () {
      testWidgets('calls onActiveVideoChanged when page changes',
          (tester) async {
        final videos = createTestVideos(5);
        VideoItem? changedVideo;
        int? changedIndex;

        await tester.pumpWidget(
          buildFeed(
            videos: videos,
            onActiveVideoChanged: (video, index) {
              changedVideo = video;
              changedIndex = index;
            },
          ),
        );
        await tester.pumpAndSettle();

        // Swipe to next video
        await tester.fling(
          find.byType(PageView),
          const Offset(0, -300),
          1000,
        );
        await tester.pumpAndSettle();

        expect(changedVideo, isNotNull);
        expect(changedVideo!.id, 'video-1');
        expect(changedIndex, 1);
      });

      testWidgets('calls onNearEnd when near end of list', (tester) async {
        final videos = createTestVideos(5);
        int? nearEndIndex;

        await tester.pumpWidget(
          buildFeed(
            videos: videos,
            nearEndThreshold: 2, // 2 videos from end
            onNearEnd: (index) => nearEndIndex = index,
          ),
        );
        await tester.pumpAndSettle();

        // Go to video 2 (3 from end, not near enough)
        await tester.fling(find.byType(PageView), const Offset(0, -300), 1000);
        await tester.pumpAndSettle();
        await tester.fling(find.byType(PageView), const Offset(0, -300), 1000);
        await tester.pumpAndSettle();

        expect(nearEndIndex, 2); // distance is 2, equals threshold

        // Go to video 3 (2 from end, within threshold)
        await tester.fling(find.byType(PageView), const Offset(0, -300), 1000);
        await tester.pumpAndSettle();

        expect(nearEndIndex, 3);
      });

      testWidgets('calls onVideoTapped with lease when video is tapped',
          (tester) async {
        final videos = createTestVideos(3);
        VideoItem? tappedVideo;
        int? tappedIndex;
        var onVideoTappedCalled = false;

        await tester.pumpWidget(
          buildFeed(
            videos: videos,
            onVideoTapped: (video, index, lease) {
              tappedVideo = video;
              tappedIndex = index;
              onVideoTappedCalled = true;
            },
          ),
        );
        await tester.pumpAndSettle();

        // Tap on the video
        await tester.tap(find.text('Video video-0'));
        await tester.pump();

        expect(onVideoTappedCalled, true);
        expect(tappedVideo?.id, 'video-0');
        expect(tappedIndex, 0);
      });
    });

    group('VideoPoolProvider', () {
      testWidgets('wraps content with VideoPoolProvider', (tester) async {
        await tester.pumpWidget(buildFeed());
        await tester.pumpAndSettle();

        expect(find.byType(VideoPoolProvider), findsOneWidget);
      });
    });

    group('Item Builder', () {
      testWidgets('passes correct isActive value to itemBuilder',
          (tester) async {
        final videos = createTestVideos(3);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: PooledVideoFeed(
                feedId: 'test-feed',
                videos: videos,
                itemBuilder: (context, video, index, {required bool isActive}) {
                  return Container(
                    key: ValueKey('video-$index'),
                    child: Text(isActive ? 'Active' : 'Inactive'),
                  );
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // First video should be active
        expect(find.text('Active'), findsOneWidget);
      });
    });
  });
}
