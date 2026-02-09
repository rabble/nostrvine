// ABOUTME: Bottom bar with playback controls and time display
// ABOUTME: Play/pause, mute, and options buttons with formatted duration

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/svg.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/services/video_editor/video_editor_split_service.dart';
import 'package:openvine/widgets/video_editor_icon_button.dart';
import 'package:openvine/widgets/video_clip_editor/video_clip_editor_more_button.dart';
import 'package:openvine/widgets/video_clip_editor/video_time_display.dart';

/// Bottom bar with playback controls and time display.
class VideoClipEditorBottomBar extends ConsumerWidget {
  /// Creates a video editor bottom bar widget.
  const VideoClipEditorBottomBar({super.key});

  void _showSnackBar({required BuildContext context, required String message}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        padding: EdgeInsets.zero,
        backgroundColor: Colors.transparent,
        elevation: 0,
        behavior: .floating,
        duration: Duration(seconds: 3),
        content: DivineSnackbarContainer(label: message),
      ),
    );
  }

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
      _showSnackBar(
        context: context,
        message:
            // TODO(l10n): Replace with context.l10n when localization is added.
            'Cannot split clip while it is being processed. Please wait.',
      );
      return;
    }

    // Validate split position
    if (!VideoEditorSplitService.isValidSplitPosition(
      selectedClip,
      splitPosition,
    )) {
      const minDuration = VideoEditorSplitService.minClipDuration;
      _showSnackBar(
        context: context,
        message:
            // TODO(l10n): Replace with context.l10n when localization is added.
            'Split position invalid. Both clips must be at least '
            '${minDuration.inMilliseconds}ms long.',
      );
      return;
    }

    // Proceed with split
    await ref.read(videoEditorProvider.notifier).splitSelectedClip();
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
                      VideoEditorIconButton(
                        backgroundColor: const Color(0x00000000),
                        iconPath: state.isPlaying
                            ? 'assets/icon/pause.svg'
                            : 'assets/icon/play.svg',
                        onTap: notifier.togglePlayPause,
                        // TODO(l10n): Replace with context.l10n when localization is added.
                        semanticLabel: 'Play or pause video',
                      ),
                      if (state.isEditing)
                        VideoEditorIconButton(
                          backgroundColor: const Color(0x00000000),
                          iconPath: 'assets/icon/trim.svg',
                          onTap: () => _handleSplitClip(context, ref),
                          // TODO(l10n): Replace with context.l10n when localization is added.
                          semanticLabel: 'Crop',
                        ),
                      const VideoClipEditorMoreButton(),
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
                        totalDuration: Duration(
                          milliseconds: totalDuration.inMilliseconds.clamp(
                            0,
                            VideoEditorConstants.maxDuration.inMilliseconds,
                          ),
                        ),
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
    final isOverDeleteZone = ref.watch(
      videoEditorProvider.select((s) => s.isOverDeleteZone),
    );
    return Align(
      child: AnimatedScale(
        scale: isOverDeleteZone ? 1.4 : 1.0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
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
      ),
    );
  }
}
