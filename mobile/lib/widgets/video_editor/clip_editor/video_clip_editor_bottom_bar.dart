// ABOUTME: Bottom bar with playback controls and time display
// ABOUTME: Play/pause, mute, and options buttons with formatted duration

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/blocs/video_editor/clip_editor/clip_editor_bloc.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/services/video_editor/video_editor_split_service.dart';
import 'package:openvine/widgets/video_editor/clip_editor/video_clip_editor_more_button.dart';
import 'package:openvine/widgets/video_editor/clip_editor/video_time_display.dart';
import 'package:openvine/widgets/video_editor_icon_button.dart';

/// Bottom bar with playback controls and time display.
class VideoClipEditorBottomBar extends StatelessWidget {
  /// Creates a video editor bottom bar widget.
  const VideoClipEditorBottomBar({super.key});

  void _showSnackBar({required BuildContext context, required String message}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        padding: EdgeInsets.zero,
        backgroundColor: VineTheme.transparent,
        elevation: 0,
        behavior: .floating,
        duration: const Duration(seconds: 3),
        content: DivineSnackbarContainer(label: message),
      ),
    );
  }

  void _handleSplitClip(BuildContext context) {
    final clipEditorState = context.read<ClipEditorBloc>().state;
    final splitPosition = clipEditorState.splitPosition;
    final currentClipIndex = clipEditorState.currentClipIndex;

    final clips = clipEditorState.clips;
    if (currentClipIndex >= clips.length) {
      return;
    }

    final selectedClip = clips[currentClipIndex];

    // Check if clip is currently processing
    if (selectedClip.isProcessing) {
      _showSnackBar(
        context: context,
        message: context.l10n.videoEditorCannotSplitProcessing,
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
        message: context.l10n.videoEditorSplitPositionInvalid(
          minDuration.inMilliseconds,
        ),
      );
      return;
    }

    // Proceed with split
    context.read<ClipEditorBloc>().add(const ClipEditorSplitRequested());
  }

  @override
  Widget build(BuildContext context) {
    final (
      :isReordering,
      :isPlaying,
      :isEditing,
      :currentClipIndex,
    ) = context
        .select<
          ClipEditorBloc,
          ({
            bool isReordering,
            bool isPlaying,
            bool isEditing,
            int currentClipIndex,
          })
        >(
          (bloc) => (
            isReordering: bloc.state.isReordering,
            isPlaying: bloc.state.isPlaying,
            isEditing: bloc.state.isEditing,
            currentClipIndex: bloc.state.currentClipIndex,
          ),
        );

    return Container(
      height: 80,
      padding: const .symmetric(horizontal: 16, vertical: 16),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: isReordering
            ? const _ClipRemoveArea()
            : Row(
                mainAxisAlignment: .spaceBetween,
                children: [
                  // Control buttons
                  Row(
                    spacing: 16,
                    children: [
                      VideoEditorIconButton(
                        backgroundColor: VineTheme.transparent,
                        icon: isPlaying ? .pause : .play,
                        onTap: () => context.read<ClipEditorBloc>().add(
                          const ClipEditorPlayPauseToggled(),
                        ),
                        semanticLabel:
                            context.l10n.videoEditorPlayPauseSemanticLabel,
                      ),
                      if (isEditing)
                        VideoEditorIconButton(
                          backgroundColor: VineTheme.transparent,
                          icon: .scissors,
                          onTap: () => _handleSplitClip(context),
                          semanticLabel:
                              context.l10n.videoEditorCropSemanticLabel,
                        ),
                      const VideoClipEditorMoreButton(),
                    ],
                  ),

                  // Time display
                  BlocSelector<
                    ClipEditorBloc,
                    ClipEditorState,
                    ({Duration totalDuration, List<DivineVideoClip> clips})
                  >(
                    selector: (state) => (
                      totalDuration: state.totalDuration,
                      clips: state.clips,
                    ),
                    builder: (context, data) {
                      Duration totalDuration;
                      Duration maxDuration;

                      if (isEditing) {
                        if (currentClipIndex >= data.clips.length) {
                          assert(
                            false,
                            'Clip index $currentClipIndex is out of bounds. '
                            'Total clips: ${data.clips.length}',
                          );
                          totalDuration = Duration.zero;
                          maxDuration = Duration.zero;
                        } else {
                          totalDuration = data.clips[currentClipIndex].duration;
                          maxDuration = totalDuration;
                        }
                      } else {
                        totalDuration = data.totalDuration;
                        // Clamp interpolation to the end of the current clip
                        // so the display never overshoots into the next clip's
                        // time range.
                        maxDuration = data.clips
                            .take(
                              (currentClipIndex + 1).clamp(
                                0,
                                data.clips.length,
                              ),
                            )
                            .fold(
                              Duration.zero,
                              (sum, clip) => sum + clip.duration,
                            );
                      }

                      final maxMs =
                          VideoEditorConstants.maxDuration.inMilliseconds;

                      return VideoTimeDisplay(
                        key: ValueKey(
                          'Video-Editor-Time-Display-$isEditing',
                        ),
                        isPlayingSelector: (s) => s.isPlaying && !s.isEditing,
                        currentPositionSelector: isEditing
                            ? (s) => s.splitPosition
                            : (s) => s.currentPosition,
                        totalDuration: Duration(
                          milliseconds: totalDuration.inMilliseconds.clamp(
                            0,
                            maxMs,
                          ),
                        ),
                        maxDuration: Duration(
                          milliseconds: maxDuration.inMilliseconds.clamp(
                            0,
                            maxMs,
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
    final (:isOverDeleteZone, :isLastClip) = context
        .select<ClipEditorBloc, ({bool isOverDeleteZone, bool isLastClip})>(
          (bloc) => (
            isOverDeleteZone: bloc.state.isOverDeleteZone,
            isLastClip: bloc.state.clips.length <= 1,
          ),
        );
    return Align(
      child: AnimatedScale(
        scale: isOverDeleteZone && !isLastClip ? 1.4 : 1.0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        child: AnimatedOpacity(
          opacity: isLastClip ? 0.3 : 1.0,
          duration: const Duration(milliseconds: 200),
          child: Container(
            key: deleteButtonKey,
            padding: const .all(10),
            decoration: ShapeDecoration(
              color: VineTheme.error,
              shape: RoundedRectangleBorder(borderRadius: .circular(20)),
            ),
            child: const DivineIcon(
              icon: .trash,
              size: 28,
              color: VineTheme.backgroundColor,
            ),
          ),
        ),
      ),
    );
  }
}
