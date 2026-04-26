// ABOUTME: Screen for adjusting audio timing/offset for video editor.
// ABOUTME: Displays video preview with audio segment selector overlay.

import 'dart:typed_data';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:models/models.dart' show AudioEvent;
import 'package:openvine/blocs/sound_waveform/sound_waveform_bloc.dart';
import 'package:openvine/blocs/video_editor/audio_timing/audio_timing_cubit.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/stereo_waveform_painter.dart';
import 'package:openvine/widgets/video_editor/audio_editor/video_editor_audio_chip.dart';
import 'package:openvine/widgets/video_editor/video_editor_toolbar.dart';

/// Result of the audio timing screen.
///
/// Returned via [Navigator.pop] to indicate whether the user confirmed
/// the timing selection or deleted the audio.
sealed class AudioTimingResult {
  const AudioTimingResult();
}

/// User confirmed the audio timing selection.
class AudioTimingConfirmed extends AudioTimingResult {
  /// Creates a confirmed result with the updated sound.
  const AudioTimingConfirmed(this.sound);

  /// The sound with updated [AudioEvent.startOffset].
  final AudioEvent sound;
}

/// User deleted the audio.
class AudioTimingDeleted extends AudioTimingResult {
  /// Creates a deleted result.
  const AudioTimingDeleted();
}

/// Screen for adjusting audio timing/offset in the video editor.
///
/// This screen is shown after selecting audio, allowing users to
/// set the start position of the audio track relative to the video.
///
/// Returns an [AudioTimingResult] via [Navigator.pop]:
/// - [AudioTimingConfirmed] with the updated sound when confirmed
/// - [AudioTimingDeleted] when the user deletes the audio
/// - `null` when cancelled (back navigation)
class VideoAudioEditorTimingScreen extends StatefulWidget {
  /// Creates the audio timing screen.
  const VideoAudioEditorTimingScreen({
    required this.sound,
    this.enableDeleteButton = true,
    super.key,
  });

  /// The sound to edit timing for.
  final AudioEvent sound;

  /// Whether the delete button is shown in the toolbar.
  final bool enableDeleteButton;

  /// Route name for navigation.
  static const routeName = 'video-audio-timing';

  /// Route path.
  static const path = '/video-audio-timing';

  @override
  State<VideoAudioEditorTimingScreen> createState() =>
      _VideoAudioEditorTimingScreenState();
}

class _VideoAudioEditorTimingScreenState
    extends State<VideoAudioEditorTimingScreen>
    with SingleTickerProviderStateMixin {
  late final SoundWaveformBloc _waveformBloc;
  late final AnimationController _flingController;
  late final AudioTimingCubit _audioTimingCubit;

  /// Friction for momentum scrolling (higher = stops faster).
  static const double _friction = 0.015;

  @override
  void initState() {
    super.initState();
    _waveformBloc = SoundWaveformBloc();
    _flingController = AnimationController.unbounded(vsync: this);
    _flingController.addListener(_onFlingUpdate);
    _audioTimingCubit = AudioTimingCubit(sound: widget.sound);

    // Delay initialization until after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      // Sync fling controller with initial offset after cubit initializes
      _audioTimingCubit.initialize().then((_) {
        if (mounted) {
          _flingController.value = _audioTimingCubit.state.startOffset;
        }
      });

      _extractWaveform();
    });
  }

  @override
  void dispose() {
    _flingController
      ..removeListener(_onFlingUpdate)
      ..dispose();
    _waveformBloc.close();
    _audioTimingCubit.close();
    super.dispose();
  }

  void _onFlingUpdate() {
    final offset = _flingController.value.clamp(0.0, 1.0);
    _audioTimingCubit.updateOffset(offset);
    // Resume audio at end of fling (when velocity approaches 0)
    if (_flingController.velocity.abs() < 0.001) {
      _audioTimingCubit.resumePlayback();
    }
  }

  void _handleFling(double velocity) {
    // If velocity is too low, just resume audio immediately
    if (velocity.abs() < 0.01) {
      _audioTimingCubit.resumePlayback();
      return;
    }

    // Convert velocity to offset units (normalized 0-1 range)
    // Positive velocity = moving right/forward in audio
    final simulation = FrictionSimulation(
      _friction,
      _audioTimingCubit.state.startOffset,
      velocity,
    );
    _flingController.animateWith(simulation);
  }

  void _handleOffsetChanged(double offset) {
    _flingController.stop();
    _audioTimingCubit.updateOffset(offset);
  }

  /// Pauses audio playback when dragging starts.
  void _handleDragStart() {
    _audioTimingCubit.pausePlayback();
  }

  /// Called from onDragEnd — audio resume is handled by _handleFling.
  void _handleDragEnd() {
    // Audio resume is handled by _handleFling / _onFlingUpdate
  }

  void _extractWaveform() {
    final sound = widget.sound;

    if (sound.isBundled && sound.assetPath != null) {
      _waveformBloc.add(
        SoundWaveformExtract(
          path: sound.assetPath!,
          soundId: sound.id,
          isAsset: true,
        ),
      );
    } else if (sound.url != null) {
      _waveformBloc.add(
        SoundWaveformExtract(path: sound.url!, soundId: sound.id),
      );
    }
  }

  Future<void> _deleteAudio() async {
    await _audioTimingCubit.stopPlayback();
    if (mounted) context.pop<AudioTimingResult>(const AudioTimingDeleted());
  }

  Future<void> _confirmSelection() async {
    await _audioTimingCubit.stopPlayback();
    final startOffset = _audioTimingCubit.calculateStartOffset();
    final updatedSound = widget.sound.copyWith(startOffset: startOffset);
    if (mounted) {
      context.pop<AudioTimingResult>(AudioTimingConfirmed(updatedSound));
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: _waveformBloc),
        BlocProvider.value(value: _audioTimingCubit),
      ],
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: const SystemUiOverlayStyle(
          statusBarColor: VineTheme.transparent,
          systemNavigationBarColor: VineTheme.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
        child: Scaffold(
          backgroundColor: VineTheme.transparent,
          body: Stack(
            fit: StackFit.expand,
            children: [
              const ColoredBox(color: VineTheme.scrim65),

              // Content
              SafeArea(
                child: Column(
                  children: [
                    // Top bar
                    VideoEditorToolbar(
                      closeIcon: widget.enableDeleteButton ? .trash : .x,
                      closeType: widget.enableDeleteButton
                          ? .error
                          : .ghostSecondary,
                      closeSemanticLabel: widget.enableDeleteButton
                          ? 'Remove audio'
                          : 'Close',
                      doneSemanticLabel: 'Confirm audio selection',
                      onClose: widget.enableDeleteButton
                          ? _deleteAudio
                          : context.pop,
                      onDone: _confirmSelection,
                      center: Flexible(
                        child: IgnorePointer(
                          child: VideoEditorAudioChip(
                            selectedSound: widget.sound,
                            onSoundChanged: (_) {},
                          ),
                        ),
                      ),
                    ),

                    const Spacer(),

                    // Bottom controls
                    BlocBuilder<AudioTimingCubit, AudioTimingState>(
                      builder: (context, timingState) {
                        return _BottomControls(
                          startOffset: timingState.startOffset,
                          audioDuration: timingState.audioDuration,
                          onOffsetChanged: _handleOffsetChanged,
                          onFling: _handleFling,
                          onDragStart: _handleDragStart,
                          onDragEnd: _handleDragEnd,
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bottom controls with instruction text and timeline selector.
class _BottomControls extends StatelessWidget {
  const _BottomControls({
    required this.startOffset,
    required this.audioDuration,
    required this.onOffsetChanged,
    required this.onFling,
    required this.onDragStart,
    required this.onDragEnd,
  });

  final double startOffset;

  /// Audio duration in seconds, or null if unknown.
  final double? audioDuration;
  final ValueChanged<double> onOffsetChanged;
  final ValueChanged<double> onFling;
  final VoidCallback onDragStart;
  final VoidCallback onDragEnd;

  /// Calculates the selection width ratio based on video maxDuration vs audio duration.
  ///
  /// The selection always represents [VideoEditorConstants.maxDuration] (6.3s).
  /// - If audio is shorter than maxDuration: returns 1.0 (100% width, fills entire area)
  /// - If audio is longer: returns the proportional ratio (e.g., 33% for ~19s audio)
  /// - Minimum 10% to keep the selection visible and draggable
  double get _selectionWidthRatio {
    final audioDurationSecs = audioDuration;
    if (audioDurationSecs == null || audioDurationSecs <= 0) {
      return 1.0; // Unknown duration, assume full width
    }

    final maxDurationSecs =
        VideoEditorConstants.maxDuration.inMilliseconds / 1000.0;

    // If audio is shorter than video max duration, use full width (100%)
    if (audioDurationSecs <= maxDurationSecs) {
      return 1.0;
    }

    // Ratio of video duration to audio duration, clamped to [0.1, 1.0]
    return (maxDurationSecs / audioDurationSecs).clamp(0.1, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final selectionRatio = _selectionWidthRatio;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Instruction text
        Padding(
          padding: const .symmetric(horizontal: 16),
          child: Text(
            context.l10n.videoEditorAudioSegmentInstruction,
            style: VineTheme.bodySmallFont(),
            textAlign: .center,
          ),
        ),

        const SizedBox(height: 28),

        // Video duration timeline (top bar with green segment)
        _VideoDurationTimeline(
          startOffset: startOffset,
          selectionWidthRatio: selectionRatio,
          audioDuration: audioDuration,
          onOffsetChanged: onOffsetChanged,
          onFling: onFling,
          onDragStart: onDragStart,
          onDragEnd: onDragEnd,
        ),

        const SizedBox(height: 18),

        // Audio waveform with draggable selection
        _AudioWaveformSelector(
          startOffset: startOffset,
          selectionWidthRatio: selectionRatio,
          audioDuration: audioDuration,
          onOffsetChanged: onOffsetChanged,
          onFling: onFling,
          onDragStart: onDragStart,
          onDragEnd: onDragEnd,
        ),
      ],
    );
  }
}

/// Video duration timeline showing where the selected segment will play.
class _VideoDurationTimeline extends StatelessWidget {
  const _VideoDurationTimeline({
    required this.startOffset,
    required this.selectionWidthRatio,
    required this.audioDuration,
    required this.onOffsetChanged,
    required this.onFling,
    required this.onDragStart,
    required this.onDragEnd,
  });

  final double startOffset;

  /// The ratio of the segment width to the total timeline width.
  final double selectionWidthRatio;

  /// Audio duration in seconds, or null if unknown.
  final double? audioDuration;

  final ValueChanged<double> onOffsetChanged;
  final ValueChanged<double> onFling;
  final VoidCallback onDragStart;
  final VoidCallback onDragEnd;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width - 32;
    final segmentWidth = screenWidth * selectionWidthRatio;

    // Calculate scrollable distance based on audio duration
    final maxDurationSecs =
        VideoEditorConstants.maxDuration.inMilliseconds / 1000.0;
    final audioDurationSecs = audioDuration ?? 0;

    // Short audio: no scrolling (segment fills timeline relative to audio)
    // Long audio: scrollable distance proportional to excess audio
    final double maxScrollableDistance;
    if (audioDurationSecs <= 0 || audioDurationSecs <= maxDurationSecs) {
      maxScrollableDistance = 0;
    } else {
      maxScrollableDistance = screenWidth - segmentWidth;
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragStart: (_) => onDragStart(),
      onHorizontalDragUpdate: (details) {
        // Don't allow scrolling if selection fills the timeline
        if (maxScrollableDistance < 1) return;

        final delta = details.delta.dx;
        // Dragging right increases offset (moves segment right)
        final newOffset = (startOffset + delta / maxScrollableDistance).clamp(
          0.0,
          1.0,
        );
        onOffsetChanged(newOffset);
      },
      onHorizontalDragEnd: (details) {
        onDragEnd();
        if (maxScrollableDistance < 1) {
          // No scrolling possible, but still resume audio
          onFling(0);
          return;
        }
        // Convert velocity from pixels to normalized offset units
        final velocityInOffset =
            (details.primaryVelocity ?? 0) / maxScrollableDistance / 1000;
        onFling(velocityInOffset);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: SizedBox(
          height: kMinInteractiveDimension,
          child: Center(
            child: Container(
              height: 8,
              decoration: BoxDecoration(
                color: VineTheme.scrim65,
                borderRadius: .circular(4),
              ),
              child: Stack(
                children: [
                  Positioned(
                    left: startOffset * maxScrollableDistance,
                    child: Container(
                      width: segmentWidth,
                      height: 8,
                      decoration: BoxDecoration(
                        color: VineTheme.vineGreen,
                        borderRadius: BorderRadius.circular(4),
                        border: .all(
                          color: VineTheme.accentYellow,
                          width: 4,
                          strokeAlign: BorderSide.strokeAlignOutside,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Audio waveform with draggable green selection area.
class _AudioWaveformSelector extends StatelessWidget {
  const _AudioWaveformSelector({
    required this.startOffset,
    required this.selectionWidthRatio,
    required this.audioDuration,
    required this.onOffsetChanged,
    required this.onFling,
    required this.onDragStart,
    required this.onDragEnd,
  });

  final double startOffset;

  /// The ratio of the selection width to the total waveform width.
  final double selectionWidthRatio;

  /// Audio duration in seconds, or null if unknown.
  final double? audioDuration;
  final ValueChanged<double> onOffsetChanged;
  final ValueChanged<double> onFling;
  final VoidCallback onDragStart;
  final VoidCallback onDragEnd;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width - 32;
    // Selection area represents portion of audio that fits video duration
    final selectionWidth = screenWidth * selectionWidthRatio;
    // Selection is always centered
    final selectionLeft = (screenWidth - selectionWidth) / 2;

    // Calculate actual waveform width based on audio duration
    final double fullWaveformWidth;
    final maxDurationSecs =
        VideoEditorConstants.maxDuration.inMilliseconds / 1000.0;
    final audioDurationSecs = audioDuration ?? 0;

    if (audioDurationSecs <= 0 || audioDurationSecs <= maxDurationSecs) {
      // Short audio: waveform fits exactly within selection
      fullWaveformWidth = selectionWidth;
    } else {
      // Long audio: waveform extends beyond selection proportionally
      fullWaveformWidth =
          selectionWidth * (audioDurationSecs / maxDurationSecs);
    }

    // Calculate how far the waveform can scroll
    final maxScrollableDistance = (fullWaveformWidth - selectionWidth).clamp(
      0.0,
      double.infinity,
    );
    // Waveform position: at offset 0, waveform starts at selection left edge
    // at offset 1, waveform ends at selection right edge
    final waveformLeft = selectionLeft - startOffset * maxScrollableDistance;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragStart: (_) => onDragStart(),
      onHorizontalDragUpdate: (details) {
        // Don't allow scrolling if selection fills the waveform
        if (maxScrollableDistance < 1) return;

        final delta = details.delta.dx;
        // Invert delta: dragging right scrolls waveform left (increases offset)
        final newOffset = (startOffset - delta / maxScrollableDistance).clamp(
          0.0,
          1.0,
        );
        onOffsetChanged(newOffset);
      },
      onHorizontalDragEnd: (details) {
        onDragEnd();
        if (maxScrollableDistance < 1) {
          // No scrolling possible, but still resume audio
          onFling(0);
          return;
        }
        // Convert velocity from pixels to normalized offset units
        // Invert velocity to match inverted drag direction
        final velocityInOffset =
            -(details.primaryVelocity ?? 0) / maxScrollableDistance / 1000;
        onFling(velocityInOffset);
      },
      child: Container(
        padding: const .fromLTRB(16, 8, 16, 11),
        height: 85,
        color: VineTheme.backgroundColor,
        child: ClipRect(
          child: BlocBuilder<SoundWaveformBloc, SoundWaveformState>(
            builder: (context, waveformState) {
              final (leftChannel, rightChannel) = switch (waveformState) {
                SoundWaveformLoaded(:final leftChannel, :final rightChannel) =>
                  (leftChannel, rightChannel),
                _ => (null, null),
              };

              return Stack(
                children: [
                  // Selection background always centered
                  Positioned(
                    left: selectionLeft,
                    top: 0,
                    bottom: 0,
                    child: Container(
                      width: selectionWidth,
                      decoration: BoxDecoration(
                        color: VineTheme.primary,
                        borderRadius: .circular(24),
                        border: Border.all(
                          color: VineTheme.accentYellow,
                          width: 4,
                        ),
                      ),
                    ),
                  ),

                  // Scrollable waveform (stereo bars) - offset based on selection
                  Positioned(
                    left: waveformLeft,
                    top: 10,
                    bottom: 10,
                    width: fullWaveformWidth,
                    child: TweenAnimationBuilder<double>(
                      key: ValueKey(leftChannel != null),
                      tween: Tween(begin: 0, end: 1),
                      duration: WaveformConstants.animationDuration,
                      curve: WaveformConstants.animationCurve,
                      builder: (context, heightFactor, child) {
                        return ClipRRect(
                          borderRadius: .circular(24),
                          child: SizedBox.expand(
                            child: CustomPaint(
                              painter: StereoWaveformPainter(
                                leftChannel: leftChannel ?? Float32List(0),
                                rightChannel: rightChannel,
                                progress: 1.0, // No progress indicator needed
                                activeColor: VineTheme.whiteText,
                                inactiveColor: VineTheme.whiteText,
                                audioDuration: Duration(
                                  milliseconds: ((audioDuration ?? 0) * 1000)
                                      .toInt(),
                                ),
                                maxDuration: VideoEditorConstants.maxDuration,
                                heightFactor: heightFactor,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  // Selection overlay - always centered
                  Positioned(
                    left: selectionLeft,
                    top: 0,
                    bottom: 0,
                    child: Container(
                      width: selectionWidth,
                      decoration: BoxDecoration(
                        borderRadius: .circular(24),
                        border: Border.all(
                          color: VineTheme.accentYellow,
                          width: 4,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
