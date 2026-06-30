part of 'sound_waveform_bloc.dart';

/// Base event for sound waveform actions.
sealed class SoundWaveformEvent extends Equatable {
  const SoundWaveformEvent();

  @override
  List<Object?> get props => [];
}

/// Extract waveform data from a sound source.
class SoundWaveformExtract extends SoundWaveformEvent {
  const SoundWaveformExtract({
    required this.path,
    required this.soundId,
    this.kind = AudioSourceKind.network,
  });

  /// Build an extract event for [sound], or `null` when it has no usable
  /// source. Resolves the correct [AudioSourceKind] (bundled asset, imported
  /// file, or network URL) so callers don't re-derive it.
  static SoundWaveformExtract? forSound(AudioEvent sound) {
    final source = sound.resolvedSource;
    if (source == null) return null;
    return SoundWaveformExtract(
      path: source.path,
      soundId: sound.id,
      kind: source.kind,
    );
  }

  /// The asset path, file path, or URL of the sound to extract from.
  final String path;

  /// The sound ID for logging purposes.
  final String soundId;

  /// The kind of source [path] points to.
  final AudioSourceKind kind;

  @override
  List<Object?> get props => [path, soundId, kind];
}

/// Clear the current waveform data.
class SoundWaveformClear extends SoundWaveformEvent {
  const SoundWaveformClear();
}
