import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/blocs/video_editor/main_editor/video_editor_main_bloc.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/timeline_constants.dart';
import 'package:time_formatter/time_formatter.dart';

/// Left column — time display + audio mute button
class VideoEditorTimelineLeftActions extends StatelessWidget {
  const VideoEditorTimelineLeftActions({
    required this.playheadPosition,
    super.key,
  });

  /// Notifier driven by the scroll offset of the timeline.
  final ValueNotifier<Duration> playheadPosition;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: VineTheme.backgroundCamera.withAlpha(220),
      width: TimelineConstants.leftColumnWidth,
      child: Column(
        children: [
          _ActiveTimeDisplay(playheadPosition: playheadPosition),
          const _AudioButton(),
        ],
      ),
    );
  }
}

/// Time display — shows current position as m:ss.cc
class _ActiveTimeDisplay extends StatelessWidget {
  const _ActiveTimeDisplay({required this.playheadPosition});

  final ValueNotifier<Duration> playheadPosition;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: TimelineConstants.rulerHeight,
      child: Center(
        child: ValueListenableBuilder<Duration>(
          valueListenable: playheadPosition,
          builder: (context, position, _) => Text(
            TimeFormatter.formatPreciseDuration(position),
            style: VineTheme.labelSmallFont(
              color: VineTheme.onSurface,
            ).copyWith(fontFeatures: [const .tabularFigures()]),
            textAlign: TextAlign.center,
            maxLines: 1,
          ),
        ),
      ),
    );
  }
}

/// Audio button — mute toggle with green ring
class _AudioButton extends StatelessWidget {
  const _AudioButton();

  @override
  Widget build(BuildContext context) {
    final isMuted = context.select(
      (VideoEditorMainBloc b) => b.state.isMuted,
    );

    return SizedBox(
      height: TimelineConstants.thumbnailStripHeight,
      child: Center(
        child: DivineIconButton(
          icon: isMuted ? .speakerSimpleX : .speakerHigh,
          size: .small,
          type: .secondary,
          onPressed: () => context.read<VideoEditorMainBloc>().add(
            const VideoEditorMuteToggled(),
          ),
        ),
      ),
    );
  }
}
