import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/blocs/video_search/video_search_bloc.dart';
import 'package:openvine/screens/search_results/widgets/section_header.dart';
import 'package:openvine/widgets/composable_video_grid.dart';

/// Always-visible Videos section with a "Videos" header.
///
/// Content below the header reacts to [VideoSearchBloc] state via
/// granular [context.select] rebuilds.
class VideosSection extends StatelessWidget {
  const VideosSection({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SectionHeader(title: 'Videos'),
        _VideosContent(),
      ],
    );
  }
}

class _VideosContent extends StatelessWidget {
  const _VideosContent();

  @override
  Widget build(BuildContext context) {
    final status = context.select(
      (VideoSearchBloc bloc) => bloc.state.status,
    );
    final videos = context.select(
      (VideoSearchBloc bloc) => bloc.state.videos,
    );

    if ((status == .initial || status == .searching) && videos.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: CircularProgressIndicator(color: VineTheme.vineGreen),
        ),
      );
    }

    if (videos.isEmpty) return const SizedBox.shrink();

    return ComposableVideoGrid(
      videos: videos,
      onVideoTap: (videos, index) {
        // TODO(#2473): Navigate to video feed mode
      },
      useMasonryLayout: true,
    );
  }
}
