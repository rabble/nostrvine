import 'dart:math';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:models/models.dart' show AudioEvent;
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/utils/video_editor_utils.dart';

class AudioListTile extends StatelessWidget {
  const AudioListTile({
    required this.audio,
    required this.isSelected,
    required this.onTap,
    this.isPlaying = false,
    super.key,
  });

  final AudioEvent audio;
  final bool isSelected;
  final bool isPlaying;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const .symmetric(vertical: 20.0),
      child: ListTile(
        onTap: onTap,
        minTileHeight: 48,
        title: Text(
          audio.title ?? context.l10n.videoEditorAudioUntitledSound,
          style: VineTheme.titleMediumFont(
            color: isSelected ? VineTheme.primary : VineTheme.onSurface,
          ),
          maxLines: 1,
          overflow: .ellipsis,
        ),
        subtitle: Text.rich(
          TextSpan(
            style: VineTheme.bodyMediumFont(color: VineTheme.onSurfaceVariant),
            children: [
              TextSpan(
                text: Duration(
                  seconds: max((audio.duration ?? 0).toInt(), 1),
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
        trailing: isSelected
            ? _AudioPlayingIndicator(isPlaying: isPlaying)
            : null,
      ),
    );
  }
}

class _AudioPlayingIndicator extends StatefulWidget {
  const _AudioPlayingIndicator({required this.isPlaying});

  final bool isPlaying;

  @override
  State<_AudioPlayingIndicator> createState() => _AudioPlayingIndicatorState();
}

class _AudioPlayingIndicatorState extends State<_AudioPlayingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    if (widget.isPlaying) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(_AudioPlayingIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying != oldWidget.isPlaying) {
      if (widget.isPlaying) {
        _controller.repeat();
      } else {
        _controller.stop();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    if (reduceMotion || !widget.isPlaying) {
      return _AudioBars(progress: _controller.value);
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return _AudioBars(progress: _controller.value);
      },
    );
  }
}

class _AudioBars extends StatelessWidget {
  const _AudioBars({required this.progress});

  final double progress;

  // Per bar: [freqA, phaseA, freqB, phaseB, mixB].
  // Frequencies are integers so the loop stays seamless.
  // Phases are intentionally non-monotonic to break left-right wave look.
  static const List<List<double>> _tracks = [
    [1, 0.0, 3, 2.5, 0.30],
    [2, 4.2, 1, 1.8, 0.35],
    [3, 0.7, 1, 3.3, 0.40],
    [1, 5.5, 2, 0.2, 0.30],
    [2, 2.9, 3, 4.7, 0.35],
  ];

  double _heightFactorFor(int index) {
    final track = _tracks[index];
    final t = progress * 2 * pi;
    final a = sin((t * track[0]) + track[1]);
    final b = sin((t * track[2]) + track[3]);
    final mixB = track[4];
    final mixed = (a * (1 - mixB)) + (b * mixB);
    final normalized = (mixed + 1) / 2;

    return 0.28 + (normalized * 0.66);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 24,
      height: 16,
      child: Row(
        spacing: 2,
        mainAxisSize: MainAxisSize.min,
        children: List.generate(5, (index) {
          final height = 16 * _heightFactorFor(index);

          return DecoratedBox(
            decoration: BoxDecoration(
              color: VineTheme.primary,
              borderRadius: BorderRadius.circular(999),
            ),
            child: SizedBox(width: 2, height: height),
          );
        }),
      ),
    );
  }
}
