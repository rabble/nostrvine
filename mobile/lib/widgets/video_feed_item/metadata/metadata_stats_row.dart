// ABOUTME: Stats row for the metadata expanded sheet.
// ABOUTME: Shows Loops, Likes, Comments, Reposts with vertical dividers.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/video_interactions/video_interactions_bloc.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/utils/string_utils.dart';

/// Horizontal stats row displaying engagement counts for a video.
///
/// Reads live counts from [VideoInteractionsBloc] (likes, comments, reposts)
/// and static loops from [VideoEvent.originalLoops].
///
/// Layout matches Figma node `I11251:226991;9113:176278`:
/// four stat columns separated by vertical dividers.
class MetadataStatsRow extends StatelessWidget {
  const MetadataStatsRow({required this.video, super.key});

  final VideoEvent video;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<VideoInteractionsBloc, VideoInteractionsState>(
      builder: (context, state) {
        final isLoading = state.isLoading;

        return DecoratedBox(
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: VineTheme.outlineDisabled),
            ),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                // Top padding shrinks to 4 px so the gap between the
                // overview section's bottom (20 px padding) and the
                // first stat row totals 24 px, matching Figma node
                // 15675:27356's inter-group spacing.
                padding: const EdgeInsets.only(
                  left: 24,
                  right: 24,
                  top: 4,
                  bottom: 16,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minWidth: constraints.maxWidth - 48,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _StatColumn(
                        count: video.totalLoops,
                        label: context.l10n.metadataLoopsLabel(
                          video.totalLoops,
                        ),
                        isLoading: false,
                      ),
                      const _VerticalDivider(),
                      _StatColumn(
                        count: state.likeCount,
                        label: context.l10n.metadataLikesLabel,
                        isLoading: isLoading,
                      ),
                      const _VerticalDivider(),
                      _StatColumn(
                        count: state.commentCount,
                        label: context.l10n.metadataCommentsLabel,
                        isLoading: isLoading,
                      ),
                      const _VerticalDivider(),
                      _StatColumn(
                        count: state.repostCount,
                        label: context.l10n.metadataRepostsLabel,
                        isLoading: isLoading,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _StatColumn extends StatelessWidget {
  const _StatColumn({
    required this.count,
    required this.label,
    required this.isLoading,
  });

  final int? count;
  final String label;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final displayValue = isLoading
        ? '—'
        : count != null
        ? StringUtils.formatCompactNumber(count!)
        : '0';

    return Column(
      children: [
        Text(
          displayValue,
          style: VineTheme.statNumberFont(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          label,
          style: VineTheme.labelSmallFont(color: VineTheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _VerticalDivider extends StatelessWidget {
  const _VerticalDivider();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 40,
      child: VerticalDivider(
        width: 2,
        thickness: 2,
        color: VineTheme.outlineMuted,
      ),
    );
  }
}
