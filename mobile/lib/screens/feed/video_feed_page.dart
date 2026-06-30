import 'dart:async';

import 'package:analytics/analytics.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/blocs/video_feed/video_feed_bloc.dart';
import 'package:openvine/blocs/video_playback_status/video_playback_status_cubit.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/foreground_idle_warmup_provider.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/providers/overlay_visibility_provider.dart';
import 'package:openvine/providers/route_feed_providers.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/providers/shell_obscured_provider.dart';
import 'package:openvine/router/router.dart';
import 'package:openvine/screens/feed/feed_auto_advance_cubit.dart';
import 'package:openvine/screens/feed/feed_mode_switch.dart';
import 'package:openvine/screens/feed/video_feed_page/feed_empty_widget.dart';
import 'package:openvine/screens/feed/video_feed_page/feed_error_widget.dart';
import 'package:openvine/services/startup_performance_service.dart';
import 'package:openvine/services/view_event_publisher.dart'
    show ViewTrafficSource;
import 'package:openvine/utils/video_nostr_enrichment.dart';
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

  const VideoFeedPage({
    this.initialMode = FeedMode.forYou,
    this.initialIndex = 0,
    super.key,
  });

  /// The feed mode to start with. Defaults to [FeedMode.forYou].
  final FeedMode initialMode;

  /// The video index restored from the Home route or last-tab position.
  final int initialIndex;

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
    final enrichmentAttemptTracker = NostrTagEnrichmentAttemptTracker();

    return MultiBlocProvider(
      key: ValueKey('video-feed-$showDivineHostedOnly-$contentFilterVersion'),
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
            // Cached-feed serving stays on (constructor default) regardless of
            // the Divine-hosted-only filter: applyContentPreferences re-filters
            // on read and the splice-on-refresh keeps the post-active tail
            // fresh, so the cached serve is never stale to the viewer.
            feedTracker: FeedPerformanceTracker(),
            enrichVideos: (videos) => enrichVideosWithNostrTags(
              videos,
              nostrService: ref.read(nostrServiceProvider),
              callerName: 'VideoFeedBloc',
              attemptTracker: enrichmentAttemptTracker,
            ),
          )..add(VideoFeedStarted(mode: initialMode)),
        ),
        BlocProvider(
          create: (_) => VideoPlaybackStatusCubit(
            canAutoAuthorizeAgeRestrictedMedia: () => ref
                .read(mediaAuthInterceptorProvider)
                .shouldAutoAuthorizeAgeRestrictedMedia,
          ),
        ),
      ],
      child: VideoFeedView(initialIndex: initialIndex),
    );
  }
}

@visibleForTesting
class VideoFeedView extends ConsumerStatefulWidget {
  const VideoFeedView({this.initialIndex = 0, super.key});

  /// The video index to show when the feed first mounts.
  final int initialIndex;

  @override
  ConsumerState<VideoFeedView> createState() => _VideoFeedViewState();
}

class _VideoFeedViewState extends ConsumerState<VideoFeedView>
    with WidgetsBindingObserver {
  /// Tracks whether the new native player feed should be active.
  ///
  /// Drives [FeedVideos] pause/resume on tab switches, route pushes, and
  /// overlay open/close. Kept in sync by [_syncFeedActive].
  bool _isNewFeedActive = true;

  /// Guards so startup milestones fire only once.
  bool _hasMarkedUIReady = false;
  bool _hasMarkedVideoReady = false;

  /// Whether the app has actually been backgrounded since the last resume.
  ///
  /// The launch `resumed` lifecycle event would otherwise trigger an
  /// auto-refresh that wipes the just-served cached feed and resets the
  /// resume index back to the first video. Only a genuine background →
  /// foreground transition should auto-refresh.
  bool _wasBackgrounded = false;

  /// Tracks the current fractional page position for scroll-driven overlay opacity.
  late final ValueNotifier<double> _pagePosition;

  /// Tracks the active Home video without forcing route updates while swiping.
  late int _currentIndex;

  /// Feed-scoped Auto playback state. Owned by this state so tests can drive
  /// the screen without also wiring the cubit externally; exposed to children
  /// via `BlocProvider.value` in [build] so the rail control and feed items
  /// can observe/read it.
  final FeedAutoAdvanceCubit _autoAdvanceCubit = FeedAutoAdvanceCubit();

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex < 0 ? 0 : widget.initialIndex;
    _pagePosition = ValueNotifier<double>(_currentIndex.toDouble());
    WidgetsBinding.instance.addObserver(this);
    // Seed playback from the current signals once mounted, in case this view is
    // first built on a non-home route (e.g. a deep link) where no later change
    // fires the [build] listeners. Deferred so the providers can resolve.
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncFeedActive());
  }

  int _clampIndexForItemCount(int index, int itemCount) {
    if (itemCount == 0) return 0;
    return index.clamp(0, itemCount - 1);
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
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _wasBackgrounded = true;
      return;
    }
    // Only auto-refresh on a genuine background → foreground transition. The
    // spurious `resumed` event during cold start must not fire, or it would
    // wipe the just-served cached feed and reset the resume index.
    if (state == AppLifecycleState.resumed && _wasBackgrounded) {
      _wasBackgrounded = false;
      context.read<VideoFeedBloc>().add(const VideoFeedAutoRefreshRequested());
    }
  }

  void _resumeAutoAdvanceAfterSwipe() => _autoAdvanceCubit.resumeAfterSwipe();

  /// Recomputes whether the home feed should be playing and updates
  /// [_isNewFeedActive] if it changed. The feed is active only when the home
  /// route is current, nothing is pushed over the shell, and no overlay is
  /// open. See the listeners in [build] for the rationale.
  void _syncFeedActive() {
    if (!mounted) return;
    // Home is the first bottom-nav branch (index 0). Use the authoritative
    // active-branch index (set by AppShell from navigationShell) rather than
    // the URL-derived route: the latter can lag on web for StatefulShellRoute
    // branch switches, which left the feed playing on other tabs there.
    final isHomeRoute = ref.read(activeBranchIndexProvider) == 0;
    final isObscured = ref.read(shellObscuredProvider);
    final hasOverlay = ref.read(overlayVisibilityProvider).hasVisibleOverlay;

    final shouldBeActive = isHomeRoute && !isObscured && !hasOverlay;
    if (shouldBeActive == _isNewFeedActive) return;
    setState(() => _isNewFeedActive = shouldBeActive);
  }

  @override
  Widget build(BuildContext context) {
    // The home feed plays only while it is the visible top-level screen: the
    // home route is current, no full-screen route covers the shell, and no
    // overlay (page/bottom sheet) is open. Each signal lives in its own
    // provider, so re-evaluate playback whenever any of them changes. Some
    // pushed routes keep this widget mounted, so playback must follow these
    // signals instead of assuming disposal handles every transition.
    //
    // Uses activeBranchIndexProvider (the authoritative active tab from
    // navigationShell), NOT pageContextProvider: inside the StatefulShellRoute
    // home branch the latter is scoped to "home" and never flips when the tab
    // is backgrounded, and the URL-derived route can lag on web — both would
    // leave the feed playing on other tabs. [shellObscuredProvider] — driven by
    // AppShell's RouteAware subscription to the root navigator — covers the
    // orthogonal case where a full-screen route covers the shell (e.g. profile
    // → fullscreen video → pop back to profile), which the active tab alone
    // cannot detect.
    ref.listen(activeBranchIndexProvider, (_, _) => _syncFeedActive());
    ref.listen(shellObscuredProvider, (_, _) => _syncFeedActive());
    ref.listen(overlayVisibilityProvider, (_, _) => _syncFeedActive());

    // Refresh feed when blocklist changes (block from profile, DM, or relay).
    ref.listen(blocklistVersionProvider, (previous, current) {
      if (previous != null && current > previous) {
        context.read<VideoFeedBloc>().add(const VideoFeedBlocklistChanged());
      }
    });

    // Comments/Share bottom sheets pause the current player but keep the
    // neighbours and disk prefetch warm for instant resume
    // ([OverlayVisibilityState.shouldRetainPlayer]). Only a real backgrounding
    // — tab switch, pushed route, or a full-screen page overlay — releases the
    // off-screen players. Watched (not read) so the flag stays coherent with
    // the overlay state across rebuilds.
    final shouldRetainPlayer = ref
        .watch(overlayVisibilityProvider)
        .shouldRetainPlayer;

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
                _currentIndex = 0;
                _pagePosition.value = 0;
                ref
                    .read(lastTabPositionProvider.notifier)
                    .recordPosition(RouteType.home, 0);
              },
            ),
            // Seed the page position from the BLoC's restored index (cold-start
            // resume / mode switch). Runs before the builder, so [FeedVideos]
            // mounts at the right page. Echoes of the user's own swipe are
            // ignored because [_currentIndex] already matches.
            BlocListener<VideoFeedBloc, VideoFeedBlocState>(
              listenWhen: (previous, current) =>
                  previous.currentIndex != current.currentIndex,
              listener: (_, state) {
                if (state.currentIndex == _currentIndex) return;
                _currentIndex = state.currentIndex;
                _pagePosition.value = state.currentIndex.toDouble();
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
            // The builder renders from the widget's own [_currentIndex], never
            // [state.currentIndex], so a per-swipe index emit must not rebuild
            // the whole feed. Rebuild only when some other field changed.
            buildWhen: (previous, current) =>
                current !=
                previous.copyWith(currentIndex: current.currentIndex),
            builder: (context, state) {
              final itemCount = state.videos.length;
              final clampedIndex = _clampIndexForItemCount(
                _currentIndex,
                itemCount,
              );
              if (clampedIndex != _currentIndex) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted) return;
                  if (_currentIndex >= 0 && _currentIndex < itemCount) return;
                  final normalized = _clampIndexForItemCount(
                    _currentIndex,
                    itemCount,
                  );
                  if (_currentIndex == normalized) return;
                  _currentIndex = normalized;
                  _pagePosition.value = normalized.toDouble();
                  ref
                      .read(lastTabPositionProvider.notifier)
                      .recordPosition(RouteType.home, normalized);
                });
              }

              // Loading state (including initial state before first load)
              if (state.isLoading) {
                return const Center(child: BrandedLoadingIndicator());
              }

              // Error state
              if (state.status == VideoFeedStatus.failure) {
                return FeedErrorWidget(
                  error: state.error,
                  onRetry: () => _refreshFeed(context),
                );
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
                      currentIndex: clampedIndex,
                      isActive: _isNewFeedActive,
                      // The home feed stays mounted across tab switches and
                      // pushed routes (StatefulShellRoute keep-alive), so
                      // release the off-screen neighbour players and pause
                      // disk prefetch while it is backgrounded. Bottom sheets
                      // (comments/share) only pause the current player — they
                      // keep neighbours and prefetch warm via shouldRetainPlayer.
                      releaseNeighboursWhenInactive: !shouldRetainPlayer,
                      hasMore: state.hasMore,
                      isLoadingMore: state.isLoadingMore,
                      trafficSource: ViewTrafficSource.home,
                      onActiveVideoChanged: (video, index) {
                        ref
                            .read(foregroundFeedActivityGateProvider)
                            .markActive();
                        _currentIndex = index;
                        context.read<VideoFeedBloc>().add(
                          VideoFeedActiveIndexChanged(index),
                        );
                        ref
                            .read(lastTabPositionProvider.notifier)
                            .recordPosition(RouteType.home, index);
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
    _currentIndex = 0;
    _pagePosition.value = 0;
    ref
        .read(lastTabPositionProvider.notifier)
        .recordPosition(RouteType.home, 0);
    bloc.add(const VideoFeedRefreshRequested());
    await bloc.stream.firstWhere(
      (s) =>
          s.status == VideoFeedStatus.success ||
          s.status == VideoFeedStatus.failure,
      orElse: () => bloc.state,
    );
  }
}
