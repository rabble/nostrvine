// ABOUTME: Verifies the popular feed provider rebuilds and routes through
// ABOUTME: the period-aware repository path when popularPeriodProvider changes.

import 'package:content_blocklist_repository/content_blocklist_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/providers/popular_period_provider.dart';
import 'package:openvine/providers/popular_videos_feed_provider.dart';
import 'package:openvine/providers/readiness_gate_providers.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:videos_repository/videos_repository.dart';

class _MockVideosRepository extends Mock implements VideosRepository {}

class _MockVideoEventService extends Mock implements VideoEventService {}

class _MockContentBlocklistRepository extends Mock
    implements ContentBlocklistRepository {}

class _MockNostrClient extends Mock implements NostrClient {}

void main() {
  setUpAll(() {
    registerFallbackValue(LeaderboardPeriod.week);
  });

  late _MockVideosRepository repo;
  late _MockVideoEventService videoEventService;
  late _MockContentBlocklistRepository blocklist;
  late _MockNostrClient nostrClient;
  late SharedPreferences sharedPreferences;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    sharedPreferences = await SharedPreferences.getInstance();

    repo = _MockVideosRepository();
    videoEventService = _MockVideoEventService();
    blocklist = _MockContentBlocklistRepository();
    nostrClient = _MockNostrClient();

    when(() => videoEventService.filterVideoList(any())).thenAnswer((
      invocation,
    ) {
      return List<VideoEvent>.from(
        invocation.positionalArguments.first as List,
      );
    });
    when(() => blocklist.shouldFilterFromFeeds(any())).thenReturn(false);

    when(
      () => repo.getPopularVideos(
        limit: any(named: 'limit'),
        until: any(named: 'until'),
        offset: any(named: 'offset'),
        period: any(named: 'period'),
      ),
    ).thenAnswer((_) async => const []);
  });

  ProviderContainer makeContainer({LeaderboardPeriod? initialPeriod}) {
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(sharedPreferences),
        videosRepositoryProvider.overrideWithValue(repo),
        appReadyProvider.overrideWithValue(true),
        videoEventServiceProvider.overrideWithValue(videoEventService),
        contentBlocklistRepositoryProvider.overrideWithValue(blocklist),
        nostrServiceProvider.overrideWithValue(nostrClient),
        popularPeriodProvider.overrideWith((_) => initialPeriod),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  group(PopularVideosFeed, () {
    test(
      'passes selected period from popularPeriodProvider to repository',
      () async {
        final container = makeContainer(initialPeriod: LeaderboardPeriod.week);

        await container.read(popularVideosFeedProvider.future);

        verify(
          () => repo.getPopularVideos(
            limit: any(named: 'limit'),
            until: any(named: 'until'),
            offset: any(named: 'offset'),
            period: LeaderboardPeriod.week,
          ),
        ).called(1);
      },
    );

    test('passes null period (Right Now) by default', () async {
      final container = makeContainer();

      await container.read(popularVideosFeedProvider.future);

      verify(
        () => repo.getPopularVideos(
          limit: any(named: 'limit'),
          until: any(named: 'until'),
          offset: any(named: 'offset'),
          // Explicit null — required so mocktail matches the literal value
          // rather than ignoring the named arg.
          // ignore: avoid_redundant_argument_values
          period: null,
        ),
      ).called(1);
    });

    test(
      'rebuilds when popularPeriodProvider flips, calling repo again',
      () async {
        final container = makeContainer();

        await container.read(popularVideosFeedProvider.future);
        container.read(popularPeriodProvider.notifier).state =
            LeaderboardPeriod.month;
        await container.read(popularVideosFeedProvider.future);

        verify(
          () => repo.getPopularVideos(
            limit: any(named: 'limit'),
            until: any(named: 'until'),
            offset: any(named: 'offset'),
            // Explicit null — required so mocktail matches the literal value
            // rather than ignoring the named arg.
            // ignore: avoid_redundant_argument_values
            period: null,
          ),
        ).called(1);
        verify(
          () => repo.getPopularVideos(
            limit: any(named: 'limit'),
            until: any(named: 'until'),
            offset: any(named: 'offset'),
            period: LeaderboardPeriod.month,
          ),
        ).called(1);
      },
    );
  });
}
