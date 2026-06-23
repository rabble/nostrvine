import 'package:divine_camera/divine_camera.dart'
    show DivineVideoStabilizationMode;
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/blocs/video_recorder/video_recorder_bloc.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/clip_manager_provider.dart';

class VideoRecorderCaptureActions extends ConsumerWidget {
  const VideoRecorderCaptureActions({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = context.select(
      (VideoRecorderBloc b) => (
        flashMode: b.state.flashMode,
        timer: b.state.timerDuration,
        aspectRatio: b.state.aspectRatio,
        canSwitchCamera: b.state.canSwitchCamera,
        hasFlash: b.state.hasFlash,
        isRecording: b.state.isRecording,
      ),
    );
    final hasClips = ref.watch(clipManagerProvider.select((p) => p.hasClips));

    return SafeArea(
      top: false,
      left: false,
      bottom: false,
      child: IgnorePointer(
        ignoring: state.isRecording,
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
                  onTap: state.hasFlash
                      ? () => context.read<VideoRecorderBloc>().add(
                          const VideoRecorderFlashToggled(),
                        )
                      : null,
                ),
                _IconButton(
                  icon: state.timer.icon,
                  label: context.l10n.videoRecorderCycleTimerLabel,
                  onTap: () => context.read<VideoRecorderBloc>().add(
                    const VideoRecorderTimerCycled(),
                  ),
                ),
                _IconButton(
                  icon: state.aspectRatio == .square
                      ? .cropSquare
                      : .cropPortrait,
                  label: context.l10n.videoRecorderToggleAspectRatioLabel,
                  onTap: !hasClips
                      ? () => context.read<VideoRecorderBloc>().add(
                          const VideoRecorderAspectRatioToggled(),
                        )
                      : null,
                ),
                _IconButton(
                  icon: .arrowsClockwise,
                  label: context.l10n.videoRecorderSwitchCameraLabel,
                  onTap: state.canSwitchCamera
                      ? () => context.read<VideoRecorderBloc>().add(
                          const VideoRecorderCameraSwitched(),
                        )
                      : null,
                ),
                const _StabilizationButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Opens a selection menu to change the video stabilization mode.
///
/// Disabled when the active camera reports no stabilization support
/// (e.g. front camera on some devices, macOS, Linux).
class _StabilizationButton extends StatelessWidget {
  const _StabilizationButton();

  @override
  Widget build(BuildContext context) {
    final isSupported = context.select(
      (VideoRecorderBloc b) => b.state.isVideoStabilizationSupported,
    );
    return _IconButton(
      icon: .sparkle,
      label: context.l10n.videoRecorderStabilizationLabel,
      onTap: isSupported ? () => _showStabilizationMenu(context) : null,
    );
  }

  Future<void> _showStabilizationMenu(BuildContext context) async {
    final l10n = context.l10n;
    final bloc = context.read<VideoRecorderBloc>();
    final state = bloc.state;

    final selected = await VineBottomSheetSelectionMenu.show(
      context: context,
      title: Text(
        l10n.videoRecorderStabilizationLabel,
        style: VineTheme.titleMediumFont(),
      ),
      selectedValue: state.videoStabilizationMode.toNativeString(),
      options: [
        for (final mode in state.availableVideoStabilizationModes)
          VineBottomSheetSelectionOptionData(
            label: _stabilizationModeLabel(l10n, mode),
            value: mode.toNativeString(),
          ),
      ],
    );

    if (selected == null) return;
    bloc.add(
      VideoRecorderStabilizationModeSet(
        DivineVideoStabilizationMode.fromNativeString(selected),
      ),
    );
  }
}

/// Maps a [DivineVideoStabilizationMode] to its localized label.
String _stabilizationModeLabel(
  AppLocalizations l10n,
  DivineVideoStabilizationMode mode,
) {
  return switch (mode) {
    .off => l10n.videoRecorderStabilizationModeOff,
    .standard => l10n.videoRecorderStabilizationModeStandard,
    .cinematic => l10n.videoRecorderStabilizationModeCinematic,
    .cinematicExtended => l10n.videoRecorderStabilizationModeCinematicExtended,
    .previewOptimized => l10n.videoRecorderStabilizationModePreviewOptimized,
    .lowLatency => l10n.videoRecorderStabilizationModeLowLatency,
    .auto => l10n.videoRecorderStabilizationModeAuto,
  };
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
