import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
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
      child: const VideoFeedView(),
    );
  }
}

@visibleForTesting
class VideoFeedView extends StatefulWidget {
  const VideoFeedView({super.key});

  @override
  State<VideoFeedView> createState() => _VideoFeedViewState();
}

class _VideoFeedViewState extends State<VideoFeedView> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
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
              const _FeedModeSwitch(),
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
            ],
          );
        },
      ),
    );
  }
}

class _FeedModeSwitch extends StatelessWidget {
  const _FeedModeSwitch();

  static const _feedModeLabels = {
    FeedMode.latest: 'New',
    FeedMode.popular: 'Popular',
    FeedMode.home: 'Following',
  };

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0x3D000000), // rgba(0,0,0,0.24)
              Colors.transparent,
            ],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 16),
            child: BlocBuilder<VideoFeedBloc, VideoFeedState>(
              buildWhen: (prev, curr) => prev.mode != curr.mode,
              builder: (context, state) {
                return Center(
                  child: GestureDetector(
                    onTap: () => _showFeedModeBottomSheet(context, state.mode),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _feedModeLabels[state.mode] ?? state.mode.name,
                          style: VineTheme.titleFont(fontSize: 28).copyWith(
                            shadows: [
                              const Shadow(
                                color: Color(0x1A000000),
                                offset: Offset(1, 1),
                                blurRadius: 1,
                              ),
                              const Shadow(
                                color: Color(0x1A000000),
                                offset: Offset(0.4, 0.4),
                                blurRadius: 0.6,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 32,
                          height: 32,
                          child: SvgPicture.asset(
                            'assets/icon/CaretDown.svg',
                            colorFilter: const ColorFilter.mode(
                              Colors.white,
                              BlendMode.srcIn,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showFeedModeBottomSheet(
    BuildContext context,
    FeedMode currentMode,
  ) async {
    final selected = await VineBottomSheetSelectionMenu.show(
      context: context,
      selectedValue: currentMode.name,
      options: const [
        VineBottomSheetSelectionOptionData(label: 'New', value: 'latest'),
        VineBottomSheetSelectionOptionData(label: 'Popular', value: 'popular'),
        VineBottomSheetSelectionOptionData(label: 'Following', value: 'home'),
      ],
    );

    if (selected != null && context.mounted) {
      final mode = FeedMode.values.firstWhere((m) => m.name == selected);
      context.read<VideoFeedBloc>().add(VideoFeedModeChanged(mode));
    }
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
