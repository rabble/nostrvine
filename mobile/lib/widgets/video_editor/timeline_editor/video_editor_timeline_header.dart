import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/blocs/video_editor/clip_editor/clip_editor_bloc.dart';
import 'package:openvine/blocs/video_editor/main_editor/video_editor_main_bloc.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_scope.dart';
import 'package:time_formatter/time_formatter.dart';

class VideoEditorTimelineHeader extends StatelessWidget {
  const VideoEditorTimelineHeader({required this.playheadPosition, super.key});

  /// Notifier driven by the scroll offset of the timeline.
  final ValueNotifier<Duration> playheadPosition;

  static const _padding = EdgeInsets.symmetric(horizontal: 16);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: _padding,
          scrollDirection: .horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: constraints.maxWidth - _padding.horizontal,
            ),
            child: Row(
              mainAxisAlignment: .spaceBetween,
              spacing: 8,
              children: [
                const Row(
                  spacing: 8,
                  children: [_PlayPauseButton(), _MuteButton()],
                ),

                _TimeDisplay(playheadPosition: playheadPosition),

                const Row(spacing: 8, children: [_UndoButton(), _RedoButton()]),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PlayPauseButton extends StatelessWidget {
  const _PlayPauseButton();

  @override
  Widget build(BuildContext context) {
    final isPlaying = context.select(
      (VideoEditorMainBloc b) => b.state.isPlaying,
    );

    return DivineIconButton(
      icon: isPlaying ? .pauseFill : .playFill,
      size: .small,
      type: .ghost,
      semanticLabel: isPlaying
          ? context.l10n.videoEditorPauseSemanticLabel
          : context.l10n.videoEditorPlaySemanticLabel,
      onPressed: () => context.read<VideoEditorMainBloc>().add(
        const VideoEditorPlaybackToggleRequested(),
      ),
    );
  }
}

class _MuteButton extends StatelessWidget {
  const _MuteButton();

  @override
  Widget build(BuildContext context) {
    final isMuted = context.select((VideoEditorMainBloc b) => b.state.isMuted);

    return DivineIconButton(
      icon: isMuted ? .speakerSimpleX : .speakerHigh,
      size: .small,
      type: .ghost,
      semanticLabel: isMuted
          ? context.l10n.videoEditorUnmuteAudioSemanticLabel
          : context.l10n.videoEditorMuteAudioSemanticLabel,
      onPressed: () => context.read<VideoEditorMainBloc>().add(
        const VideoEditorMuteToggled(),
      ),
    );
  }
}

class _TimeDisplay extends StatelessWidget {
  const _TimeDisplay({required this.playheadPosition});

  final ValueNotifier<Duration> playheadPosition;

  static final TextStyle _timeStyle = VineTheme.labelLargeFont().copyWith(
    fontFeatures: [const FontFeature.tabularFigures()],
  );

  @override
  Widget build(BuildContext context) {
    final totalDuration = context.select(
      (ClipEditorBloc b) => b.state.totalDuration,
    );

    return ValueListenableBuilder<Duration>(
      valueListenable: playheadPosition,
      builder: (context, position, _) {
        final isOver =
            position.inMilliseconds >
            VideoEditorConstants.maxDuration.inMilliseconds;
        final positionText = TextSpan(
          text: TimeFormatter.formatCompactDuration(position),
          style: isOver
              ? _timeStyle.copyWith(color: VineTheme.warning)
              : _timeStyle,
        );
        return Text.rich(
          TextSpan(
            children: [
              positionText,
              TextSpan(text: ' / ', style: _timeStyle),
              TextSpan(
                text: TimeFormatter.formatCompactDuration(totalDuration),
                style: _timeStyle,
              ),
            ],
          ),
          maxLines: 1,
        );
      },
    );
  }
}

class _UndoButton extends StatelessWidget {
  const _UndoButton();

  @override
  Widget build(BuildContext context) {
    final canUndo = context.select((VideoEditorMainBloc b) => b.state.canUndo);

    return DivineIconButton(
      icon: .arrowUUpLeft,
      size: .small,
      type: .ghost,
      semanticLabel: context.l10n.videoEditorUndoSemanticLabel,
      onPressed: canUndo ? () => _performUndo(context) : null,
    );
  }

  void _performUndo(BuildContext context) {
    VideoEditorScope.of(context).editor?.undoAction();
  }
}

class _RedoButton extends StatelessWidget {
  const _RedoButton();

  @override
  Widget build(BuildContext context) {
    final canRedo = context.select((VideoEditorMainBloc b) => b.state.canRedo);

    return DivineIconButton(
      icon: .arrowUUpRight,
      size: .small,
      type: .ghost,
      semanticLabel: context.l10n.videoEditorRedoSemanticLabel,
      onPressed: canRedo ? () => _performRedo(context) : null,
    );
  }

  void _performRedo(BuildContext context) {
    VideoEditorScope.of(context).editor?.redoAction();
  }
}
