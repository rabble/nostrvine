import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/blocs/video_feed/video_feed_bloc.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/screens/feed/video_page_view.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:openvine/widgets/branded_loading_indicator.dart';

class VideoFeedPage extends ConsumerWidget {
  static const String path = '/new-video-feed';

  static const String routeName = 'new-video-feed';

  const VideoFeedPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final videosRepository = ref.read(videosRepositoryProvider);
    final followRepository = ref.read(followRepositoryProvider);

    return BlocProvider(
      create: (_) => VideoFeedBloc(
        videosRepository: videosRepository,
        followRepository: followRepository,
      )..add(const VideoFeedStarted(mode: FeedMode.latest)),
    );
  }
}

class _VideoFeedView extends ConsumerStatefulWidget {
  const _VideoFeedView();

  @override
  ConsumerState<_VideoFeedView> createState() => _VideoFeedViewState();
}

class _VideoFeedViewState extends ConsumerState<_VideoFeedView> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: BlocBuilder<VideoFeedBloc, VideoFeedState>(
          buildWhen: (prev, curr) => prev.mode != curr.mode,
          builder: (context, state) => Text(
            state.mode.name.toUpperCase(),
            style: const TextStyle(color: Colors.white),
          ),
        ),
        actions: [
          _FeedModeSwitch(),
          // Refresh button
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () {
              context.read<VideoFeedBloc>().add(
                const VideoFeedRefreshRequested(),
              );
            },
          ),
        ],
      ),
      body: BlocBuilder<VideoFeedBloc, VideoFeedState>(
        builder: (context, state) {
          // Loading state (including initial state before first load)
          if (state.isLoading) {
            return const Center(child: BrandedLoadingIndicator(size: 80));
          }

          // Error state
          if (state.status == VideoFeedStatus.failure) {
            return _FeedErrorWidget(error: state.error);
          }

          // Empty state
          if (state.isEmpty) {
            return FeedEmptyWidget(state: state);
          }

          // Note: RefreshIndicator removed - it conflicts with PageView
          // scrolling and adds memory overhead. Use the refresh button instead.
          return Stack(
            children: [
              VideoPageView(
                videos: state.videos,
                contextTitle: 'BLoC Test (${state.mode.name})',
                hasBottomNavigation: false,
                onLoadMore: state.hasMore
                    ? () => context.read<VideoFeedBloc>().add(
                        const VideoFeedLoadMoreRequested(),
                      )
                    : null,
              ),
              // Loading more indicator
              if (state.isLoadingMore)
                const Positioned(
                  bottom: 100,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: CircularProgressIndicator(
                      color: VineTheme.vineGreen,
                      strokeWidth: 2,
                    ),
                  ),
                ),
              // Debug info overlay
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Videos: ${state.videos.length} | '
                    'HasMore: ${state.hasMore}',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _FeedModeSwitch extends StatelessWidget {
  const _FeedModeSwitch();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<VideoFeedBloc, VideoFeedState>(
      buildWhen: (prev, curr) => prev.mode != curr.mode,
      builder: (context, state) => IconButton(
        icon: const Icon(Icons.filter_list, color: Colors.white),
        onPressed: () => _showFeedModeBottomSheet(context, state.mode),
      ),
    );
  }

  void _showFeedModeBottomSheet(BuildContext context, FeedMode currentMode) {
    VineBottomSheet.show<FeedMode>(
      context: context,
      initialChildSize: 0.35,
      minChildSize: 0.25,
      maxChildSize: 0.5,
      title: Text(
        'Feed Mode',
        style: VineTheme.titleFont(fontSize: 18, color: VineTheme.onSurface),
      ),
      children: FeedMode.values.map((mode) {
        final isSelected = mode == currentMode;
        return _FeedModeOption(
          mode: mode,
          isSelected: isSelected,
          onTap: () {
            Navigator.of(context).pop(mode);
            context.read<VideoFeedBloc>().add(VideoFeedModeChanged(mode));
          },
        );
      }).toList(),
    );
  }
}

class _FeedModeOption extends StatelessWidget {
  const _FeedModeOption({
    required this.mode,
    required this.isSelected,
    required this.onTap,
  });

  final FeedMode mode;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Row(
          children: [
            Icon(
              _getIconForMode(mode),
              color: isSelected ? VineTheme.vineGreen : Colors.white70,
              size: 24,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    mode.name.toUpperCase(),
                    style: VineTheme.bodyFont(
                      color: isSelected ? VineTheme.vineGreen : Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _getDescriptionForMode(mode),
                    style: VineTheme.bodyFont(
                      fontSize: 12,
                      color: Colors.white54,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check_circle,
                color: VineTheme.vineGreen,
                size: 24,
              ),
          ],
        ),
      ),
    );
  }

  IconData _getIconForMode(FeedMode mode) {
    return switch (mode) {
      FeedMode.home => Icons.home_outlined,
      FeedMode.latest => Icons.schedule,
      FeedMode.popular => Icons.trending_up,
    };
  }

  String _getDescriptionForMode(FeedMode mode) {
    return switch (mode) {
      FeedMode.home => 'Videos from users you follow',
      FeedMode.latest => 'Newest videos first',
      FeedMode.popular => 'Most engaging videos',
    };
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
          const Icon(Icons.error_outline, color: Colors.red, size: 64),
          const SizedBox(height: 16),
          const Text(
            'Failed to load videos',
            style: TextStyle(color: Colors.white, fontSize: 18),
          ),
          if (error != null) ...[
            const SizedBox(height: 8),
            Text(error.toString(), style: const TextStyle(color: Colors.grey)),
          ],
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => context.read<VideoFeedBloc>().add(
              const VideoFeedRefreshRequested(),
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

class FeedEmptyWidget extends StatelessWidget {
  const FeedEmptyWidget({required this.state, super.key});

  final VideoFeedState state;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.video_library_outlined,
            color: Colors.grey,
            size: 64,
          ),
          const SizedBox(height: 16),
          Text(
            _getEmptyMessage(state),
            style: const TextStyle(color: Colors.white, fontSize: 18),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  String _getEmptyMessage(VideoFeedState state) {
    if (state.mode == FeedMode.home &&
        state.error == VideoFeedError.noFollowedUsers) {
      return 'No followed users.\nFollow someone to see their videos here.';
    }
    return 'No videos found for ${state.mode.name} feed.';
  }
}
