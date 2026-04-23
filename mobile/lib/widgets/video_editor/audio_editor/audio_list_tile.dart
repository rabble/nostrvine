import 'dart:math';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:models/models.dart' show AudioEvent;
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/utils/video_editor_utils.dart';
import 'package:openvine/widgets/video_editor_icon_button.dart';

class AudioListTile extends StatelessWidget {
  const AudioListTile({
    required this.audio,
    required this.isPlaying,
    required this.onPlayPause,
    required this.onSelect,
    super.key,
  });

  final AudioEvent audio;
  final bool isPlaying;
  final VoidCallback onPlayPause;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const .symmetric(vertical: 20.0),
      child: ListTile(
        minTileHeight: 48,
        leading: VideoEditorIconButton(
          semanticLabel: isPlaying
              ? context.l10n.videoEditorAudioPausePreviewSemanticLabel
              : context.l10n.videoEditorAudioPlayPreviewSemanticLabel,
          onTap: onPlayPause,
          icon: isPlaying ? .pauseFill : .playFill,
          iconColor: VineTheme.onSurface,
          backgroundColor: VineTheme.surfaceContainer,
          iconSize: 16,
          size: 40,
          radius: 12,
        ),
        title: Text(
          audio.title ?? context.l10n.videoEditorAudioUntitledSound,
          style: VineTheme.titleMediumFont(),
          maxLines: 1,
          overflow: .ellipsis,
        ),
        subtitle: Text.rich(
          TextSpan(
            style: VineTheme.bodyMediumFont(),
            children: [
              TextSpan(
                text: Duration(
                  seconds: max(
                    (audio.duration ?? 0).toInt(),
                    1,
                  ),
                ).toMmSs(),
                style: const TextStyle(fontFeatures: [.tabularFigures()]),
              ),
              if (audio.source != null) ...[
                const TextSpan(text: ' ∙ '),
                TextSpan(text: audio.source),
              ],
            ],
          ),
        ),
        trailing: VideoEditorIconButton(
          semanticLabel: context.l10n.videoEditorAudioSelectSoundSemanticLabel,
          onTap: onSelect,
          icon: .plus,
          iconColor: VineTheme.onPrimary,
          backgroundColor: VineTheme.primary,
          iconSize: 24,
          size: 40,
          radius: 16,
        ),
      ),
    );
  }
}
