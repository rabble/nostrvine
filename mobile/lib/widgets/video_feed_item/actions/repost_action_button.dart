// ABOUTME: Repost action button for video feed overlay.
// ABOUTME: Displays repost icon with count, handles toggle repost action.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/video_interactions/video_interactions_bloc.dart';
import 'package:openvine/l10n/l10n.dart';
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
    this.onInteracted,
  });

  final VideoEvent video;
  final bool isPreviewMode;
  final VoidCallback? onInteracted;

  @override
  Widget build(BuildContext context) {
    if (isPreviewMode) return const _ActionButton();

    // Use relay count when available; fall back to video metadata.
    // Don't sum both — Funnelcake's originalReposts already includes
    // Nostr reposts, so adding them would double-count.
    return BlocSelector<
      VideoInteractionsBloc,
      VideoInteractionsState,
      ({bool isReposted, bool isInProgress, int count})
    >(
      selector: (state) => (
        isReposted: state.isReposted,
        isInProgress: state.isRepostInProgress,
        count:
            state.repostCount ??
            (video.reposterPubkeys?.length ?? 0) + (video.originalReposts ?? 0),
      ),
      builder: (context, data) {
        return _ActionButton(
          isReposted: data.isReposted,
          isRepostInProgress: data.isInProgress,
          totalReposts: data.count,
          onInteracted: onInteracted,
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
    this.onInteracted,
  });

  final bool isReposted;
  final bool isRepostInProgress;
  final int totalReposts;
  final VoidCallback? onInteracted;

  @override
  Widget build(BuildContext context) {
    return VideoActionButton(
      icon: .repeatDuo,
      semanticIdentifier: 'repost_button',
      semanticLabel: isReposted
          ? context.l10n.videoActionRemoveRepost
          : context.l10n.videoActionRepost,
      iconColor: isReposted ? VineTheme.vineGreen : VineTheme.whiteText,
      isLoading: isRepostInProgress,
      count: totalReposts,
      labelWhenZero: context.l10n.videoActionRepostLabel,
      onPressed: () {
        onInteracted?.call();
        context.read<VideoInteractionsBloc>().add(
          const VideoInteractionsRepostToggled(),
        );
      },
    );
  }
}
