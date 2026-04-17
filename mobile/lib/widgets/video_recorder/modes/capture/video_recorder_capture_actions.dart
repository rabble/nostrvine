import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/providers/video_recorder_provider.dart';

class VideoRecorderCaptureActions extends ConsumerWidget {
  const VideoRecorderCaptureActions({super.key});

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
      top: false,
      left: false,
      bottom: false,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 220),
        opacity: state.isRecording ? 0 : 1,
        child: Container(
          margin: const .symmetric(horizontal: 16),
          padding: const .symmetric(vertical: 12, horizontal: 4),
          decoration: ShapeDecoration(
            color: VineTheme.scrim35,
            shape: RoundedRectangleBorder(borderRadius: .circular(20)),
          ),
          child: Column(
            mainAxisSize: .min,
            spacing: 8,
            children: [
              _IconButton(
                icon: state.flashMode.icon,
                label: context.l10n.videoRecorderToggleFlashLabel,
                onTap: state.hasFlash ? notifier.toggleFlash : null,
              ),
              _IconButton(
                icon: state.timer.icon,
                label: context.l10n.videoRecorderCycleTimerLabel,
                onTap: notifier.cycleTimer,
              ),
              _IconButton(
                icon: state.aspectRatio == .square
                    ? .cropSquare
                    : .cropPortrait,
                label: context.l10n.videoRecorderToggleAspectRatioLabel,
                onTap: !hasClips ? notifier.toggleAspectRatio : null,
              ),
              _IconButton(
                icon: .arrowsClockwise,
                label: context.l10n.videoRecorderSwitchCameraLabel,
                onTap: state.canSwitchCamera ? notifier.switchCamera : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IconButton extends StatelessWidget {
  const _IconButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final String label;
  final DivineIconName icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const .all(8),
          child: DivineIcon(
            icon: icon,
            color: VineTheme.whiteText.withAlpha(onTap != null ? 255 : 100),
          ),
        ),
      ),
    );
  }
}
