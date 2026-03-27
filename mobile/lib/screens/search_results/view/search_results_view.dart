import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/blocs/video_search/video_search_bloc.dart';
import 'package:openvine/widgets/composable_video_grid.dart';

/// View for the unified search results screen.
///
/// Currently shows only the Videos section. People, Tags, and Lists
/// will be added incrementally.
class SearchResultsView extends StatelessWidget {
  const SearchResultsView({super.key});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: VineTheme.backgroundColor,
      child: BlocBuilder<VideoSearchBloc, VideoSearchState>(
        builder: (context, state) {
          if (state.status == VideoSearchStatus.initial) {
            return const SizedBox.shrink();
          }

          if (state.status == VideoSearchStatus.searching &&
              state.videos.isEmpty) {
            return const Center(
              child: CircularProgressIndicator(color: VineTheme.vineGreen),
            );
          }

          if (state.videos.isEmpty) {
            return const Center(
              child: Text(
                'No results found',
                style: TextStyle(color: VineTheme.secondaryText),
              ),
            );
          }

          return ComposableVideoGrid(
            videos: state.videos,
            onVideoTap: (videos, index) {
              // TODO(#2473): Navigate to video feed mode
            },
            useMasonryLayout: true,
          );
        },
      ),
    );
  }
}
