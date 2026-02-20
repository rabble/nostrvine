import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:openvine/models/audio_event.dart';
import 'package:openvine/widgets/video_editor_icon_button.dart';

class AudioListTile extends StatelessWidget {
  const AudioListTile({
    super.key,
    required this.audio,
    required this.isPlaying,
    required this.onPlayPause,
    required this.onSelect,
  });

  final AudioEvent audio;
  final bool isPlaying;
  final VoidCallback onPlayPause;
  final VoidCallback onSelect;

  String _formatDuration(double? seconds) {
    if (seconds == null) return '--:--';
    final totalSeconds = seconds.round();
    final mins = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final secs = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const .symmetric(vertical: 20.0),
      child: ListTile(
        minTileHeight: 48,
        leading: VideoEditorIconButton(
          // TODO(l10n): Replace with context.l10n when localization is added.
          semanticLabel: isPlaying ? 'Pause preview' : 'Play preview',
          onTap: onPlayPause,
          iconPath: isPlaying
              ? 'assets/icon/pause_fill.svg'
              : 'assets/icon/play_fill.svg',
          iconColor: VineTheme.onSurface,
          backgroundColor: VineTheme.surfaceContainer,
          iconSize: 16,
          size: 40,
          radius: 12,
        ),
        title: Text(
          // TODO(l10n): Replace with context.l10n when localization is added.
          audio.title ?? 'Untitled sound',
          style: VineTheme.titleMediumFont(fontSize: 16, height: 1.5),
          maxLines: 1,
          overflow: .ellipsis,
        ),
        subtitle: Text.rich(
          TextSpan(
            style: VineTheme.bodyMediumFont(),
            children: [
              TextSpan(
                text: _formatDuration(audio.duration),
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
          // TODO(l10n): Replace with context.l10n when localization is added.
          semanticLabel: 'Select sound',
          onTap: onSelect,
          iconPath: 'assets/icon/plus.svg',
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
