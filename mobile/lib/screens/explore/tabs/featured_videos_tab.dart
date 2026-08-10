// ABOUTME: Explore tab rendering one server-configured featured collection.
// ABOUTME: Renders the server's order verbatim — no client sorting or filtering.

import 'package:divine_ui/divine_ui.dart';
import 'package:feed_repository/feed_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/blocs/featured_tabs/featured_tab_videos_cubit.dart';
import 'package:openvine/blocs/featured_tabs/featured_tabs_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/view_traffic_source.dart';
import 'package:openvine/providers/featured_tabs_providers.dart';
import 'package:openvine/providers/feed_repository_provider.dart';
import 'package:openvine/screens/feed/pooled_fullscreen_video_feed_screen.dart';
import 'package:openvine/widgets/branded_loading_indicator.dart';
import 'package:openvine/widgets/composable_video_grid.dart';

/// Grid of videos for the configured featured tab [config].
///
/// The tab is addressed by opaque id; this widget never learns which hashtag
/// backs it, and renders the returned page order as-is.
class FeaturedVideosTab extends ConsumerWidget {
  /// Creates the featured tab content for [config].
  const FeaturedVideosTab({required this.config, super.key});

  /// The resolved configuration driving this tab.
  final FeaturedTabConfig config;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.watch(featuredTabsRepositoryProvider);
    return BlocProvider<FeaturedTabVideosCubit>(
      // Rebuild the cubit when the repository identity changes (environment or
      // relay swap) or when anything about the configuration changes. Keyed on
      // the whole config, not just its id: the admin endpoint upserts by id, so
      // a tab can be retargeted in place, and the backing hashtag is
      // deliberately absent from the public config — the visible fields are the
      // only retarget signal the client can see.
      key: ValueKey((repository, config)),
      create: (_) =>
          FeaturedTabVideosCubit(repository: repository, tabId: config.id)
            ..load(),
      child: _FeaturedVideosRetryOnPoll(
        child: _FeaturedVideosView(config: config),
      ),
    );
  }
}

/// Refetches the page when a config poll lands while the tab is empty.
///
/// `has_content` runs on a 15-minute snapshot cadence and can lead the videos
/// endpoint, so funnelcake's integration guide asks clients to treat an empty
/// page as transient and retry on the next poll.
/// [FeaturedTabVideosState.isEmpty] already says as much; this is what acts on
/// it. Only the empty case retries, so a populated grid never loses the user's
/// scroll position to a background poll.
class _FeaturedVideosRetryOnPoll extends StatelessWidget {
  const _FeaturedVideosRetryOnPoll({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return BlocListener<FeaturedTabsCubit, FeaturedTabsState>(
      listenWhen: (previous, current) =>
          previous.status != FeaturedTabsStatus.resolved &&
          current.status == FeaturedTabsStatus.resolved,
      listener: (context, _) {
        final videos = context.read<FeaturedTabVideosCubit>();
        if (videos.state.isEmpty) videos.load();
      },
      child: child,
    );
  }
}

class _FeaturedVideosView extends StatelessWidget {
  const _FeaturedVideosView({required this.config});

  final FeaturedTabConfig config;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<FeaturedTabVideosCubit, FeaturedTabVideosState>(
      listenWhen: (previous, current) =>
          previous.status != FeaturedTabVideosStatus.failure &&
          current.status == FeaturedTabVideosStatus.failure &&
          current.videos.isNotEmpty,
      listener: (context, state) {
        ScaffoldMessenger.of(context).showSnackBar(
          DivineSnackbarContainer.snackBar(
            context.l10n.featuredTabLoadFailed,
            error: true,
          ),
        );
      },
      builder: (context, state) {
        if (state.videos.isNotEmpty) {
          return _FeaturedGrid(config: config, state: state);
        }

        return switch (state.status) {
          FeaturedTabVideosStatus.initial || FeaturedTabVideosStatus.loading =>
            const Center(child: BrandedLoadingIndicator()),
          FeaturedTabVideosStatus.failure => const _FeaturedRetry(),
          FeaturedTabVideosStatus.ready => _FeaturedGrid(
            config: config,
            state: state,
          ),
        };
      },
    );
  }
}

class _FeaturedGrid extends ConsumerWidget {
  const _FeaturedGrid({required this.config, required this.state});

  final FeaturedTabConfig config;
  final FeaturedTabVideosState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ComposableVideoGrid(
      videos: state.videos,
      useMasonryLayout: true,
      isLoadingMore: state.isLoadingMore,
      hasMoreContent: state.hasMore,
      onLoadMore: context.read<FeaturedTabVideosCubit>().loadMore,
      onRefresh: context.read<FeaturedTabVideosCubit>().load,
      emptyBuilder: () => const _FeaturedEmpty(),
      onVideoTap: (videos, index) => context.push(
        PooledFullscreenVideoFeedScreen.pathForVideoId(videos[index].id),
        extra: PooledFullscreenVideoFeedArgs(
          source: VideoListViewSource(videos),
          feedRepository: ref.read(feedRepositoryProvider),
          initialIndex: index,
          initialVideoId: videos[index].id,
          trafficSource: ViewTrafficSource.discoveryFeatured,
          sourceDetail: config.id,
        ),
      ),
    );
  }
}

class _FeaturedEmpty extends StatelessWidget {
  const _FeaturedEmpty();

  @override
  Widget build(BuildContext context) {
    return Center(child: Text(context.l10n.featuredTabEmpty));
  }
}

class _FeaturedRetry extends StatelessWidget {
  const _FeaturedRetry();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: 12,
        children: [
          Text(context.l10n.featuredTabLoadFailed),
          DivineButton(
            label: context.l10n.featuredTabRetry,
            type: DivineButtonType.secondary,
            onPressed: context.read<FeaturedTabVideosCubit>().load,
          ),
        ],
      ),
    );
  }
}
