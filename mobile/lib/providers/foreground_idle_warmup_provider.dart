// ABOUTME: App-shell providers for foreground-idle data warmups.
// ABOUTME: Warms existing feed and notification caches without prefetching media bytes.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/constants/app_constants.dart';
import 'package:openvine/notifications/services/notification_refresh_coordinator.dart';
import 'package:openvine/providers/app_foreground_provider.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/providers/for_you_provider.dart';
import 'package:openvine/providers/new_videos_feed_provider.dart';
import 'package:openvine/providers/popular_videos_feed_provider.dart';
import 'package:openvine/providers/repository_providers.dart';
import 'package:openvine/providers/video_providers.dart';
import 'package:openvine/services/foreground_idle_warmup_coordinator.dart';

/// Coordinates low-priority data warmups for adjacent app surfaces.
final foregroundIdleWarmupCoordinatorProvider =
    Provider<ForegroundIdleWarmupCoordinator>((ref) {
      return ForegroundIdleWarmupCoordinator(
        isForeground: () => ref.read(appForegroundProvider),
        // The scheduler only fires after startup settles and then very
        // occasionally. Keep this gate explicit so richer idle signals can be
        // added without changing task semantics.
        isIdle: () => ref.read(appForegroundProvider),
        tasks: [
          ForegroundIdleWarmupTask(
            id: ForegroundIdleWarmupTaskId.forYou,
            cooldown: const Duration(minutes: 10),
            run: () async {
              await ref.read(forYouFeedProvider.future);
            },
          ),
          ForegroundIdleWarmupTask(
            id: ForegroundIdleWarmupTaskId.following,
            cooldown: const Duration(minutes: 10),
            run: () async {
              final following = ref
                  .read(followRepositoryProvider)
                  .followingPubkeys;
              if (following.isEmpty) return;

              await ref
                  .read(videosRepositoryProvider)
                  .getHomeFeedVideos(
                    authors: following,
                    userPubkey: ref
                        .read(authServiceProvider)
                        .currentPublicKeyHex,
                    limit: AppConstants.paginationBatchSize,
                  );
            },
          ),
          ForegroundIdleWarmupTask(
            id: ForegroundIdleWarmupTaskId.newVideos,
            cooldown: const Duration(minutes: 10),
            run: () async {
              await ref.read(newVideosFeedProvider.future);
            },
          ),
          ForegroundIdleWarmupTask(
            id: ForegroundIdleWarmupTaskId.popular,
            cooldown: const Duration(minutes: 10),
            run: () async {
              await ref.read(popularVideosFeedProvider.future);
            },
          ),
          ForegroundIdleWarmupTask(
            id: ForegroundIdleWarmupTaskId.notifications,
            cooldown: const Duration(minutes: 1),
            run: () async {
              await ref
                  .read(notificationRefreshCoordinatorProvider)
                  ?.refresh(
                    reason: NotificationRefreshReason.foregroundIdleWarmup,
                  );
            },
          ),
        ],
      );
    });

/// Starts the foreground-idle warmup schedule for the app shell.
final foregroundIdleWarmupSchedulerProvider =
    Provider<ForegroundIdleWarmupScheduler>((ref) {
      final coordinator = ref.watch(foregroundIdleWarmupCoordinatorProvider);
      final scheduler = ForegroundIdleWarmupScheduler(
        requestWarmup: (trigger) => coordinator.requestWarmup(trigger: trigger),
      );
      ref.onDispose(scheduler.stop);
      return scheduler;
    });
