// ABOUTME: Bottom bar with playback controls and time display
// ABOUTME: Play/pause, mute, and options buttons with formatted duration

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/svg.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/services/video_editor/video_editor_split_service.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:openvine/widgets/divine_icon_button.dart';
import 'package:openvine/widgets/video_editor/sheets/video_editor_clip_edit_more_sheet.dart';
import 'package:openvine/widgets/video_editor/sheets/video_editor_overview_more_sheet.dart';
import 'package:openvine/widgets/video_editor/video_time_display.dart';

/// Bottom bar with playback controls and time display.
class VideoEditorBottomBar extends ConsumerWidget {
  /// Creates a video editor bottom bar widget.
  const VideoEditorBottomBar({super.key});

  Future<void> _handleSplitClip(BuildContext context, WidgetRef ref) async {
    final splitPosition = ref.read(videoEditorProvider).splitPosition;
    final currentClipIndex = ref.read(videoEditorProvider).currentClipIndex;

    final clips = ref.read(clipManagerProvider).clips;
    if (currentClipIndex >= clips.length) {
      return;
    }

    final selectedClip = clips[currentClipIndex];

    // Check if clip is currently processing
    if (selectedClip.isProcessing) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            // TODO(l10n): Replace with context.l10n when localization is added.
            'Cannot split clip while it is being processed. Please wait.',
          ),
          duration: Duration(seconds: 2),
          behavior: .floating,
        ),
      );
      return;
    }

    // Validate split position
    if (!VideoEditorSplitService.isValidSplitPosition(
      selectedClip,
      splitPosition,
    )) {
      const minDuration = VideoEditorSplitService.minClipDuration;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            // TODO(l10n): Replace with context.l10n when localization is added.
            'Split position invalid. Both clips must be at least '
            '${minDuration.inMilliseconds}ms long.',
          ),
          duration: const Duration(seconds: 2),
          behavior: .floating,
        ),
      );
      return;
    }

    // Proceed with split
    await ref.read(videoEditorProvider.notifier).splitSelectedClip();
  }

  /// Show the more options bottom sheet.
  ///
  /// Displays additional editor options like save to drafts, clip library, etc.
  Future<void> _showMoreOptions(BuildContext context, WidgetRef ref) async {
    Log.debug(
      '⚙️ Showing more options sheet',
      name: 'VideoEditorNotifier',
      category: .video,
    );
    final isEditing = ref.read(videoEditorProvider).isEditing;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: VineTheme.surfaceBackground,
      builder: (context) => isEditing
          ? const VideoEditorClipEditMoreSheet()
          : const VideoEditorOverviewMoreSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(
      videoEditorProvider.select(
        (state) => (
          isPlaying: state.isPlaying,
          isEditing: state.isEditing,
          isReordering: state.isReordering,
          isMuted: state.isMuted,
          currentClipIndex: state.currentClipIndex,
          splitPosition: state.splitPosition,
        ),
      ),
    );
    final notifier = ref.read(videoEditorProvider.notifier);

    return Container(
      height: 80,
      padding: const .symmetric(horizontal: 16, vertical: 16),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: state.isReordering
            ? const _ClipRemoveArea()
            : Row(
                mainAxisAlignment: .spaceBetween,
                children: [
                  // Control buttons
                  Row(
                    spacing: 16,
                    children: [
                      DivineIconButton(
                        backgroundColor: const Color(0x00000000),
                        iconPath: state.isPlaying
                            ? 'assets/icon/pause.svg'
                            : 'assets/icon/play.svg',
                        onTap: notifier.togglePlayPause,
                        // TODO(l10n): Replace with context.l10n when localization is added.
                        semanticLabel: 'Play or pause video',
                      ),
                      if (state.isEditing)
                        DivineIconButton(
                          backgroundColor: const Color(0x00000000),
                          iconPath: 'assets/icon/trim.svg',
                          onTap: () => _handleSplitClip(context, ref),
                          // TODO(l10n): Replace with context.l10n when localization is added.
                          semanticLabel: 'Crop',
                        ),
                      DivineIconButton(
                        backgroundColor: const Color(0x00000000),
                        iconPath: 'assets/icon/more_horiz.svg',
                        onTap: () => _showMoreOptions(context, ref),
                        // TODO(l10n): Replace with context.l10n when localization is added.
                        semanticLabel: 'More options',
                      ),
                    ],
                  ),

                  // Time display
                  Consumer(
                    builder: (_, ref, _) {
                      Duration totalDuration = .zero;

                      if (state.isEditing) {
                        totalDuration = ref.watch(
                          clipManagerProvider.select((p) {
                            final clipIndex = state.currentClipIndex;

                            if (clipIndex >= p.clips.length) {
                              assert(
                                false,
                                'Clip index $clipIndex is out of bounds. '
                                'Total clips: ${p.clips.length}',
                              );
                              return Duration.zero;
                            }

                            return p.clips[clipIndex].duration;
                          }),
                        );
                      } else {
                        totalDuration = ref.watch(
                          clipManagerProvider.select(
                            (state) => state.totalDuration,
                          ),
                        );
                      }

                      return VideoTimeDisplay(
                        key: ValueKey(
                          'Video-Editor-Time-Display-${state.isEditing}',
                        ),
                        isPlayingSelector: videoEditorProvider.select(
                          (s) => s.isPlaying && !s.isEditing,
                        ),
                        currentPositionSelector: state.isEditing
                            ? videoEditorProvider.select((s) => s.splitPosition)
                            : videoEditorProvider.select(
                                (s) => s.currentPosition,
                              ),
                        totalDuration: totalDuration,
                      );
                    },
                  ),
                ],
              ),
      ),
    );
  }
}

class _ClipRemoveArea extends ConsumerWidget {
  const _ClipRemoveArea();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deleteButtonKey = ref.read(videoEditorProvider).deleteButtonKey;
    return Align(
      child: Container(
        key: deleteButtonKey,
        padding: const .all(10),
        decoration: ShapeDecoration(
          color: const Color(0xFFF44336),
          shape: RoundedRectangleBorder(borderRadius: .circular(20)),
        ),
        child: SizedBox(
          height: 28,
          width: 28,
          child: SvgPicture.asset(
            'assets/icon/delete.svg',
            colorFilter: const .mode(Color(0xFF000000), .srcIn),
          ),
        ),
      ),
    );
  }
}
