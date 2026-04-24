import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/providers/video_recorder_provider.dart';
import 'package:openvine/utils/video_editor_utils.dart';

/// Top bar for capture mode with close and confirm buttons.
class VideoRecorderCaptureTopBar extends ConsumerWidget {
  const VideoRecorderCaptureTopBar({required this.fromEditor, super.key});

  static const _animationDuration = Duration(milliseconds: 220);

  /// Whether the recorder was opened from the video editor.
  final bool fromEditor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(videoRecorderProvider.notifier);
    final state = ref.watch(
      videoRecorderProvider.select(
        (p) => (
          flashMode: p.flashMode,
          timer: p.timerDuration,
          aspectRatio: p.aspectRatio,
          canSwitchCamera: p.canSwitchCamera,
          hasFlash: p.hasFlash,
          isRecording: p.isRecording,
        ),
      ),
    );
    final hasClips = ref.watch(clipManagerProvider.select((p) => p.hasClips));

    return SafeArea(
      left: false,
      child: AnimatedSwitcher(
        duration: _animationDuration,
        child: state.isRecording
            ? const _RecordingProgressBar()
            : Padding(
                padding: const EdgeInsetsGeometry.fromLTRB(12, 12, 12, 0),
                child: Row(
                  spacing: 12,
                  mainAxisAlignment: .spaceBetween,
                  children: [
                    DivineIconButton(
                      icon: .x,
                      semanticLabel:
                          context.l10n.videoRecorderCaptureCloseLabel,
                      size: .small,
                      type: .ghostSecondary,
                      onPressed: () => fromEditor
                          ? context.pop(false)
                          : notifier.closeVideoRecorder(context),
                    ),
                    AnimatedOpacity(
                      duration: _animationDuration,
                      opacity: hasClips ? 1 : 0,
                      child: DivineIconButton(
                        icon: .caretRight,
                        semanticLabel:
                            context.l10n.videoRecorderCaptureNextLabel,
                        size: .small,
                        type: .ghostSecondary,
                        onPressed: () => fromEditor
                            ? context.pop(true)
                            : notifier.openVideoEditor(context),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _RecordingProgressBar extends ConsumerWidget {
  const _RecordingProgressBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (:totalDuration, :activeDuration) = ref.watch(
      clipManagerProvider.select(
        (s) => (
          totalDuration: s.totalDuration,
          activeDuration: s.activeRecordingDuration,
        ),
      ),
    );

    final maxMs = VideoEditorConstants.maxDuration.inMilliseconds;
    final currentMs = (totalDuration + activeDuration).inMilliseconds;
    // Under max: primary fills up, remaining (disabled bg) shrinks.
    // Over max: primary is capped at maxDuration, primaryContainer grows
    // from the right → primary appears to shrink back relatively.
    final primaryMs = currentMs.clamp(0, maxMs);
    final remainingMs = (maxMs - currentMs).clamp(0, maxMs);
    final overflowMs = (currentMs - maxMs).clamp(0, currentMs);

    return RepaintBoundary(
      child: Padding(
        padding: const .fromLTRB(18, 16, 18, 0),
        child: Column(
          spacing: 14,
          children: [
            Container(
              height: 4,
              decoration: BoxDecoration(
                borderRadius: .circular(2),
                color: VineTheme.onSurfaceDisabled,
              ),
              clipBehavior: .antiAlias,
              child: Row(
                children: [
                  if (primaryMs > 0)
                    Flexible(
                      flex: primaryMs,
                      child: Container(color: VineTheme.primary),
                    ),
                  if (remainingMs > 0)
                    Flexible(
                      flex: remainingMs,
                      child: Container(color: VineTheme.onSurfaceDisabled),
                    ),
                  if (overflowMs > 0)
                    Flexible(
                      flex: overflowMs,
                      child: Container(color: VineTheme.primaryContainer),
                    ),
                ],
              ),
            ),
            Text(
              (totalDuration + activeDuration).toMmSs(),
              style: VineTheme.titleSmallFont(),
            ),
          ],
        ),
      ),
    );
  }
}
