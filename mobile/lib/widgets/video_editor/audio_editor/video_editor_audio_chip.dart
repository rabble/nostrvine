import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:models/models.dart' show AudioEvent;
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/screens/video_editor/video_audio_editor_timing_screen.dart';
import 'package:openvine/widgets/video_editor/audio_editor/audio_selection_bottom_sheet.dart';

/// Audio chip widget for selecting and displaying audio in video recording/editing.
///
/// This widget is provider-agnostic - it receives the current sound as input
/// and reports changes via callbacks. The parent widget is responsible for
/// updating the appropriate provider (recorder or editor).
class VideoEditorAudioChip extends StatelessWidget {
  const VideoEditorAudioChip({
    required this.selectedSound,
    required this.onSoundChanged,
    this.onSelectionStarted,
    this.onSelectionEnded,
    super.key,
  });

  /// The currently selected sound, or null if none selected.
  final AudioEvent? selectedSound;

  /// Called when the sound selection changes.
  ///
  /// Called with the new [AudioEvent] when a sound is selected or its
  /// start offset is changed. Called with `null` when the sound is cleared.
  final ValueChanged<AudioEvent?> onSoundChanged;

  /// Called when audio selection begins (e.g. to pause playback).
  final VoidCallback? onSelectionStarted;

  /// Called when audio selection ends (e.g. to resume playback).
  final VoidCallback? onSelectionEnded;

  Future<void> _selectAudio(BuildContext context) async {
    final previousSound = selectedSound;
    onSelectionStarted?.call();

    try {
      AudioEvent? soundToEdit = previousSound;

      // If no sound selected, show selection sheet first
      if (soundToEdit == null) {
        final result = await VineBottomSheet.show<AudioEvent>(
          context: context,
          maxChildSize: 1,
          initialChildSize: 1,
          minChildSize: 0.8,
          buildScrollBody: (scrollController) =>
              AudioSelectionBottomSheet(scrollController: scrollController),
        );
        if (result == null) {
          onSoundChanged(null);
          return;
        }
        soundToEdit = result;
        // Notify parent about initial selection
      }

      if (!context.mounted) return;

      // Open timing screen and wait for result
      final timingResult = await Navigator.of(context).push<AudioTimingResult>(
        PageRouteBuilder(
          opaque: false,
          barrierColor: VineTheme.transparent,
          pageBuilder: (_, _, _) => VideoAudioEditorTimingScreen(
            sound: soundToEdit!,
          ),
        ),
      );

      // Handle timing screen result
      if (timingResult != null) {
        switch (timingResult) {
          case AudioTimingConfirmed(:final sound):
            onSoundChanged(sound);
          case AudioTimingDeleted():
            onSoundChanged(null);
        }
      }
    } finally {
      onSelectionEnded?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasSelectedSound = selectedSound != null;

    return Hero(
      tag: VideoEditorConstants.heroAudioChipId,
      child: Material(
        type: .transparency,
        child: InkWell(
          onTap: () => _selectAudio(context),
          borderRadius: .circular(16),
          child: Container(
            constraints: const BoxConstraints(minHeight: 40),
            padding: const .fromLTRB(16, 8, 8, 8),
            decoration: ShapeDecoration(
              color: VineTheme.scrim15,
              shape: RoundedRectangleBorder(borderRadius: .circular(16)),
            ),
            child: Row(
              mainAxisSize: .min,
              mainAxisAlignment: .center,
              children: [
                const Row(
                  spacing: 1.5,
                  children: [
                    _AudioBar(height: 7),
                    _AudioBar(height: 16),
                    _AudioBar(height: 13),
                    _AudioBar(height: 7),
                    _AudioBar(height: 10),
                  ],
                ),
                Flexible(
                  child: Padding(
                    padding: const .symmetric(horizontal: 8),
                    child: hasSelectedSound
                        ? Text.rich(
                            textScaler: TextScaler.noScaling,
                            TextSpan(
                              style: VineTheme.labelLargeFont(),
                              children: [
                                // TODO(l10n): Replace with context.l10n when localization is added.
                                TextSpan(
                                  text: selectedSound?.title ?? 'Untitled',
                                ),
                                if (selectedSound?.source != null) ...[
                                  const TextSpan(text: ' ∙ '),
                                  TextSpan(
                                    text: selectedSound!.source,
                                    style: VineTheme.bodyMediumFont(),
                                  ),
                                ],
                              ],
                            ),
                            textAlign: .center,
                            maxLines: 1,
                            overflow: .ellipsis,
                          )
                        : Text(
                            // TODO(l10n): Replace with context.l10n when localization is added.
                            'Add audio',
                            textAlign: .center,
                            textScaler: TextScaler.noScaling,
                            style: VineTheme.titleMediumFont(),
                          ),
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

class _AudioBar extends StatelessWidget {
  const _AudioBar({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: 2,
      height: height,
      decoration: BoxDecoration(
        color: VineTheme.whiteText,
        borderRadius: .circular(2),
      ),
    );
  }
}
