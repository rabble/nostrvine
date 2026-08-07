// ABOUTME: Explore tab rendering one server-configured featured collection.
// ABOUTME: Renders the server's order verbatim — no client sorting or filtering.

import 'package:feed_repository/feed_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/blocs/featured_tabs/featured_tab_videos_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/featured_tabs_providers.dart';
import 'package:openvine/providers/feed_repository_provider.dart';
import 'package:openvine/screens/feed/pooled_fullscreen_video_feed_screen.dart';
import 'package:openvine/services/view_event_publisher.dart';
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
      // Rebuild the cubit when the repository identity changes (environment
      // or relay swap) or when the tab is retargeted to a new configuration.
      key: ValueKey((repository, config.id)),
      create: (_) =>
          FeaturedTabVideosCubit(repository: repository, tabId: config.id)
            ..load(),
      child: const _FeaturedVideosView(),
    );
  }
}

class _FeaturedVideosView extends ConsumerWidget {
  const _FeaturedVideosView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return BlocBuilder<FeaturedTabVideosCubit, FeaturedTabVideosState>(
      builder: (context, state) {
        return switch (state.status) {
          FeaturedTabVideosStatus.initial ||
          FeaturedTabVideosStatus.loading => const Center(
            child: BrandedLoadingIndicator(),
          ),
          FeaturedTabVideosStatus.failure => const _FeaturedRetry(),
          FeaturedTabVideosStatus.ready => ComposableVideoGrid(
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
                source: const ExploreViewSource(),
                feedRepository: ref.read(feedRepositoryProvider),
                initialIndex: index,
                initialVideoId: videos[index].id,
                trafficSource: ViewTrafficSource.discoveryFeatured,
              ),
            ),
          ),
        };
      },
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
          TextButton(
            onPressed: context.read<FeaturedTabVideosCubit>().load,
            child: Text(context.l10n.featuredTabRetry),
          ),
        ],
      ),
    );
  }
}
