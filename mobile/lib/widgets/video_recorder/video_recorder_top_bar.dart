// ABOUTME: Top bar widget for video recorder screen
// ABOUTME: Contains close button, audio chip, and forward button using VideoEditorToolbar

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/providers/video_recorder_provider.dart';
import 'package:openvine/widgets/video_editor/audio_editor/video_editor_audio_chip.dart';
import 'package:openvine/widgets/video_editor/video_editor_toolbar.dart';

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
    final isRecording = ref.watch(
      videoRecorderProvider.select((s) => s.isRecording),
    );
    final selectedSound = ref.watch(
      videoEditorProvider.select((s) => s.selectedSound),
    );
    final clipCount = ref.watch(clipManagerProvider.select((s) => s.clipCount));
    final hasClips = clipCount > 0;

    return Align(
      alignment: .topCenter,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: isRecording
            ? const SizedBox.shrink()
            : AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: _isSelectingSound ? 0 : 1,
                child: VideoEditorToolbar(
                  padding: const EdgeInsets.fromLTRB(16, 40, 16, 0),
                  closeSemanticLabel: context.l10n.videoRecorderCloseLabel,
                  doneSemanticLabel:
                      context.l10n.videoRecorderContinueToEditorLabel,
                  doneIcon: DivineIconName.caretRight,
                  onClose: () => notifier.closeVideoRecorder(context),
                  onDone: hasClips
                      ? () => notifier.openVideoEditor(context)
                      : null,
                  center: Flexible(
                    child: VideoEditorAudioChip(
                      selectedSound: selectedSound,
                      onSoundChanged: (sound) {
                        ref.read(videoEditorProvider.notifier)
                          ..selectSound(sound)
                          // Lip-sync recording: mute original audio by default
                          // since the selected sound replaces it. The user can
                          // re-enable original audio later in the editor.
                          ..setOriginalAudioVolume(0);
                      },
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
                ),
              ),
      ),
    );
  }
}
