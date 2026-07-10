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
    this.extractingAudioClipId,
    this.extractedAudioClipIds = const {},
    this.lastAudioExtraction,
    this.isSplitting = false,
    this.splittingClipId,
    this.lastSplitFailure,
    this.isReversing = false,
    this.reversingClipId,
    this.lastReverseResult,
    this.isTransforming = false,
    this.transformingClipId,
    this.lastTransformResult,
    this.isMultiSelectMode = false,
    this.selectedClipIds = const {},
    this.isMerging = false,
    this.mergingRenderId,
    this.lastMergeResult,
    this.lastClipsRemovedResult,
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

  /// The ID of the clip whose audio is currently being extracted.
  ///
  /// Non-`null` while [isExtractingAudio] is `true`. Lets the controls
  /// disable audio-dependent actions (Speed) only for the affected clip, so
  /// switching to and operating on a different clip stays unblocked.
  final String? extractingAudioClipId;

  /// IDs of clips whose audio has been extracted (and muted) this session.
  ///
  /// Used to dedupe a queued re-extraction: with the `sequential()`
  /// transformer a second Extract tap on a clip queues behind the first, and
  /// without this guard the second run would re-mute the already-muted clip
  /// and emit a second [ClipAudioExtractionSuccess], adding a duplicate audio
  /// track. A manual un-mute (volume > 0) lifts the guard, so a deliberate
  /// re-extraction still works.
  final Set<String> extractedAudioClipIds;

  /// Whether a split operation is currently in progress (rendering).
  final bool isSplitting;

  /// The ID of the clip currently being split (rendering).
  ///
  /// Non-`null` while [isSplitting] is `true`. Lets the controls disable
  /// Split only for the affected clip, leaving other clips unblocked.
  final String? splittingClipId;

  /// One-shot signal emitted when a split rendering operation fails.
  ///
  /// Identity-compared so the [BlocListener] in the scaffold fires exactly
  /// once per failure even if the same error type repeats.
  final ClipSplitFailure? lastSplitFailure;

  /// Last completed audio extraction result. Consumed by the widget layer
  /// to write history (on success) or show an error snackbar (on failure).
  ///
  /// Identity-compared (not value-compared) so each extraction delivers a
  /// fresh signal even when fields happen to repeat.
  final ClipAudioExtractionResult? lastAudioExtraction;

  /// Whether a reverse render operation is currently running.
  final bool isReversing;

  /// Clip ID used as the render-progress stream key while reversing.
  final String? reversingClipId;

  /// Last completed reverse-render result.
  ///
  /// Consumed by the widget layer to persist clip history after a successful
  /// reverse render.
  final ClipReverseResult? lastReverseResult;

  /// Whether a transform (crop/rotate/flip) render operation is running.
  final bool isTransforming;

  /// Render id used as the render-progress stream key while transforming.
  ///
  /// Namespaced from the clip id (`<clipId>_transform`) so it can't collide
  /// with a concurrent reverse render keyed on the same clip id.
  final String? transformingClipId;

  /// Last completed transform-render result.
  ///
  /// Consumed by the widget layer to surface failures. Success is handled by
  /// the canvas player-sync listener that reacts to the swapped clip file.
  final ClipTransformResult? lastTransformResult;

  /// Whether the timeline is in multi-select mode — tapping a clip toggles its
  /// membership in [selectedClipIds] instead of entering single-clip editing.
  final bool isMultiSelectMode;

  /// IDs of the clips currently selected in multi-select mode. Keyed by id so
  /// the selection survives reorder and re-render.
  final Set<String> selectedClipIds;

  /// Whether a merge (concat) render operation is currently running.
  final bool isMerging;

  /// Render id used as the render-progress stream key while merging.
  final String? mergingRenderId;

  /// Last completed merge-render result.
  ///
  /// Consumed by the widget layer to commit the merged clip list to editor
  /// history (on success) or surface a failure snackbar.
  final ClipMergeResult? lastMergeResult;

  /// One-shot signal emitted after a multi-select removal.
  ///
  /// The BLoC owns the clip-list mutation; the widget layer consumes this to
  /// rebase timeline markers and commit the new clip list to editor history.
  final ClipsRemovedResult? lastClipsRemovedResult;

  /// Total wall-clock duration of all clips (respecting trim and playback speed).
  Duration get totalDuration =>
      clips.fold(Duration.zero, (sum, clip) => sum + clip.playbackDuration);

  /// Creates a copy with the given fields replaced.
  ClipEditorState copyWith({
    List<DivineVideoClip>? clips,
    int? currentClipIndex,
    Duration? splitPosition,
    bool? isEditing,
    bool? isTrimDragging,
    int? clipsVolumeRevision,
    ClipSplitEvent? lastSplit,
    bool clearLastSplit = false,
    Duration? trimPosition,
    bool clearTrimPosition = false,
    String? trimmingClipId,
    bool clearTrimmingClipId = false,
    bool? isExtractingAudio,
    String? extractingAudioClipId,
    bool clearExtractingAudioClipId = false,
    Set<String>? extractedAudioClipIds,
    ClipAudioExtractionResult? lastAudioExtraction,
    bool? isSplitting,
    String? splittingClipId,
    bool clearSplittingClipId = false,
    ClipSplitFailure? lastSplitFailure,
    bool? isReversing,
    String? reversingClipId,
    bool clearReversingClipId = false,
    ClipReverseResult? lastReverseResult,
    bool? isTransforming,
    String? transformingClipId,
    bool clearTransformingClipId = false,
    ClipTransformResult? lastTransformResult,
    bool? isMultiSelectMode,
    Set<String>? selectedClipIds,
    bool? isMerging,
    String? mergingRenderId,
    bool clearMergingRenderId = false,
    ClipMergeResult? lastMergeResult,
    ClipsRemovedResult? lastClipsRemovedResult,
  }) {
    return ClipEditorState(
      clips: clips ?? this.clips,
      currentClipIndex: currentClipIndex ?? this.currentClipIndex,
      splitPosition: splitPosition ?? this.splitPosition,
      isEditing: isEditing ?? this.isEditing,
      isTrimDragging: isTrimDragging ?? this.isTrimDragging,
      clipsVolumeRevision: clipsVolumeRevision ?? this.clipsVolumeRevision,
      lastSplit: clearLastSplit ? null : (lastSplit ?? this.lastSplit),
      trimPosition: clearTrimPosition
          ? null
          : (trimPosition ?? this.trimPosition),
      trimmingClipId: clearTrimmingClipId
          ? null
          : (trimmingClipId ?? this.trimmingClipId),
      isExtractingAudio: isExtractingAudio ?? this.isExtractingAudio,
      extractingAudioClipId: clearExtractingAudioClipId
          ? null
          : (extractingAudioClipId ?? this.extractingAudioClipId),
      extractedAudioClipIds:
          extractedAudioClipIds ?? this.extractedAudioClipIds,
      lastAudioExtraction: lastAudioExtraction ?? this.lastAudioExtraction,
      isSplitting: isSplitting ?? this.isSplitting,
      splittingClipId: clearSplittingClipId
          ? null
          : (splittingClipId ?? this.splittingClipId),
      lastSplitFailure: lastSplitFailure ?? this.lastSplitFailure,
      isReversing: isReversing ?? this.isReversing,
      reversingClipId: clearReversingClipId
          ? null
          : (reversingClipId ?? this.reversingClipId),
      lastReverseResult: lastReverseResult ?? this.lastReverseResult,
      isTransforming: isTransforming ?? this.isTransforming,
      transformingClipId: clearTransformingClipId
          ? null
          : (transformingClipId ?? this.transformingClipId),
      lastTransformResult: lastTransformResult ?? this.lastTransformResult,
      isMultiSelectMode: isMultiSelectMode ?? this.isMultiSelectMode,
      selectedClipIds: selectedClipIds ?? this.selectedClipIds,
      isMerging: isMerging ?? this.isMerging,
      mergingRenderId: clearMergingRenderId
          ? null
          : (mergingRenderId ?? this.mergingRenderId),
      lastMergeResult: lastMergeResult ?? this.lastMergeResult,
      lastClipsRemovedResult:
          lastClipsRemovedResult ?? this.lastClipsRemovedResult,
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
    extractingAudioClipId,
    extractedAudioClipIds,
    // Identity-only: each ClipAudioExtractionResult is a fresh instance.
    identityHashCode(lastAudioExtraction),
    isSplitting,
    splittingClipId,
    // Identity-only: each ClipSplitFailure is a fresh instance per failure.
    identityHashCode(lastSplitFailure),
    isReversing,
    reversingClipId,
    identityHashCode(lastReverseResult),
    isTransforming,
    transformingClipId,
    identityHashCode(lastTransformResult),
    isMultiSelectMode,
    selectedClipIds,
    isMerging,
    mergingRenderId,
    // Identity-only: each ClipMergeResult is a fresh instance per merge.
    identityHashCode(lastMergeResult),
    // Identity-only: each ClipsRemovedResult is a fresh instance per removal.
    identityHashCode(lastClipsRemovedResult),
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

// === SPLIT FAILURE SIGNAL ===

/// One-shot signal emitted into [ClipEditorState.lastSplitFailure] when a
/// split rendering operation fails. The scaffold listener uses this to show
/// an error snackbar to the user.
///
/// Identity-compared so each failure produces a distinct notification even
/// when the same error type repeats consecutively.
final class ClipSplitFailure {}

// === REVERSE RESULT ===

/// One-shot signal describing the outcome of a reverse-render operation.
sealed class ClipReverseResult {}

/// Reverse render succeeded; widget should persist the updated clip state.
final class ClipReverseSuccess extends ClipReverseResult {}

/// Reverse render was attempted but the clip has no locally available file.
final class ClipReverseNoLocalFile extends ClipReverseResult {}

/// Reverse render completed but the source clip was removed in-flight.
final class ClipReverseDiscarded extends ClipReverseResult {}

/// Reverse render failed.
final class ClipReverseFailure extends ClipReverseResult {}

// === TRANSFORM RESULT ===

/// One-shot signal describing the outcome of a transform-render operation.
sealed class ClipTransformResult {}

/// Transform render succeeded; the clip file has been swapped in state.
final class ClipTransformSuccess extends ClipTransformResult {}

/// Transform render was attempted but the clip has no locally available file.
final class ClipTransformNoLocalFile extends ClipTransformResult {}

/// Transform render completed but the source clip was removed in-flight.
final class ClipTransformDiscarded extends ClipTransformResult {}

/// Transform render failed.
final class ClipTransformFailure extends ClipTransformResult {}

// === MERGE RESULT ===

/// One-shot signal describing the outcome of a merge-render operation.
///
/// Emitted into [ClipEditorState.lastMergeResult] after each merge attempt.
/// Identity-compared so the scaffold [BlocListener] fires exactly once per
/// attempt even when the same outcome repeats.
sealed class ClipMergeResult {}

/// Merge render succeeded; [ClipEditorState.clips] already holds the merged
/// clip in place of the selected ones. [previousClips] is the clip list as it
/// was immediately before the merge, so the widget layer can rebase timeline
/// markers from the old composition to the new one.
final class ClipMergeSuccess extends ClipMergeResult {
  ClipMergeSuccess({required this.previousClips});

  final List<DivineVideoClip> previousClips;
}

/// Merge render was attempted but cancelled or failed.
final class ClipMergeFailure extends ClipMergeResult {}

/// Merge completed but one or more selected clips were removed from the
/// timeline while the async render was in flight, so the result was discarded.
final class ClipMergeDiscarded extends ClipMergeResult {}

// === CLIPS-REMOVED RESULT ===

/// One-shot signal emitted after a multi-select removal succeeds.
///
/// The BLoC has already dropped the selected clips from [ClipEditorState.clips]
/// by the time this fires; [previousClips] is the clip list as it was before the
/// removal, so the widget layer can rebase timeline markers from the old
/// composition to the new one. Identity-compared so the scaffold [BlocListener]
/// fires exactly once per removal.
final class ClipsRemovedResult {
  ClipsRemovedResult({required this.previousClips});

  final List<DivineVideoClip> previousClips;
}
