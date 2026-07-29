part of 'chroma_key_editor_cubit.dart';

/// Where the auto-detect measurement stands.
enum ChromaKeyDetectionStatus {
  /// No measurement has been asked for, or the last one already landed.
  idle,

  /// A measurement is running.
  detecting,

  /// The last measurement found no usable screen.
  ///
  /// The most common cause is a screen that does not reach the frame border —
  /// only a ring around the edge is sampled, which is what lets the subject be
  /// ignored. The key is left untouched so the user can set it by hand.
  failure,
}

class ChromaKeyEditorState extends Equatable {
  const ChromaKeyEditorState({
    required this.chromaKey,
    this.detectionStatus = ChromaKeyDetectionStatus.idle,
  });

  /// The key as currently configured. Drives the live preview and is what the
  /// screen returns on confirm.
  final ClipChromaKey chromaKey;

  final ChromaKeyDetectionStatus detectionStatus;

  /// Which background the keyed area is filled with.
  ClipChromaKeyBackgroundType get backgroundType => chromaKey.backgroundType;

  /// Whether a measurement is in flight, which disables the controls it would
  /// overwrite.
  bool get isDetecting => detectionStatus == ChromaKeyDetectionStatus.detecting;

  ChromaKeyEditorState copyWith({
    ClipChromaKey? chromaKey,
    ChromaKeyDetectionStatus? detectionStatus,
  }) {
    return ChromaKeyEditorState(
      chromaKey: chromaKey ?? this.chromaKey,
      detectionStatus: detectionStatus ?? this.detectionStatus,
    );
  }

  @override
  List<Object?> get props => [chromaKey, detectionStatus];
}
