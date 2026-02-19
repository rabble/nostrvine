import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:openvine/models/audio_event.dart';

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
        onTap: onSelect,
        minTileHeight: 48,
        leading: Semantics(
          button: true,
          label: isPlaying ? 'Pause preview' : 'Play preview',
          child: GestureDetector(
            onTap: onPlayPause,
            child: Container(
              padding: const .all(12),
              decoration: ShapeDecoration(
                color: VineTheme.surfaceContainer,
                shape: RoundedRectangleBorder(borderRadius: .circular(12)),
              ),
              child: SvgPicture.asset(
                isPlaying
                    ? 'assets/icon/pause_fill.svg'
                    : 'assets/icon/play_fill.svg',
                width: 16,
                height: 16,
                colorFilter: .mode(VineTheme.onSurface, .srcIn),
              ),
            ),
          ),
        ),
        title: Text(
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
        trailing: Container(
          padding: const .all(8),
          decoration: ShapeDecoration(
            color: VineTheme.primary,
            shape: RoundedRectangleBorder(borderRadius: .circular(16)),
          ),
          child: SvgPicture.asset(
            'assets/icon/plus.svg',
            width: 24,
            height: 24,
            colorFilter: const .mode(VineTheme.onPrimary, .srcIn),
          ),
        ),
      ),
    );
  }
}
