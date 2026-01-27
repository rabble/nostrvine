// ABOUTME: Repost action button for video feed overlay.
// ABOUTME: Displays repost icon with count, handles toggle repost action.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:models/models.dart' hide LogCategory;
import 'package:openvine/blocs/video_interactions/video_interactions_bloc.dart';
import 'package:openvine/utils/string_utils.dart';
import 'package:openvine/utils/unified_logger.dart';

/// Repost action button with count display for video overlay.
///
/// Shows a repost icon that toggles the repost state.
/// Uses [VideoInteractionsBloc] for state management.
///
/// Requires [VideoInteractionsBloc] to be provided in the widget tree.
/// Shows a disabled state when the bloc is not available.
class RepostActionButton extends StatelessWidget {
  const RepostActionButton({required this.video, super.key});

  final VideoEvent video;

  @override
  Widget build(BuildContext context) {
    final interactionsBloc = context.read<VideoInteractionsBloc?>();

    if (interactionsBloc == null) {
      // No bloc available - show disabled state with original reposts only
      return _RepostButton(
        isReposted: false,
        isRepostInProgress: false,
        totalReposts: _calculateTotalReposts(repostCount: null),
        onPressed: null,
      );
    }

    return BlocBuilder<VideoInteractionsBloc, VideoInteractionsState>(
      builder: (context, state) {
        final isReposted = state.isReposted;
        final isRepostInProgress = state.isRepostInProgress;
        final totalReposts = _calculateTotalReposts(
          repostCount: state.repostCount,
        );

        return _RepostButton(
          isReposted: isReposted,
          isRepostInProgress: isRepostInProgress,
          totalReposts: totalReposts,
          onPressed: () {
            Log.info(
              '🔁 Repost button tapped for ${video.id}',
              name: 'RepostActionButton',
              category: LogCategory.ui,
            );
            context.read<VideoInteractionsBloc>().add(
              const VideoInteractionsRepostToggled(),
            );
          },
        );
      },
    );
  }

  /// Calculate total reposts combining bloc count and original reposts.
  int _calculateTotalReposts({required int? repostCount}) {
    final nostrReposts = repostCount ?? (video.reposterPubkeys?.length ?? 0);
    final originalReposts = video.originalReposts ?? 0;
    return nostrReposts + originalReposts;
  }
}

class _RepostButton extends StatelessWidget {
  const _RepostButton({
    required this.isReposted,
    required this.isRepostInProgress,
    required this.totalReposts,
    this.onPressed,
  });

  final bool isReposted;
  final bool isRepostInProgress;
  final int totalReposts;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          identifier: 'repost_button',
          container: true,
          explicitChildNodes: true,
          button: true,
          label: isReposted ? 'Remove repost' : 'Repost video',
          child: IconButton(
            padding: const EdgeInsets.all(8),
            constraints: const BoxConstraints.tightFor(width: 48, height: 48),
            style: IconButton.styleFrom(
              highlightColor: Colors.transparent,
              splashFactory: NoSplash.splashFactory,
            ),
            onPressed: isRepostInProgress || onPressed == null
                ? null
                : onPressed,
            icon: isRepostInProgress
                ? const SizedBox(
                    width: 32,
                    height: 32,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : DecoratedBox(
                    decoration: BoxDecoration(
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 15,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: SvgPicture.asset(
                      'assets/icon/content-controls/repost.svg',
                      width: 32,
                      height: 32,
                      colorFilter: ColorFilter.mode(
                        isReposted ? VineTheme.vineGreen : Colors.white,
                        BlendMode.srcIn,
                      ),
                    ),
                  ),
          ),
        ),
        // Show repost count: Nostr reposts + original reposts (if any)
        if (totalReposts > 0)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              StringUtils.formatCompactNumber(totalReposts),
              style: const TextStyle(
                fontFamily: 'Bricolage Grotesque',
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                height: 1,
                letterSpacing: 0.5,
              ),
            ),
          ),
      ],
    );
  }
}
