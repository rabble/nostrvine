part of 'audio_timing_cubit.dart';

/// State for audio timing selection in the video editor.
class AudioTimingState extends Equatable {
  /// Creates an [AudioTimingState].
  const AudioTimingState({
    this.startOffset = 0,
    this.audioDuration,
    this.isPlaying = false,
  });

  /// Normalized start offset within the scrollable audio range (0.0 - 1.0).
  ///
  /// At 0.0, the selection starts at the beginning of the audio.
  /// At 1.0, the selection ends at the end of the audio.
  final double startOffset;

  /// Cached audio duration in seconds, or `null` if not yet available.
  final double? audioDuration;

  /// Whether audio is currently playing.
  final bool isPlaying;

  /// Creates a copy of this state with optionally updated values.
  AudioTimingState copyWith({
    double? startOffset,
    double? audioDuration,
    bool? isPlaying,
  }) {
    return AudioTimingState(
      startOffset: startOffset ?? this.startOffset,
      audioDuration: audioDuration ?? this.audioDuration,
      isPlaying: isPlaying ?? this.isPlaying,
    );
  }

  @override
  List<Object?> get props => [startOffset, audioDuration, isPlaying];
}
