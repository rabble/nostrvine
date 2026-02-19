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
    final result = await VineBottomSheet.show<AudioEvent>(
      context: context,
      maxChildSize: 1,
      initialChildSize: 1,
      minChildSize: 0.8,
      buildScrollBody: (scrollController) =>
          AudioSelectionBottomSheet(scrollController: scrollController),
    );

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
                        backgroundColor: Color(0x26000000),
                        // TODO(l10n): Replace with context.l10n when localization is added.
                        semanticLabel: 'Close video recorder',
                        iconPath: 'assets/icon/close.svg',
                        onTap: () => notifier.closeVideoRecorder(context),
                      ),

                      Flexible(
                        child: VideoEditorAudioChip(
                          onTap: () => _selectAudio(context, ref),
                        ),
                      ),

                      // Next button
                      if (hasClips)
                        _NextButton(
                          onTap: () => notifier.openVideoEditor(context),
                        ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}

class _NextButton extends StatelessWidget {
  const _NextButton({this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      // TODO(l10n): Replace with context.l10n when localization is added.
      label: 'Continue to video editor',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const .symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: .circular(16),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1A000000),
                offset: Offset(1, 1),
                blurRadius: 1,
              ),
              BoxShadow(
                color: Color(0x1A000000),
                offset: Offset(0.4, 0.4),
                blurRadius: 0.6,
              ),
            ],
          ),
          child: const Text(
            // TODO(l10n): Replace with context.l10n when localization is added.
            'Next',
            style: TextStyle(
              fontFamily: 'BricolageGrotesque',
              fontSize: 18,
              fontWeight: .w800,
              height: 1.33,
              letterSpacing: 0.15,
              color: Color(0xFF00452D),
            ),
          ),
        ),
      ),
    );
  }
}
