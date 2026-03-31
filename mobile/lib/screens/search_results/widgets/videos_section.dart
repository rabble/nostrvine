import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/video_search/video_search_bloc.dart';
import 'package:openvine/screens/search_results/widgets/section_header.dart';
import 'package:openvine/widgets/user_name.dart';
import 'package:openvine/widgets/video_thumbnail_widget.dart';

/// Always-visible Videos section with a "Videos" header.
///
/// Returns a [SliverMainAxisGroup] so the header and content participate
/// natively in the parent [CustomScrollView]'s sliver protocol.
class VideosSection extends StatelessWidget {
  const VideosSection({super.key});

  @override
  Widget build(BuildContext context) {
    return const SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(child: SectionHeader(title: 'Videos')),
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
      return const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Center(
            child: CircularProgressIndicator(color: VineTheme.vineGreen),
          ),
        ),
      );
    }

    if (videos.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final crossAxisCount = screenWidth >= 600 ? 3 : 2;

    return SliverPadding(
      padding: const EdgeInsets.all(4),
      sliver: SliverMasonryGrid.count(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: 4,
        crossAxisSpacing: 4,
        childCount: videos.length,
        itemBuilder: (context, index) {
          return _SearchVideoTile(
            video: videos[index],
            index: index,
            videos: videos,
          );
        },
      ),
    );
  }
}

class _SearchVideoTile extends StatelessWidget {
  const _SearchVideoTile({
    required this.video,
    required this.index,
    required this.videos,
  });

  final VideoEvent video;
  final int index;
  final List<VideoEvent> videos;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // TODO(#2473): Navigate to video feed mode
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Stack(
          children: [
            VideoThumbnailWidget(video: video),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.only(
                  left: 8,
                  right: 8,
                  bottom: 6,
                  top: 24,
                ),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [VineTheme.transparent, VineTheme.scrim80],
                  ),
                ),
                child: UserName.fromPubKey(
                  video.pubkey,
                  embeddedName: video.authorName,
                  maxLines: 1,
                  style: const TextStyle(
                    color: VineTheme.whiteText,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    shadows: [
                      Shadow(
                        offset: Offset(0, 1),
                        blurRadius: 3,
                        color: VineTheme.scrim50,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
