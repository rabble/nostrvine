import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/blocs/video_feed/video_feed_bloc.dart';
import 'package:openvine/blocs/video_playback_status/video_playback_status_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/overlay_visibility_provider.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/router/router.dart';
import 'package:openvine/screens/explore_screen.dart';
import 'package:openvine/screens/feed/feed_auto_advance_cubit.dart';
import 'package:openvine/screens/feed/feed_mode_switch.dart';
import 'package:openvine/services/feed_performance_tracker.dart';
import 'package:openvine/services/startup_performance_service.dart';
import 'package:openvine/services/view_event_publisher.dart'
    show ViewTrafficSource;
import 'package:openvine/widgets/branded_loading_indicator.dart';
import 'package:openvine/widgets/nav_rounded_shell.dart';
import 'package:openvine/widgets/video_feed_item/feed_videos.dart';

class VideoFeedPage extends ConsumerWidget {
  /// Route name for this screen.
  static const routeName = 'home';

  /// Path for this route.
  static const path = '/home';

  /// Path for this route with index.
  static const pathWithIndex = '/home/:index';

  /// Build path for a specific index.
  static String pathForIndex(int index) => '/home/$index';

  const VideoFeedPage({this.initialMode = FeedMode.forYou, super.key});

  /// The feed mode to start with. Defaults to [FeedMode.forYou].
  final FeedMode initialMode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(divineHostFilterVersionProvider);
    final contentFilterVersion = ref.watch(contentFilterVersionProvider);
    final videosRepository = ref.watch(videosRepositoryProvider);
    final followRepository = ref.watch(followRepositoryProvider);
    final curatedListRepository = ref.watch(curatedListRepositoryProvider);
    final profileRepository = ref.watch(profileRepositoryProvider);
    final authService = ref.watch(authServiceProvider);
    final sharedPreferences = ref.watch(sharedPreferencesProvider);
    final showDivineHostedOnly = ref
        .read(divineHostFilterServiceProvider)
        .showDivineHostedOnly;

    final blocklistRepository = ref.watch(contentBlocklistRepositoryProvider);

    return MultiBlocProvider(
      key: ValueKey(
        'video-feed-$showDivineHostedOnly-$contentFilterVersion',
      ),
      providers: [
        BlocProvider(
          create: (_) => VideoFeedBloc(
            videosRepository: videosRepository,
            followRepository: followRepository,
            curatedListRepository: curatedListRepository,
            profileRepository: profileRepository,
            contentBlocklistRepository: blocklistRepository,
            userPubkey: authService.currentPublicKeyHex,
            sharedPreferences: sharedPreferences,
            serveCachedHomeFeed: !showDivineHostedOnly,
            feedTracker: FeedPerformanceTracker(),
          )..add(VideoFeedStarted(mode: initialMode)),
        ),
        BlocProvider(create: (_) => VideoPlaybackStatusCubit()),
      ],
      child: const VideoFeedView(),
    );
  }
}

@visibleForTesting
class VideoFeedView extends ConsumerStatefulWidget {
  const VideoFeedView({super.key});

  @override
  ConsumerState<VideoFeedView> createState() => _VideoFeedViewState();
}

class _VideoFeedViewState extends ConsumerState<VideoFeedView>
    with WidgetsBindingObserver {
  /// Whether the home tab is currently active.
  ///
  /// Used to prevent overlay-close from resuming playback when the user
  /// has navigated away to another tab (e.g. Search).
  bool _isOnHomeTab = true;

  /// Tracks whether the new native player feed should be active.
  ///
  /// Drives [FeedVideos] pause/resume on tab switches and overlay open/close.
  bool _isNewFeedActive = true;

  /// Guards so startup milestones fire only once.
  bool _hasMarkedUIReady = false;
  bool _hasMarkedVideoReady = false;

  /// Tracks the current fractional page position for scroll-driven overlay opacity.
  late final ValueNotifier<double> _pagePosition;

  /// Feed-scoped Auto playback state. Owned by this state so tests can drive
  /// the screen without also wiring the cubit externally; exposed to children
  /// via `BlocProvider.value` in [build] so the rail control and feed items
  /// can observe/read it.
  final FeedAutoAdvanceCubit _autoAdvanceCubit = FeedAutoAdvanceCubit();

  @override
  void initState() {
    super.initState();
    _pagePosition = ValueNotifier<double>(0);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  @override
  void dispose() {
    _pagePosition.dispose();
    unawaited(_autoAdvanceCubit.close());
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      context.read<VideoFeedBloc>().add(const VideoFeedAutoRefreshRequested());
    }
  }

  void _resumeAutoAdvanceAfterSwipe() => _autoAdvanceCubit.resumeAfterSwipe();

  @override
  Widget build(BuildContext context) {
    // Pause/resume when navigating away from/back to home tab.
    // The home navigator's GlobalKey keeps this widget alive across
    // tab switches, so we must explicitly pause on tab change.
    ref.listen(pageContextProvider, (_, next) {
      final routeType = next.asData?.value.type;
      if (routeType == null) return;

      final isHome = routeType == RouteType.home;
      if (isHome == _isOnHomeTab) return;
      _isOnHomeTab = isHome;

      // Don't resume when GoRouter falsely reports "home" while a pushed
      // overlay (e.g. video recorder) is still open. This happens because
      // GoRouter's routeInformationProvider can emit the shell-route
      // location when popping between pushed routes (recorder → editor →
      // pop back to recorder). The overlay listener handles resume when
      // the overlay actually closes.
      if (isHome && ref.read(overlayVisibilityProvider).hasVisibleOverlay) {
        return;
      }

      setState(() => _isNewFeedActive = isHome);
    });

    // Refresh feed when blocklist changes (block from profile, DM, or relay).
    ref.listen(blocklistVersionProvider, (previous, current) {
      if (previous != null && current > previous) {
        context.read<VideoFeedBloc>().add(const VideoFeedBlocklistChanged());
      }
    });

    // Pause/resume for overlays (drawer, pages, bottom sheets), but only when
    // on the home tab. Without this guard, closing an overlay while on
    // another tab would incorrectly resume the home feed audio.
    //
    // Bottom sheets retain the current player for instant resume.
    // Pages/drawer release all players to free memory.
    ref.listen(overlayVisibilityProvider, (previous, current) {
      if (!_isOnHomeTab) return;

      final hadOverlay = previous?.hasVisibleOverlay ?? false;
      final hasOverlay = current.hasVisibleOverlay;

      if (hasOverlay && !hadOverlay) {
        // Overlay opened - pause with retention based on overlay type
        setState(() => _isNewFeedActive = false);
      } else if (!hasOverlay && hadOverlay) {
        // All overlays closed - resume playback
        setState(() => _isNewFeedActive = true);
      }
    });

    return BlocProvider.value(
      value: _autoAdvanceCubit,
      child: NavRoundedShell(
        innerColor: VineTheme.backgroundColor,
        child: MultiBlocListener(
          listeners: [
            // Reset page position when mode changes.
            BlocListener<VideoFeedBloc, VideoFeedBlocState>(
              listenWhen: (previous, current) => previous.mode != current.mode,
              listener: (_, _) {
                _pagePosition.value = 0;
              },
            ),
            // Mark UI ready when videos first become available.
            BlocListener<VideoFeedBloc, VideoFeedBlocState>(
              listenWhen: (previous, current) =>
                  !previous.isLoaded &&
                  current.isLoaded &&
                  current.videos.isNotEmpty,
              listener: (_, _) {
                if (!_hasMarkedUIReady) {
                  _hasMarkedUIReady = true;
                  StartupPerformanceService.instance.markUIReady();
                }
              },
            ),
          ],
          child: BlocBuilder<VideoFeedBloc, VideoFeedBlocState>(
            builder: (context, state) {
              // Loading state (including initial state before first load)
              if (state.isLoading) {
                return const Center(child: BrandedLoadingIndicator());
              }

              // Error state
              if (state.status == VideoFeedStatus.failure) {
                return _FeedErrorWidget(error: state.error);
              }

              // Empty state
              if (state.isEmpty) {
                return Stack(
                  children: [
                    FeedEmptyWidget(state: state),
                    const FeedModeSwitch(),
                  ],
                );
              }

              // Pull-to-refresh: a [RefreshIndicator] wraps the feed and
              // listens for overscroll notifications from the inner
              // [PageView]. The default predicate (depth == 0) restricts the
              // gesture to the outermost scrollable, so inner overlay
              // scrollables can't trigger a refresh.
              return RefreshIndicator(
                onRefresh: () => _refreshFeed(context),
                child: Stack(
                  children: [
                    FeedVideos(
                      videos: state.videos,
                      contextTitle: state.feedContextTitle,
                      isActive: _isNewFeedActive,
                      hasMore: state.hasMore,
                      isLoadingMore: state.isLoadingMore,
                      trafficSource: ViewTrafficSource.home,
                      onActiveVideoChanged: (video, index) {
                        _resumeAutoAdvanceAfterSwipe();
                        FeedPerformanceTracker().startVideoSwipeTracking(
                          video.id,
                        );
                        if (!_hasMarkedVideoReady && index == 0) {
                          _hasMarkedVideoReady = true;
                          StartupPerformanceService.instance.markVideoReady();
                        }
                      },
                      onNearEnd: () {
                        if (state.hasMore) {
                          context.read<VideoFeedBloc>().add(
                            const VideoFeedLoadMoreRequested(),
                          );
                        }
                      },
                    ),
                    const FeedModeSwitch(),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  /// Dispatches a refresh and resolves when the bloc settles.
  ///
  /// The [RefreshIndicator] keeps its spinner visible until the returned
  /// future completes, so we await the next non-loading state instead of
  /// resolving immediately on dispatch. If the bloc is disposed before
  /// settling (e.g. the user leaves the screen mid-refresh) the stream
  /// closes without matching and [Stream.firstWhere] returns the bloc's
  /// last known state via `orElse`.
  Future<void> _refreshFeed(BuildContext context) async {
    final bloc = context.read<VideoFeedBloc>();
    bloc.add(const VideoFeedRefreshRequested());
    await bloc.stream.firstWhere(
      (s) =>
          s.status == VideoFeedStatus.success ||
          s.status == VideoFeedStatus.failure,
      orElse: () => bloc.state,
    );
  }
}

class _FeedErrorWidget extends StatelessWidget {
  const _FeedErrorWidget({this.error});

  final VideoFeedError? error;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const DivineIcon(
            icon: DivineIconName.warningCircle,
            color: VineTheme.error,
            size: 64,
          ),
          const SizedBox(height: 16),
          Text(
            context.l10n.feedFailedToLoadVideos,
            style: const TextStyle(color: VineTheme.whiteText, fontSize: 18),
          ),
          if (error != null) ...[
            const SizedBox(height: 8),
            Text(
              error.toString(),
              style: const TextStyle(color: VineTheme.lightText),
            ),
          ],
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => context.read<VideoFeedBloc>().add(
              const VideoFeedRefreshRequested(),
            ),
            child: Text(context.l10n.feedRetry),
          ),
        ],
      ),
    );
  }
}

class FeedEmptyWidget extends StatelessWidget {
  const FeedEmptyWidget({required this.state, super.key});

  final VideoFeedBlocState state;

  @override
  Widget build(BuildContext context) {
    final isNoFollowedUsers =
        state.mode == FeedMode.forYou &&
        state.error == VideoFeedError.noFollowedUsers;

    if (state.mode == FeedMode.following) {
      return const _FollowingFeedEmptyState();
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.video_library_outlined,
            color: VineTheme.lightText,
            size: 64,
          ),
          const SizedBox(height: 16),
          Text(
            _getEmptyMessage(context, state),
            style: const TextStyle(color: VineTheme.whiteText, fontSize: 18),
            textAlign: TextAlign.center,
          ),
          if (isNoFollowedUsers) ...[
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => context.go(ExploreScreen.path),
              icon: const DivineIcon(
                icon: DivineIconName.compass,
                color: VineTheme.backgroundColor,
              ),
              label: Text(context.l10n.feedExploreVideos),
              style: FilledButton.styleFrom(
                backgroundColor: VineTheme.vineGreen,
                foregroundColor: VineTheme.backgroundColor,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _getEmptyMessage(BuildContext context, VideoFeedBlocState state) {
    if ((state.mode == FeedMode.following || state.mode == FeedMode.forYou) &&
        state.error == VideoFeedError.noFollowedUsers) {
      return context.l10n.feedNoFollowedUsers;
    }

    return switch (state.mode) {
      FeedMode.forYou => context.l10n.feedForYouEmpty,
      FeedMode.following => context.l10n.feedFollowingEmpty,
      FeedMode.latest => context.l10n.feedLatestEmpty,
    };
  }
}

class _FollowingFeedEmptyState extends StatelessWidget {
  const _FollowingFeedEmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            const _FeedEmptyTestPatternMark(),
            const SizedBox(height: 28),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: Text(
                context.l10n.feedFollowingEmpty,
                style: VineTheme.bodyLargeFont(
                  color: VineTheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 28),
            DivineButton(
              label: context.l10n.feedExploreVideos,
              trailingIcon: DivineIconName.arrowRight,
              onPressed: () => context.go(ExploreScreen.pathForTab('popular')),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeedEmptyTestPatternMark extends StatelessWidget {
  const _FeedEmptyTestPatternMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 112,
      height: 88,
      decoration: BoxDecoration(
        color: VineTheme.surfaceContainer,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: VineTheme.outlineMuted),
      ),
      padding: const EdgeInsets.all(8),
      child: const Column(
        children: [
          Expanded(
            flex: 3,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: ColoredBox(color: VineTheme.primary)),
                Expanded(child: ColoredBox(color: VineTheme.warning)),
                Expanded(child: ColoredBox(color: VineTheme.error)),
                Expanded(child: ColoredBox(color: VineTheme.inverseSurface)),
              ],
            ),
          ),
          SizedBox(height: 6),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 2,
                  child: ColoredBox(color: VineTheme.onSurface),
                ),
                Expanded(child: ColoredBox(color: VineTheme.outlineMuted)),
                Expanded(flex: 2, child: ColoredBox(color: VineTheme.scrim65)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
