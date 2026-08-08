// ABOUTME: Widget tests for featured Explore tab video handoffs.
// ABOUTME: Tapping a featured tile must open the curated snapshot with campaign attribution.

import 'package:feed_repository/feed_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/models/view_traffic_source.dart';
import 'package:openvine/providers/featured_tabs_providers.dart';
import 'package:openvine/providers/feed_repository_provider.dart';
import 'package:openvine/providers/video_providers.dart';
import 'package:openvine/repositories/featured_tabs_repository.dart';
import 'package:openvine/screens/explore/tabs/featured_videos_tab.dart';
import 'package:openvine/screens/feed/pooled_fullscreen_video_feed_screen.dart';
import 'package:openvine/widgets/video_thumbnail_widget.dart';

import '../../../helpers/go_router.dart';
import '../../../helpers/test_provider_overrides.dart';

class _MockFeaturedTabsRepository extends Mock
    implements FeaturedTabsRepository {}

class _MockFeedRepository extends Mock implements FeedRepository {}

FeaturedTabConfig _config() {
  return const FeaturedTabConfig(
    id: 'ft_a1b2c3d4',
    slug: 'featured-slug',
    label: {'default': 'Featured'},
    startsAt: null,
    endsAt: null,
    enabled: true,
    hasContent: true,
  );
}

VideoEvent _video(String id) {
  return VideoEvent(
    id: id,
    pubkey: '1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef',
    createdAt: 1700000000,
    content: '',
    timestamp: DateTime.utc(2026, 2, 15),
    videoUrl: 'https://media.divine.video/$id.mp4',
    thumbnailUrl: 'https://media.divine.video/$id.jpg',
  );
}

void main() {
  group(FeaturedVideosTab, () {
    late _MockFeaturedTabsRepository featuredRepository;
    late _MockFeedRepository feedRepository;
    late MockGoRouter router;

    setUp(() {
      featuredRepository = _MockFeaturedTabsRepository();
      feedRepository = _MockFeedRepository();
      router = MockGoRouter();
      when(
        () => featuredRepository.loadVideos(
          tabId: 'ft_a1b2c3d4',
          cursor: any(named: 'cursor'),
        ),
      ).thenAnswer(
        (_) async => FeaturedTabVideosPage(
          videos: [_video('first'), _video('second')],
        ),
      );
      when(
        () => router.push<Object?>(any(), extra: any(named: 'extra')),
      ).thenAnswer((_) async => null);
    });

    Widget buildSubject() {
      return testMaterialApp(
        additionalOverrides: [
          featuredTabsRepositoryProvider.overrideWithValue(featuredRepository),
          feedRepositoryProvider.overrideWithValue(feedRepository),
          subscribedListVideoCacheProvider.overrideWithValue(null),
        ],
        home: MockGoRouterProvider(
          goRouter: router,
          child: FeaturedVideosTab(config: _config()),
        ),
      );
    }

    testWidgets('opens the curated snapshot with config attribution', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      await tester.tap(find.byType(VideoThumbnailWidget).first);
      await tester.pump();

      final captured = verify(
        () => router.push<Object?>(
          any(),
          extra: captureAny(named: 'extra'),
        ),
      ).captured.single;
      final args = captured as PooledFullscreenVideoFeedArgs;

      expect(args.source, isA<VideoListViewSource>());
      expect(args.initialIndex, 0);
      expect(args.initialVideoId, 'first');
      expect(args.trafficSource, ViewTrafficSource.discoveryFeatured);
      expect(args.sourceDetail, 'ft_a1b2c3d4');
      expect(args.feedRepository, same(feedRepository));

      final source = args.source as VideoListViewSource;
      expect(source.videos.map((video) => video.id), ['first', 'second']);
    });
  });
}
