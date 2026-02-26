// ABOUTME: Top bar widget for video recorder screen
// ABOUTME: Contains close button, segment-bar, and forward button

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/models/audio_event.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/providers/sounds_providers.dart';
import 'package:openvine/providers/video_recorder_provider.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:openvine/widgets/video_editor/audio_editor/audio_selection_bottom_sheet.dart';
import 'package:openvine/widgets/video_editor/audio_editor/video_editor_audio_chip.dart';
import 'package:openvine/widgets/video_editor_icon_button.dart';

/// Top bar with close button, segment bar, and forward button.
class VideoRecorderTopBar extends ConsumerWidget {
  /// Creates a video recorder top bar widget.
  const VideoRecorderTopBar({super.key});

  Future<void> _selectAudio(BuildContext context, WidgetRef ref) async {
    final videoRecorderNotifier = ref.read(videoRecorderProvider.notifier);
    videoRecorderNotifier.pauseRemoteRecordControl();

    final result = await VineBottomSheet.show<AudioEvent>(
      context: context,
      maxChildSize: 1,
      initialChildSize: 1,
      minChildSize: 0.8,
      buildScrollBody: (scrollController) =>
          AudioSelectionBottomSheet(scrollController: scrollController),
    );

    videoRecorderNotifier.resumeRemoteRecordControl();

    if (result != null) {
      ref.read(selectedSoundProvider.notifier).select(result);
      Log.info(
        'Sound selected: ${result.title ?? result.id}',
        name: 'VideoRecorderTopBar',
        category: LogCategory.ui,
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(videoRecorderProvider.notifier);
    final clipCount = ref.watch(clipManagerProvider.select((s) => s.clipCount));
    final hasClips = clipCount > 0;
    final isRecording = ref.watch(
      videoRecorderProvider.select((s) => s.isRecording),
    );

    // Debug logging for Next button visibility
    Log.debug(
      '🔝 TopBar build: hasClips=$hasClips, clipCount=$clipCount, '
      'isRecording=$isRecording',
      name: 'VideoRecorderTopBar',
      category: LogCategory.video,
    );

    return Align(
      alignment: .topCenter,
      child: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: isRecording
              ? const SizedBox.shrink()
              : Padding(
                  padding: const .fromLTRB(16, 40, 16, 0),
                  child: Row(
                    spacing: 16,
                    mainAxisAlignment: .spaceBetween,
                    children: [
                      // Close button
                      VideoEditorIconButton(
                        backgroundColor: const Color(0x26000000),
                        // TODO(l10n): Replace with context.l10n when localization is added.
                        semanticLabel: 'Close video recorder',
                        iconSize: 24,
                        icon: .x,
                        onTap: () => notifier.closeVideoRecorder(context),
                      ),

                      Flexible(
                        child: VideoEditorAudioChip(
                          onTap: () => _selectAudio(context, ref),
                        ),
                      ),

                      // Next button
                      Opacity(
                        opacity: hasClips ? 1 : 0.32,
                        child: VideoEditorIconButton(
                          backgroundColor: VineTheme.inverseSurface,
                          iconColor: VineTheme.inverseOnSurface,
                          // TODO(l10n): Replace with context.l10n when localization is added.
                          semanticLabel: 'Continue to video editor',
                          icon: .check,
                          iconSize: 24,
                          onTap: hasClips
                              ? () => notifier.openVideoEditor(context)
                              : null,
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}
