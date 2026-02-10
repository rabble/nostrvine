// ABOUTME: Tests for router-driven HomeScreen using pooled_video_player
// ABOUTME: Tests rendering states, empty state, and PooledVideoFeed content

import 'package:comments_repository/comments_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:likes_repository/likes_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/home_feed_provider.dart';
import 'package:openvine/providers/home_screen_controllers.dart';
import 'package:openvine/providers/overlay_visibility_provider.dart';
import 'package:openvine/router/router.dart';
import 'package:openvine/screens/home_screen_router.dart';
import 'package:openvine/state/video_feed_state.dart';
import 'package:openvine/widgets/branded_loading_indicator.dart';
import 'package:pooled_video_player/pooled_video_player.dart';
import 'package:reposts_repository/reposts_repository.dart';

import '../helpers/test_provider_overrides.dart';
import '../test_data/video_test_data.dart';

class _MockHomePaginationController extends Mock
    implements HomePaginationController {}

class _MockHomeRefreshController extends Mock
    implements HomeRefreshController {}

class _MockLikesRepository extends Mock implements LikesRepository {}

class _MockCommentsRepository extends Mock implements CommentsRepository {}

class _MockRepostsRepository extends Mock implements RepostsRepository {}

// Full 64-character test IDs (never truncate Nostr IDs)
const _testVideoId1 =
    'a1b2c3d4e5f6789012345678901234567890abcdef123456789012345678901234';
const _testVideoId2 =
    'b2c3d4e5f6789012345678901234567890abcdef123456789012345678901234a1';
const _testVideoId3 =
    'c3d4e5f6789012345678901234567890abcdef123456789012345678901234a1b2';
const _testPubkey =
    'd4e5f6789012345678901234567890abcdef123456789012345678901234a1b2c3';

/// Test HomeFeed notifier that returns fixed data without accessing
/// real providers (REST API, Nostr, etc.).
class _TestHomeFeed extends HomeFeed {
  _TestHomeFeed(this._initialState);

  final VideoFeedState _initialState;

  @override
  Future<VideoFeedState> build() async => _initialState;
}

void main() {
  group(HomeScreenRouter, () {
    late _MockHomePaginationController mockPagination;
    late _MockHomeRefreshController mockRefresh;
    late _MockLikesRepository mockLikes;
    late _MockCommentsRepository mockComments;
    late _MockRepostsRepository mockReposts;

    setUp(() async {
      await PlayerPool.init();

      mockPagination = _MockHomePaginationController();
      mockRefresh = _MockHomeRefreshController();
      mockLikes = _MockLikesRepository();
      mockComments = _MockCommentsRepository();
      mockReposts = _MockRepostsRepository();

      // Stub controllers
      when(() => mockPagination.maybeLoadMore()).thenAnswer((_) async {});
      when(() => mockRefresh.refresh()).thenAnswer((_) async {});

      // Stub repository methods needed by VideoInteractionsBloc
      when(
        () => mockLikes.watchLikedEventIds(),
      ).thenAnswer((_) => Stream.value(<String>{}));
      when(() => mockLikes.isLiked(any())).thenAnswer((_) async => false);
      when(
        () => mockLikes.getLikeCount(
          any(),
          addressableId: any(named: 'addressableId'),
        ),
      ).thenAnswer((_) async => 0);

      when(
        () => mockComments.getCommentsCount(
          any(),
          rootAddressableId: any(named: 'rootAddressableId'),
        ),
      ).thenAnswer((_) async => 0);

      when(
        () => mockReposts.watchRepostedAddressableIds(),
      ).thenAnswer((_) => Stream.value(<String>{}));
      when(() => mockReposts.isReposted(any())).thenAnswer((_) async => false);
      when(() => mockReposts.getRepostCount(any())).thenAnswer((_) async => 0);
      when(
        () => mockReposts.getRepostCountByEventId(any()),
      ).thenAnswer((_) async => 0);
    });

    tearDown(() async {
      await PlayerPool.reset();
    });

    List<VideoEvent> createTestVideos({int count = 3}) {
      return [
        createTestVideoEvent(
          id: _testVideoId1,
          pubkey: _testPubkey,
          videoUrl: 'https://example.com/video1.mp4',
        ),
        if (count > 1)
          createTestVideoEvent(
            id: _testVideoId2,
            pubkey: _testPubkey,
            videoUrl: 'https://example.com/video2.mp4',
          ),
        if (count > 2)
          createTestVideoEvent(
            id: _testVideoId3,
            pubkey: _testPubkey,
            videoUrl: 'https://example.com/video3.mp4',
          ),
      ];
    }

    Widget buildSubject({
      required VideoFeedState feedState,
      int videoIndex = 0,
      bool hasOverlay = false,
    }) {
      return testMaterialApp(
        home: const HomeScreenRouter(),
        additionalOverrides: [
          pageContextProvider.overrideWith(
            (ref) => Stream.value(
              RouteContext(type: RouteType.home, videoIndex: videoIndex),
            ),
          ),
          homeFeedProvider.overrideWith(() => _TestHomeFeed(feedState)),
          homePaginationControllerProvider.overrideWithValue(mockPagination),
          homeRefreshControllerProvider.overrideWithValue(mockRefresh),
          hasVisibleOverlayProvider.overrideWithValue(hasOverlay),
          likesRepositoryProvider.overrideWithValue(mockLikes),
          commentsRepositoryProvider.overrideWithValue(mockComments),
          repostsRepositoryProvider.overrideWithValue(mockReposts),
        ],
      );
    }

    group('state rendering', () {
      testWidgets('shows $BrandedLoadingIndicator during initial load', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildSubject(
            feedState: const VideoFeedState(videos: [], hasMoreContent: true),
          ),
        );

        // Pump to let StreamProvider emit RouteContext
        await tester.pump();

        expect(find.byType(BrandedLoadingIndicator), findsOneWidget);
        expect(find.byType(PooledVideoFeed), findsNothing);
      });

      testWidgets('shows empty state when feed has no videos', (tester) async {
        await tester.pumpWidget(
          buildSubject(
            feedState: VideoFeedState(
              videos: const [],
              hasMoreContent: false,
              lastUpdated: DateTime.now(),
            ),
          ),
        );

        // Pump to let StreamProvider emit RouteContext
        await tester.pump();

        expect(find.text('Your Home Feed is Empty'), findsOneWidget);
        expect(
          find.text('Follow creators to see their videos here'),
          findsOneWidget,
        );
        expect(find.text('Explore Videos'), findsOneWidget);
        expect(find.byType(PooledVideoFeed), findsNothing);
      });

      testWidgets('shows $PooledVideoFeed when videos are available', (
        tester,
      ) async {
        final videos = createTestVideos();

        await tester.pumpWidget(
          buildSubject(
            feedState: VideoFeedState(
              videos: videos,
              hasMoreContent: true,
              lastUpdated: DateTime.now(),
            ),
          ),
        );

        // Pump multiple times for:
        // 1. StreamProvider emits RouteContext
        // 2. HomeFeed async resolves
        // 3. Stream → BLoC → state propagation
        // 4. UI rebuild with PooledVideoFeed
        await tester.pump();
        await tester.pump();
        await tester.pump();
        await tester.pump();

        expect(find.byType(PooledVideoFeed), findsOneWidget);
      });
    });

    group('RefreshIndicator', () {
      testWidgets('is present when videos are available', (tester) async {
        final videos = createTestVideos();

        await tester.pumpWidget(
          buildSubject(
            feedState: VideoFeedState(
              videos: videos,
              hasMoreContent: true,
              lastUpdated: DateTime.now(),
            ),
          ),
        );

        await tester.pump();
        await tester.pump();
        await tester.pump();
        await tester.pump();

        expect(find.byType(RefreshIndicator), findsOneWidget);
      });

      testWidgets('has correct semantic label', (tester) async {
        final videos = createTestVideos();

        await tester.pumpWidget(
          buildSubject(
            feedState: VideoFeedState(
              videos: videos,
              hasMoreContent: true,
              lastUpdated: DateTime.now(),
            ),
          ),
        );

        await tester.pump();
        await tester.pump();
        await tester.pump();
        await tester.pump();

        final refreshIndicator = tester.widget<RefreshIndicator>(
          find.byType(RefreshIndicator),
        );
        expect(
          refreshIndicator.semanticsLabel,
          equals('searching for more videos'),
        );
      });
    });

    group('non-home route', () {
      testWidgets('renders $SizedBox when route is not home', (tester) async {
        await tester.pumpWidget(
          testMaterialApp(
            home: const HomeScreenRouter(),
            additionalOverrides: [
              pageContextProvider.overrideWith(
                (ref) => Stream.value(
                  const RouteContext(type: RouteType.explore, videoIndex: 0),
                ),
              ),
              homeFeedProvider.overrideWith(
                () => _TestHomeFeed(
                  const VideoFeedState(videos: [], hasMoreContent: false),
                ),
              ),
              homePaginationControllerProvider.overrideWithValue(
                mockPagination,
              ),
              homeRefreshControllerProvider.overrideWithValue(mockRefresh),
              hasVisibleOverlayProvider.overrideWithValue(false),
            ],
          ),
        );

        // Pump to let StreamProvider emit
        await tester.pump();

        expect(find.byType(HomeScreenRouter), findsOneWidget);
        expect(find.byType(PooledVideoFeed), findsNothing);
        expect(find.byType(BrandedLoadingIndicator), findsNothing);
      });
    });

    group('empty state', () {
      testWidgets('shows explore button for discovering videos', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildSubject(
            feedState: VideoFeedState(
              videos: const [],
              hasMoreContent: false,
              lastUpdated: DateTime.now(),
            ),
          ),
        );

        await tester.pump();

        // ElevatedButton.icon() creates _ElevatedButtonWithIcon which
        // has a different runtimeType, so use text + icon finders instead.
        expect(find.text('Explore Videos'), findsOneWidget);
        expect(find.byIcon(Icons.people_outline), findsOneWidget);
      });
    });

    group('lifecycle', () {
      testWidgets('disposes cleanly without errors', (tester) async {
        final videos = createTestVideos();

        await tester.pumpWidget(
          buildSubject(
            feedState: VideoFeedState(
              videos: videos,
              hasMoreContent: true,
              lastUpdated: DateTime.now(),
            ),
          ),
        );

        await tester.pump();
        await tester.pump();
        await tester.pump();
        await tester.pump();

        // Dispose widget tree (simulates navigation away)
        await tester.pumpWidget(const MaterialApp(home: SizedBox()));
        await tester.pump();

        // If we get here without errors, lifecycle is clean
        expect(true, isTrue);
      });
    });
  });
}
