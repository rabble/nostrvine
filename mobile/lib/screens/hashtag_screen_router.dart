// ABOUTME: Router-aware hashtag screen that shows grid or feed based on URL
// ABOUTME: Uses HashtagFeedBloc for data fetching via Funnelcake + relay fallback

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/blocs/hashtag_feed/hashtag_feed_bloc.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/router/router.dart';
import 'package:openvine/screens/pure/explore_video_screen_pure.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:openvine/widgets/composable_video_grid.dart';

/// Router-aware hashtag screen that shows grid or feed based on route
class HashtagScreenRouter extends ConsumerWidget {
  /// Route name for this screen.
  static const routeName = 'hashtag';

  /// Base path for hashtag routes.
  static const basePath = '/hashtag';

  /// Path for this route (grid mode).
  static const path = '/hashtag/:tag';

  /// Path for this route with video index (feed mode).
  static const pathWithIndex = '/hashtag/:tag/:index';

  /// Build path for a specific hashtag with optional video index.
  static String pathForTag(String tag, {int? index}) {
    final encodedTag = Uri.encodeComponent(tag);
    if (index == null) return '$basePath/$encodedTag';
    return '$basePath/$encodedTag/$index';
  }

  const HashtagScreenRouter({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final routeCtx = ref.watch(pageContextProvider).asData?.value;

    if (routeCtx == null || routeCtx.type != RouteType.hashtag) {
      Log.warning(
        'HashtagScreenRouter: Invalid route context',
        name: 'HashtagRouter',
        category: LogCategory.ui,
      );
      return const Scaffold(body: Center(child: Text('Invalid hashtag route')));
    }

    final hashtag = routeCtx.hashtag ?? 'trending';
    final videoIndex = routeCtx.videoIndex;
    final videosRepository = ref.read(videosRepositoryProvider);

    return BlocProvider(
      create: (_) =>
          HashtagFeedBloc(videosRepository: videosRepository)
            ..add(HashtagFeedStarted(hashtag)),
      child: _HashtagFeedView(hashtag: hashtag, videoIndex: videoIndex),
    );
  }
}

class _HashtagFeedView extends StatelessWidget {
  const _HashtagFeedView({required this.hashtag, this.videoIndex});

  final String hashtag;
  final int? videoIndex;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<HashtagFeedBloc, HashtagFeedState>(
      builder: (context, state) {
        // Loading state
        if (state.isLoading) {
          return _HashtagLoadingWidget(hashtag: hashtag);
        }

        // Error state
        if (state.status == HashtagFeedStatus.failure) {
          return _HashtagErrorWidget(hashtag: hashtag);
        }

        // Empty state
        if (state.isEmpty) {
          return _HashtagEmptyWidget(hashtag: hashtag);
        }

        // Grid mode: no video index
        if (videoIndex == null) {
          return ComposableVideoGrid(
            videos: state.videos,
            useMasonryLayout: true,
            hasMoreContent: state.hasMore,
            isLoadingMore: state.isLoadingMore,
            onVideoTap: (videos, index) {
              context.go(HashtagScreenRouter.pathForTag(hashtag, index: index));
            },
            onRefresh: () async {
              context.read<HashtagFeedBloc>().add(
                const HashtagFeedRefreshRequested(),
              );
            },
            onLoadMore: () async {
              context.read<HashtagFeedBloc>().add(
                const HashtagFeedLoadMoreRequested(),
              );
            },
          );
        }

        // Feed mode: show fullscreen video player
        final safeIndex = videoIndex!.clamp(0, state.videos.length - 1);

        return ExploreVideoScreenPure(
          startingVideo: state.videos[safeIndex],
          videoList: state.videos,
          contextTitle: '#$hashtag',
          startingIndex: safeIndex,
          onLoadMore: () {
            context.read<HashtagFeedBloc>().add(
              const HashtagFeedLoadMoreRequested(),
            );
          },
          onNavigate: (index) =>
              context.go(HashtagScreenRouter.pathForTag(hashtag, index: index)),
        );
      },
    );
  }
}

class _HashtagLoadingWidget extends StatelessWidget {
  const _HashtagLoadingWidget({required this.hashtag});

  final String hashtag;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: VineTheme.vineGreen),
          const SizedBox(height: 24),
          Text(
            'Loading videos about #$hashtag...',
            style: const TextStyle(
              color: VineTheme.primaryText,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _HashtagErrorWidget extends StatelessWidget {
  const _HashtagErrorWidget({required this.hashtag});

  final String hashtag;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: VineTheme.error, size: 64),
          const SizedBox(height: 16),
          Text(
            'Failed to load #$hashtag videos',
            style: const TextStyle(color: VineTheme.primaryText, fontSize: 18),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => context.read<HashtagFeedBloc>().add(
              const HashtagFeedRefreshRequested(),
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

class _HashtagEmptyWidget extends StatelessWidget {
  const _HashtagEmptyWidget({required this.hashtag});

  final String hashtag;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.tag, size: 64, color: VineTheme.secondaryText),
          const SizedBox(height: 16),
          Text(
            'No videos found for #$hashtag',
            style: const TextStyle(
              color: VineTheme.primaryText,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Be the first to post a video with this hashtag!',
            style: TextStyle(color: VineTheme.secondaryText, fontSize: 14),
          ),
        ],
      ),
    );
  }
}
