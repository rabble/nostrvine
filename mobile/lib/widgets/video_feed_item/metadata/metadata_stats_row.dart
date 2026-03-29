// ABOUTME: Stats row for the metadata expanded sheet.
// ABOUTME: Shows Loops, Likes, Comments, Reposts with vertical dividers.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/video_interactions/video_interactions_bloc.dart';
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
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
                        label: 'Loops',
                        isLoading: false,
                      ),
                      const _VerticalDivider(),
                      _StatColumn(
                        count: state.likeCount,
                        label: 'Likes',
                        isLoading: isLoading,
                      ),
                      const _VerticalDivider(),
                      _StatColumn(
                        count: state.commentCount,
                        label: 'Comments',
                        isLoading: isLoading,
                      ),
                      const _VerticalDivider(),
                      _StatColumn(
                        count: state.repostCount,
                        label: 'Reposts',
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
          // Figma spec: 20px/28px Bricolage Grotesque 800
          // titleLargeFont is 22/28 — adjust fontSize to match Figma.
          style: VineTheme.titleLargeFont().copyWith(fontSize: 20),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          label,
          style: VineTheme.bodySmallFont(
            color: VineTheme.onSurfaceVariant,
          ),
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
