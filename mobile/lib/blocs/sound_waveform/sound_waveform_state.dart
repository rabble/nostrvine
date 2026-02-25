part of 'sound_waveform_bloc.dart';

/// State for sound waveform bloc.
sealed class SoundWaveformState extends Equatable {
  const SoundWaveformState();

  @override
  List<Object?> get props => [];
}

/// Initial state - no waveform loaded.
class SoundWaveformInitial extends SoundWaveformState {
  const SoundWaveformInitial();
}

/// Waveform extraction in progress.
class SoundWaveformLoading extends SoundWaveformState {
  const SoundWaveformLoading();
}

/// Waveform data loaded successfully.
class SoundWaveformLoaded extends SoundWaveformState {
  const SoundWaveformLoaded({
    required this.leftChannel,
    required this.duration,
    this.rightChannel,
  });

  /// Left channel amplitude samples.
  final Float32List leftChannel;

  /// Right channel amplitude samples (null for mono).
  final Float32List? rightChannel;

  /// Duration of the audio.
  final Duration duration;

  @override
  List<Object?> get props => [leftChannel, rightChannel, duration];
}

/// Error extracting waveform.
class SoundWaveformError extends SoundWaveformState {
  const SoundWaveformError(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}
