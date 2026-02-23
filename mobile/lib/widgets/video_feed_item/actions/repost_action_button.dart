// ABOUTME: Repost action button for video feed overlay.
// ABOUTME: Displays repost icon with count, handles toggle repost action.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/video_interactions/video_interactions_bloc.dart';
import 'package:openvine/widgets/video_feed_item/actions/video_action_button.dart';

/// Repost action button with count display for video overlay.
///
/// Shows a repost icon that toggles the repost state.
/// Uses [VideoInteractionsBloc] for state management.
///
/// Requires [VideoInteractionsBloc] to be provided in the widget tree.
class RepostActionButton extends StatelessWidget {
  const RepostActionButton({
    required this.video,
    super.key,
    this.isPreviewMode = false,
  });

  final VideoEvent video;
  final bool isPreviewMode;

  @override
  Widget build(BuildContext context) {
    if (isPreviewMode) return const _ActionButton();

    return BlocBuilder<VideoInteractionsBloc, VideoInteractionsState>(
      builder: (context, state) {
        final isReposted = state.isReposted;
        final nostrReposts =
            state.repostCount ?? (video.reposterPubkeys?.length ?? 0);
        final totalReposts = nostrReposts + (video.originalReposts ?? 0);

        return _ActionButton(
          isReposted: isReposted,
          isRepostInProgress: state.isRepostInProgress,
          totalReposts: totalReposts,
        );
      },
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    this.isReposted = false,
    this.isRepostInProgress = false,
    this.totalReposts = 1,
  });

  final bool isReposted;
  final bool isRepostInProgress;
  final int totalReposts;

  @override
  Widget build(BuildContext context) {
    return VideoActionButton(
      iconAsset: 'assets/icon/content-controls/repost.svg',
      semanticIdentifier: 'repost_button',
      semanticLabel: isReposted ? 'Remove repost' : 'Repost video',
      iconColor: isReposted ? VineTheme.vineGreen : VineTheme.whiteText,
      isLoading: isRepostInProgress,
      count: totalReposts,
      onPressed: () {
        context.read<VideoInteractionsBloc>().add(
          const VideoInteractionsRepostToggled(),
        );
      },
    );
  }
}
