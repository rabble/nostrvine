// ABOUTME: Top bar widget for video recorder screen
// ABOUTME: Contains close button, segment-bar, and forward button

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/providers/video_recorder_provider.dart';
import 'package:openvine/widgets/video_editor/audio_editor/video_editor_audio_chip.dart';

/// Top bar with close button, segment bar, and forward button.
class VideoRecorderTopBar extends ConsumerStatefulWidget {
  /// Creates a video recorder top bar widget.
  const VideoRecorderTopBar({super.key});

  @override
  ConsumerState<VideoRecorderTopBar> createState() =>
      _VideoRecorderTopBarState();
}

class _VideoRecorderTopBarState extends ConsumerState<VideoRecorderTopBar> {
  bool _isSelectingSound = false;

  @override
  Widget build(BuildContext context) {
    final notifier = ref.read(videoRecorderProvider.notifier);
    final (isRecording, selectedSound) = ref.watch(
      videoRecorderProvider.select((s) => (s.isRecording, s.selectedSound)),
    );
    final clipCount = ref.watch(clipManagerProvider.select((s) => s.clipCount));
    final hasClips = clipCount > 0;

    return Align(
      alignment: .topCenter,
      child: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: isRecording
              ? const SizedBox.shrink()
              : Padding(
                  padding: const .fromLTRB(16, 40, 16, 0),
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 200),
                    opacity: _isSelectingSound ? 0 : 1,
                    child: Row(
                      spacing: 16,
                      mainAxisAlignment: .spaceBetween,
                      children: [
                        // Close button
                        DivineIconButton(
                          // TODO(l10n): Replace with context.l10n when localization is added.
                          semanticLabel: 'Close video recorder',
                          type: .ghostSecondary,
                          size: .small,
                          icon: .x,
                          onPressed: () => notifier.closeVideoRecorder(context),
                        ),

                        Flexible(
                          child: VideoEditorAudioChip(
                            selectedSound: selectedSound,
                            onSoundChanged: notifier.selectSound,
                            onSelectionStarted: () {
                              setState(() => _isSelectingSound = true);
                              notifier.pauseRemoteRecordControl();
                            },
                            onSelectionEnded: () {
                              setState(() => _isSelectingSound = false);
                              notifier.resumeRemoteRecordControl();
                            },
                          ),
                        ),

                        // Next button
                        AnimatedOpacity(
                          duration: const Duration(milliseconds: 200),
                          opacity: hasClips ? 1 : 0.32,
                          child: DivineIconButton(
                            // TODO(l10n): Replace with context.l10n when localization is added.
                            semanticLabel: 'Continue to video editor',
                            type: .tertiary,
                            size: .small,
                            icon: .check,
                            onPressed: hasClips
                                ? () => notifier.openVideoEditor(context)
                                : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}
