// ABOUTME: State for the captions editor screen.
// ABOUTME: Holds generation status, mode, preset, language, and the cue list.

part of 'captions_editor_cubit.dart';

/// Lifecycle of the captions editor session.
enum CaptionsEditorStatus {
  /// On-device transcription is running.
  generating,

  /// Cues are editable (possibly an empty list the user fills manually).
  ready,

  /// Generation finished without recognizing any speech.
  empty,

  /// Generation failed; `failure` carries the reason.
  failed,
}

/// State of the captions editor screen.
class CaptionsEditorState extends Equatable {
  /// Creates the state.
  const CaptionsEditorState({
    required this.mode,
    required this.presetId,
    required this.languageTag,
    this.status = CaptionsEditorStatus.generating,
    this.failure,
    this.cues = const [],
  });

  /// Current lifecycle status.
  final CaptionsEditorStatus status;

  /// Why generation failed; only set for [CaptionsEditorStatus.failed].
  final CaptionGenerationFailure? failure;

  /// Whether captions are burned in or attached as a CC track.
  final CaptionRenderMode mode;

  /// The track-wide style preset id (burn-in only).
  final String presetId;

  /// BCP-47 recognition/caption language.
  final String languageTag;

  /// The editable cues, ordered by start time.
  final List<CaptionCue> cues;

  /// The caption track this session produces on confirm.
  ///
  /// In burn-in mode the cues live as editor layers, so the stored track
  /// keeps its cue list empty.
  CaptionTrack get track => CaptionTrack(
    mode: mode,
    presetId: presetId,
    languageTag: languageTag,
    cues: mode == CaptionRenderMode.overlay ? cues : const [],
  );

  /// Copy with the given fields replaced.
  CaptionsEditorState copyWith({
    CaptionsEditorStatus? status,
    CaptionGenerationFailure? failure,
    CaptionRenderMode? mode,
    String? presetId,
    List<CaptionCue>? cues,
  }) => CaptionsEditorState(
    status: status ?? this.status,
    failure: failure ?? this.failure,
    mode: mode ?? this.mode,
    presetId: presetId ?? this.presetId,
    languageTag: languageTag,
    cues: cues ?? this.cues,
  );

  @override
  List<Object?> get props => [
    status,
    failure,
    mode,
    presetId,
    languageTag,
    cues,
  ];
}
