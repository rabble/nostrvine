import 'package:content_blocklist_repository/content_blocklist_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/constants/app_constants.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/new_videos_feed_provider.dart';
import 'package:openvine/providers/readiness_gate_providers.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:videos_repository/videos_repository.dart';

import '../helpers/test_provider_overrides.dart';

class _MockVideosRepository extends Mock implements VideosRepository {}

class _MockVideoEventService extends Mock implements VideoEventService {}

class _MockContentBlocklistRepository extends Mock
    implements ContentBlocklistRepository {}

void main() {
  group(NewVideosFeed, () {
    late _MockVideosRepository videosRepository;
    late _MockVideoEventService videoEventService;
    late _MockContentBlocklistRepository blocklistRepository;

    setUp(() {
      videosRepository = _MockVideosRepository();
      videoEventService = _MockVideoEventService();
      blocklistRepository = _MockContentBlocklistRepository();

      when(() => videoEventService.filterVideoList(any())).thenAnswer(
        (invocation) =>
            List<VideoEvent>.from(invocation.positionalArguments.first as List),
      );
      when(
        () => blocklistRepository.shouldFilterFromFeeds(any()),
      ).thenReturn(false);
    });

    ProviderContainer createContainer() {
      final container = ProviderContainer(
        overrides: [
          ...getStandardTestOverrides(),
          appReadyProvider.overrideWithValue(true),
          videosRepositoryProvider.overrideWithValue(videosRepository),
          videoEventServiceProvider.overrideWithValue(videoEventService),
          contentBlocklistRepositoryProvider.overrideWithValue(
            blocklistRepository,
          ),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    /// Stubs the first page (`until` null) and every page after it.
    void stubPages({
      required HomeFeedResult first,
      HomeFeedResult? subsequent,
    }) {
      when(
        () => videosRepository.getNewVideos(
          limit: any(named: 'limit'),
          until: any(named: 'until', that: isNull),
          skipCache: any(named: 'skipCache'),
        ),
      ).thenAnswer((_) async => first);
      when(
        () => videosRepository.getNewVideos(
          limit: any(named: 'limit'),
          until: any(named: 'until', that: isNotNull),
          skipCache: any(named: 'skipCache'),
        ),
      ).thenAnswer((_) async => subsequent ?? const HomeFeedResult(videos: []));
    }

    group('build', () {
      // The regression: the home feed warms the shared cache with 25 videos,
      // this feed asks for 50 and gets that cached page back. Inferring
      // "no more content" from the short count killed pagination for the
      // rest of the session.
      test(
        'reports more content behind a page shorter than its page size',
        () async {
          stubPages(
            first: HomeFeedResult(videos: _videos(2), hasMore: true),
          );

          final state = await createContainer().read(
            newVideosFeedProvider.future,
          );

          expect(state.videos, hasLength(2));
          expect(state.hasMoreContent, isTrue);
        },
      );

      test(
        'stops paginating when the repository reports no more content',
        () async {
          stubPages(
            first: HomeFeedResult(
              videos: _videos(AppConstants.paginationBatchSize),
              hasMore: false,
            ),
          );

          final state = await createContainer().read(
            newVideosFeedProvider.future,
          );

          expect(state.hasMoreContent, isFalse);
        },
      );
    });

    group('loadMore', () {
      test(
        'keeps paginating on the flag rather than the returned count',
        () async {
          stubPages(
            first: HomeFeedResult(videos: _videos(2), hasMore: true),
            subsequent: HomeFeedResult(
              videos: _videos(2, idPrefix: 'more'),
              hasMore: true,
            ),
          );
          final container = createContainer();
          await container.read(newVideosFeedProvider.future);

          await container.read(newVideosFeedProvider.notifier).loadMore();

          final state = container.read(newVideosFeedProvider).requireValue;
          expect(state.videos, hasLength(4));
          expect(state.hasMoreContent, isTrue);
        },
      );

      test('stops when the repository reports the source ran dry', () async {
        stubPages(
          first: HomeFeedResult(videos: _videos(2), hasMore: true),
          subsequent: HomeFeedResult(
            videos: _videos(2, idPrefix: 'more'),
            hasMore: false,
          ),
        );
        final container = createContainer();
        await container.read(newVideosFeedProvider.future);

        await container.read(newVideosFeedProvider.notifier).loadMore();

        expect(
          container.read(newVideosFeedProvider).requireValue.hasMoreContent,
          isFalse,
        );
      });
    });
  });
}

List<VideoEvent> _videos(int count, {String idPrefix = 'new'}) => [
  for (var i = 0; i < count; i++)
    VideoEvent(
      id: '$idPrefix-$i',
      pubkey: 'test-pubkey',
      createdAt: DateTime(2026, 1, count - i).millisecondsSinceEpoch ~/ 1000,
      content: 'Test video',
      timestamp: DateTime(2026, 1, count - i),
      videoUrl: 'https://example.com/$idPrefix-$i.mp4',
      thumbnailUrl: 'https://example.com/$idPrefix-$i.jpg',
    ),
];
