// ABOUTME: Provider wiring tests for foreground-idle warmup tasks.
// ABOUTME: Verifies app-shell gates and dependency arguments without real IO.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follow_repository/follow_repository.dart';
import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/constants/app_constants.dart';
import 'package:openvine/notifications/services/notification_refresh_coordinator.dart';
import 'package:openvine/providers/app_foreground_provider.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/providers/curation_providers.dart';
import 'package:openvine/providers/for_you_provider.dart';
import 'package:openvine/providers/foreground_idle_warmup_provider.dart';
import 'package:openvine/providers/new_videos_feed_provider.dart';
import 'package:openvine/providers/popular_videos_feed_provider.dart';
import 'package:openvine/providers/repository_providers.dart';
import 'package:openvine/providers/video_providers.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/foreground_idle_warmup_coordinator.dart';
import 'package:openvine/state/video_feed_state.dart';
import 'package:videos_repository/videos_repository.dart';

class _MockFollowRepository extends Mock implements FollowRepository {}

class _MockVideosRepository extends Mock implements VideosRepository {}

class _MockAuthService extends Mock implements AuthService {}

class _MockNotificationRefreshCoordinator extends Mock
    implements NotificationRefreshCoordinator {}

class _AvailableFunnelcake extends FunnelcakeAvailable {
  @override
  Future<bool> build() async => true;
}

Completer<bool>? _funnelcakeAvailabilityCompleter;

class _LoadingFunnelcake extends FunnelcakeAvailable {
  @override
  Future<bool> build() => _funnelcakeAvailabilityCompleter!.future;
}

final _feedBuilds = <String>[];
const _expectedEmptyFollowingWarmupBuilds = [
  'forYou',
  'newVideos',
  'popular',
  'popular:native',
  'popular:classic',
];

class _TestForYouFeed extends ForYouFeed {
  @override
  Future<VideoFeedState> build() async {
    _feedBuilds.add('forYou');
    return const VideoFeedState(videos: [], hasMoreContent: false);
  }
}

class _TestNewVideosFeed extends NewVideosFeed {
  @override
  Future<VideoFeedState> build() async {
    _feedBuilds.add('newVideos');
    return const VideoFeedState(videos: [], hasMoreContent: false);
  }
}

class _TestPopularVideosFeed extends PopularVideosFeed {
  @override
  Future<VideoFeedState> build() async {
    _feedBuilds.add('popular');
    return const VideoFeedState(videos: [], hasMoreContent: false);
  }

  @override
  Future<void> preloadVariant(PopularVideosVariant variant) async {
    _feedBuilds.add('popular:${variant.name}');
  }
}

void main() {
  group('foregroundIdleWarmupCoordinatorProvider', () {
    late _MockFollowRepository followRepository;
    late _MockVideosRepository videosRepository;
    late _MockAuthService authService;
    late _MockNotificationRefreshCoordinator notificationCoordinator;

    ProviderContainer createContainer({
      required List<String> following,
      bool funnelcakeAvailabilityLoading = false,
    }) {
      when(() => followRepository.followingPubkeys).thenReturn(following);
      when(() => authService.currentPublicKeyHex).thenReturn('viewer-pubkey');
      when(
        () => videosRepository.getHomeFeedVideos(
          authors: any(named: 'authors'),
          videoRefs: any(named: 'videoRefs'),
          userPubkey: any(named: 'userPubkey'),
          limit: any(named: 'limit'),
          until: any(named: 'until'),
          skipCache: any(named: 'skipCache'),
        ),
      ).thenAnswer((_) async => const HomeFeedResult(videos: []));
      when(
        () => notificationCoordinator.refresh(
          reason: NotificationRefreshReason.foregroundIdleWarmup,
        ),
      ).thenAnswer((_) async {});

      final container = ProviderContainer(
        overrides: [
          followRepositoryProvider.overrideWithValue(followRepository),
          videosRepositoryProvider.overrideWithValue(videosRepository),
          authServiceProvider.overrideWithValue(authService),
          notificationRefreshCoordinatorProvider.overrideWithValue(
            notificationCoordinator,
          ),
          funnelcakeAvailableProvider.overrideWith(
            funnelcakeAvailabilityLoading
                ? _LoadingFunnelcake.new
                : _AvailableFunnelcake.new,
          ),
          forYouFeedProvider.overrideWith(_TestForYouFeed.new),
          newVideosFeedProvider.overrideWith(_TestNewVideosFeed.new),
          popularVideosFeedProvider.overrideWith(_TestPopularVideosFeed.new),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    setUp(() {
      followRepository = _MockFollowRepository();
      videosRepository = _MockVideosRepository();
      authService = _MockAuthService();
      notificationCoordinator = _MockNotificationRefreshCoordinator();
      _feedBuilds.clear();
      _funnelcakeAvailabilityCompleter = null;
    });

    test('foreground=false gates all warmup work', () async {
      final container = createContainer(following: const ['author-pubkey']);
      container.read(appForegroundProvider.notifier).setForeground(false);

      await container
          .read(foregroundIdleWarmupCoordinatorProvider)
          .requestWarmup(
            trigger: ForegroundIdleWarmupTrigger.videoPlaybackSettled,
          );

      expect(_feedBuilds, isEmpty);
      verifyNever(() => followRepository.followingPubkeys);
      verifyNever(
        () => videosRepository.getHomeFeedVideos(
          authors: any(named: 'authors'),
          videoRefs: any(named: 'videoRefs'),
          userPubkey: any(named: 'userPubkey'),
          limit: any(named: 'limit'),
          until: any(named: 'until'),
          skipCache: any(named: 'skipCache'),
        ),
      );
      verifyNever(
        () => notificationCoordinator.refresh(
          reason: NotificationRefreshReason.foregroundIdleWarmup,
        ),
      );
    });

    test('recent foreground feed activity gates all warmup work', () async {
      final container = createContainer(following: const ['author-pubkey']);
      container.read(foregroundFeedActivityGateProvider).markActive();

      await container
          .read(foregroundIdleWarmupCoordinatorProvider)
          .requestWarmup(
            trigger: ForegroundIdleWarmupTrigger.videoPlaybackSettled,
          );

      expect(_feedBuilds, isEmpty);
      verifyNever(() => followRepository.followingPubkeys);
      verifyNever(
        () => videosRepository.getHomeFeedVideos(
          authors: any(named: 'authors'),
          videoRefs: any(named: 'videoRefs'),
          userPubkey: any(named: 'userPubkey'),
          limit: any(named: 'limit'),
          until: any(named: 'until'),
          skipCache: any(named: 'skipCache'),
        ),
      );
      verifyNever(
        () => notificationCoordinator.refresh(
          reason: NotificationRefreshReason.foregroundIdleWarmup,
        ),
      );
    });

    test('unresolved Funnelcake availability skips For You warmup', () async {
      _funnelcakeAvailabilityCompleter = Completer<bool>();
      final container = createContainer(
        following: const [],
        funnelcakeAvailabilityLoading: true,
      );

      await container
          .read(foregroundIdleWarmupCoordinatorProvider)
          .requestWarmup(
            trigger: ForegroundIdleWarmupTrigger.videoPlaybackSettled,
          );

      expect(_feedBuilds, [
        'newVideos',
        'popular',
        'popular:native',
        'popular:classic',
      ]);

      _funnelcakeAvailabilityCompleter!.complete(true);
      await container.read(funnelcakeAvailableProvider.future);

      await container
          .read(foregroundIdleWarmupCoordinatorProvider)
          .requestWarmup(
            trigger: ForegroundIdleWarmupTrigger.periodicIdleCheck,
          );

      expect(_feedBuilds, [
        'newVideos',
        'popular',
        'popular:native',
        'popular:classic',
        'forYou',
      ]);
    });

    test('empty following list skips home feed repository fetch', () async {
      final container = createContainer(following: const []);
      await container.read(funnelcakeAvailableProvider.future);

      await container
          .read(foregroundIdleWarmupCoordinatorProvider)
          .requestWarmup(
            trigger: ForegroundIdleWarmupTrigger.videoPlaybackSettled,
          );

      expect(_feedBuilds, _expectedEmptyFollowingWarmupBuilds);
      verify(() => followRepository.followingPubkeys).called(1);
      verifyNever(
        () => videosRepository.getHomeFeedVideos(
          authors: any(named: 'authors'),
          videoRefs: any(named: 'videoRefs'),
          userPubkey: any(named: 'userPubkey'),
          limit: any(named: 'limit'),
          until: any(named: 'until'),
          skipCache: any(named: 'skipCache'),
        ),
      );
    });

    test('popular warmup preloads native and classic variants', () async {
      final container = createContainer(following: const []);
      await container.read(funnelcakeAvailableProvider.future);

      await container
          .read(foregroundIdleWarmupCoordinatorProvider)
          .requestWarmup(
            trigger: ForegroundIdleWarmupTrigger.videoPlaybackSettled,
          );

      expect(_feedBuilds, _expectedEmptyFollowingWarmupBuilds);
    });

    test('notification warmup uses foreground idle warmup reason', () async {
      final container = createContainer(following: const []);
      await container.read(funnelcakeAvailableProvider.future);

      await container
          .read(foregroundIdleWarmupCoordinatorProvider)
          .requestWarmup(
            trigger: ForegroundIdleWarmupTrigger.videoPlaybackSettled,
          );

      verify(
        () => notificationCoordinator.refresh(
          reason: NotificationRefreshReason.foregroundIdleWarmup,
        ),
      ).called(1);
    });

    test(
      'non-empty following fetches home feed with current user and batch size',
      () async {
        final container = createContainer(following: const ['author-pubkey']);
        await container.read(funnelcakeAvailableProvider.future);

        await container
            .read(foregroundIdleWarmupCoordinatorProvider)
            .requestWarmup(
              trigger: ForegroundIdleWarmupTrigger.videoPlaybackSettled,
            );

        verify(
          () => videosRepository.getHomeFeedVideos(
            authors: const ['author-pubkey'],
            userPubkey: 'viewer-pubkey',
            limit: AppConstants.paginationBatchSize,
          ),
        ).called(1);
      },
    );
  });
}
