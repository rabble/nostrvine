import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/providers/video_recorder_provider.dart';

class VideoRecorderClassicTopBar extends ConsumerWidget {
  const VideoRecorderClassicTopBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(videoRecorderProvider.notifier);
    final isRecording = ref.watch(
      videoRecorderProvider.select((p) => p.isRecording),
    );
    final hasClips = ref.watch(
      clipManagerProvider.select((p) => p.hasClips),
    );

    return Stack(
      children: [
        const Positioned.fill(child: _ProgressBar()),

        Padding(
          padding: const .all(16),
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 220),
            opacity: isRecording ? 0 : 1,
            child: Row(
              mainAxisAlignment: .spaceBetween,
              children: [
                DivineIconButton(
                  icon: .x,
                  semanticLabel: context.l10n.videoRecorderCaptureCloseLabel,
                  size: .small,
                  type: .ghostSecondary,
                  onPressed: isRecording
                      ? null
                      : () => notifier.closeVideoRecorder(context),
                ),
                DivineIconButton(
                  icon: .caretRight,
                  semanticLabel: context.l10n.videoRecorderCaptureNextLabel,
                  size: .small,
                  type: .ghostSecondary,
                  onPressed: isRecording || !hasClips
                      ? null
                      : () => notifier.openVideoEditor(context),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ProgressBar extends ConsumerWidget {
  const _ProgressBar();

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

    return RepaintBoundary(
      child: Row(
        crossAxisAlignment: .stretch,
        children: [
          if (primaryMs > 0)
            Flexible(
              flex: primaryMs,
              child: Container(color: VineTheme.primary),
            ),
          if (remainingMs > 0)
            Flexible(
              flex: remainingMs,
              child: Container(color: VineTheme.neutral10),
            ),
        ],
      ),
    );
  }
}
