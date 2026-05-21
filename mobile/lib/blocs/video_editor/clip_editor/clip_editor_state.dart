part of 'clip_editor_bloc.dart';

/// State for the clip editor screen.
///
/// Manages clip selection, editing mode, and local clip mutations.
///
/// Clip mutations happen locally in this state. The parent screen
/// syncs the final clip list back to the Riverpod provider when
/// the editor is closed.
class ClipEditorState extends Equatable {
  const ClipEditorState({
    this.clips = const [],
    this.currentClipIndex = 0,
    this.splitPosition = Duration.zero,
    this.isEditing = false,
    this.isTrimDragging = false,
    this.clipsVolumeRevision = 0,
    this.lastSplit,
    this.trimPosition,
    this.trimmingClipId,
    this.isExtractingAudio = false,
    this.lastAudioExtraction,
  });

  /// Local copy of clips managed by this editor session.
  final List<DivineVideoClip> clips;

  /// Index of the currently active/selected clip (0-based).
  final int currentClipIndex;

  /// Position where a clip split operation will occur.
  final Duration splitPosition;

  /// Whether the editor is in editing mode (e.g., trimming, adjusting).
  final bool isEditing;

  /// Whether a trim handle is currently being dragged.
  final bool isTrimDragging;

  /// Incremented each time a clip's playback volume changes.
  ///
  /// `DivineVideoClip` equality is identity-based, so a volume-only update
  /// on a clip would produce a distinct `clips` list (via `copyWith`) and
  /// Equatable would detect it. However, the canvas `BlocListener` that
  /// fires for clip list changes also rebuilds the composite player — which
  /// is correct but expensive. This counter lets a lightweight, dedicated
  /// volume-history listener fire without touching that heavier path.
  final int clipsVolumeRevision;

  /// Last completed split operation. Consumed by the timeline strip
  /// to seed the new clips' thumbnail notifiers from the source clip
  /// — avoiding a flash of placeholder/wrong-range thumbnails while
  /// the trimmed segment files are still being rendered.
  ///
  /// Identity-compared (not value-compared) so each split delivers a
  /// fresh signal even when fields happen to repeat.
  final ClipSplitEvent? lastSplit;

  /// The live absolute timeline position of the trim handle being dragged.
  ///
  /// Set while a trim gesture is active; `null` when no trim is in progress.
  final Duration? trimPosition;

  /// The ID of the clip currently being trimmed.
  ///
  /// Non-`null` while a trim gesture is active. Allows the preview
  /// player to switch to a single-clip view of the trimmed clip so
  /// [trimPosition] (which is relative to that clip's untrimmed
  /// timeline) seeks to the correct frame.
  final String? trimmingClipId;

  /// Whether an audio extraction operation is currently running.
  final bool isExtractingAudio;

  /// Last completed audio extraction result. Consumed by the widget layer
  /// to write history (on success) or show an error snackbar (on failure).
  ///
  /// Identity-compared (not value-compared) so each extraction delivers a
  /// fresh signal even when fields happen to repeat.
  final ClipAudioExtractionResult? lastAudioExtraction;

  /// Total duration of all clips (respecting trim).
  Duration get totalDuration =>
      clips.fold(Duration.zero, (sum, clip) => sum + clip.trimmedDuration);

  /// Creates a copy with the given fields replaced.
  ClipEditorState copyWith({
    List<DivineVideoClip>? clips,
    int? currentClipIndex,
    Duration? splitPosition,
    bool? isEditing,
    bool? isTrimDragging,
    int? clipsVolumeRevision,
    ClipSplitEvent? lastSplit,
    Duration? trimPosition,
    bool clearTrimPosition = false,
    String? trimmingClipId,
    bool clearTrimmingClipId = false,
    bool? isExtractingAudio,
    ClipAudioExtractionResult? lastAudioExtraction,
  }) {
    return ClipEditorState(
      clips: clips ?? this.clips,
      currentClipIndex: currentClipIndex ?? this.currentClipIndex,
      splitPosition: splitPosition ?? this.splitPosition,
      isEditing: isEditing ?? this.isEditing,
      isTrimDragging: isTrimDragging ?? this.isTrimDragging,
      clipsVolumeRevision: clipsVolumeRevision ?? this.clipsVolumeRevision,
      lastSplit: lastSplit ?? this.lastSplit,
      trimPosition: clearTrimPosition
          ? null
          : (trimPosition ?? this.trimPosition),
      trimmingClipId: clearTrimmingClipId
          ? null
          : (trimmingClipId ?? this.trimmingClipId),
      isExtractingAudio: isExtractingAudio ?? this.isExtractingAudio,
      lastAudioExtraction: lastAudioExtraction ?? this.lastAudioExtraction,
    );
  }

  @override
  List<Object?> get props => [
    clips,
    currentClipIndex,
    splitPosition,
    isEditing,
    isTrimDragging,
    clipsVolumeRevision,
    // Identity-only: each ClipSplitEvent is a fresh instance per split.
    identityHashCode(lastSplit),
    trimPosition,
    trimmingClipId,
    isExtractingAudio,
    // Identity-only: each ClipAudioExtractionResult is a fresh instance.
    identityHashCode(lastAudioExtraction),
  ];
}

/// One-shot signal describing a split operation that just occurred.
///
/// The timeline strip uses this to seed the newly-created clips'
/// thumbnail notifiers from the source clip's already-loaded
/// thumbnails.
class ClipSplitEvent {
  ClipSplitEvent({
    required this.sourceClipId,
    required this.startClipId,
    required this.endClipId,
    required this.absoluteSplitPosition,
    required this.sourceDuration,
    this.sourceTrimStart = Duration.zero,
    this.sourceTrimEnd = Duration.zero,
  });

  final String sourceClipId;
  final String startClipId;
  final String endClipId;
  final Duration absoluteSplitPosition;
  final Duration sourceDuration;
  final Duration sourceTrimStart;
  final Duration sourceTrimEnd;
}

// === AUDIO EXTRACTION RESULT ===

/// One-shot signal describing the outcome of an audio extraction operation.
///
/// Emitted into [ClipEditorState.lastAudioExtraction] after each extraction
/// attempt. Identity-compared so the [BlocListener] in the widget fires
/// exactly once per attempt.
sealed class ClipAudioExtractionResult {}

/// Extraction completed; widget should write history with the created
/// [audioEvent] and the updated (muted) clip already in [ClipEditorState.clips].
final class ClipAudioExtractionSuccess extends ClipAudioExtractionResult {
  ClipAudioExtractionSuccess({required this.audioEvent});

  final AudioEvent audioEvent;
}

/// Extraction was attempted but the clip has no locally available file.
final class ClipAudioExtractionNoLocalFile extends ClipAudioExtractionResult {}

/// Extraction completed but the source clip was removed from the timeline
/// while the async extraction was in flight. The widget should silently
/// ignore this — there is no clip to attach the result to and no user
/// action that warrants a snackbar.
final class ClipAudioExtractionDiscarded extends ClipAudioExtractionResult {}

/// Extraction failed; widget should show a snackbar.
final class ClipAudioExtractionFailure extends ClipAudioExtractionResult {}
