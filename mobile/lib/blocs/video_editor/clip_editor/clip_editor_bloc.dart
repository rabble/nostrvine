import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/constants/video_editor_timeline_constants.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/services/video_editor/video_editor_split_service.dart';
import 'package:unified_logger/unified_logger.dart';

part 'clip_editor_event.dart';
part 'clip_editor_state.dart';

/// Callback that executes the clip split operation and post-split
/// side effects (rendered clip invalidation, autosave).
///
/// The BLoC handles clip list mutations locally; this callback only
/// performs the async rendering work and returns the two resulting clips.
typedef SplitExecutor =
    Future<void> Function({
      required DivineVideoClip sourceClip,
      required Duration splitPosition,
      required int currentClipIndex,
    });

/// BLoC for managing video clip editor state.
///
/// Owns a local copy of the clip list so that all mutations (add, remove,
/// reorder, split) happen in-memory without touching the Riverpod
/// [ClipManagerProvider]. The parent screen syncs the final clip list
/// back to the provider when the editor closes.
///
/// Supports undo/redo for clip mutations.
///
/// **Transition seam**: This BLoC receives its initial clip list from the
/// Riverpod [ClipManagerProvider] via [ClipEditorInitialized] dispatched in
/// the widget layer. This is an intentional migration boundary — the target
/// architecture replaces the Riverpod provider with a [VideoEditorRepository]
/// injected directly into this BLoC. See the follow-up migration issue.
class ClipEditorBloc extends Bloc<ClipEditorEvent, ClipEditorState> {
  ClipEditorBloc({required void Function() this.onFinalClipInvalidated})
    : super(const ClipEditorState()) {
    // Clip data
    on<ClipEditorInitialized>(_onInitialized);
    on<ClipEditorClipRemoved>(_onClipRemoved);
    on<ClipEditorClipReordered>(_onClipReordered);
    on<ClipEditorClipInserted>(_onClipInserted);
    on<ClipEditorClipUpdated>(_onClipUpdated);

    // Undo / Redo
    on<ClipEditorUndoRequested>(_onUndo);
    on<ClipEditorRedoRequested>(_onRedo);

    // Clip selection
    on<ClipEditorClipSelected>(_onClipSelected);

    // Playback control
    on<ClipEditorPlayPauseToggled>(_onPlayPauseToggled);
    on<ClipEditorPlaybackPaused>(_onPlaybackPaused);
    on<ClipEditorPlayerReadyChanged>(_onPlayerReadyChanged);
    on<ClipEditorFirstPlaybackStarted>(_onFirstPlaybackStarted);
    on<ClipEditorMuteToggled>(_onMuteToggled);
    on<ClipEditorPositionUpdated>(_onPositionUpdated);

    // Editing mode
    on<ClipEditorEditingStarted>(_onEditingStarted);
    on<ClipEditorEditingStopped>(_onEditingStopped);
    on<ClipEditorEditingToggled>(_onEditingToggled);
    on<ClipEditorSplitPositionChanged>(_onSplitPositionChanged);

    // Reordering
    on<ClipEditorReorderingStarted>(_onReorderingStarted);
    on<ClipEditorReorderingStopped>(_onReorderingStopped);
    on<ClipEditorDeleteZoneChanged>(_onDeleteZoneChanged);

    // Split
    on<ClipEditorOriginalClipReplaced>(_onOriginalClipReplaced);
    on<ClipEditorSplitRequested>(_onSplitRequested, transformer: droppable());

    // Trim
    on<ClipEditorTrimUpdated>(_onTrimUpdated, transformer: restartable());
    on<ClipEditorTrimDragStarted>(_onTrimDragStarted);
    on<ClipEditorTrimDragEnded>(_onTrimDragEnded);
  }

  final void Function()? onFinalClipInvalidated;

  /// Pushes the current clip list onto the undo stack and clears redo.
  ClipEditorState _pushUndo(ClipEditorState s) {
    final newUndo = [
      ...s.undoStack,
      ClipSnapshot(List.unmodifiable(s.clips)),
    ];

    // Trim oldest entries beyond the limit.
    final trimmed = newUndo.length > VideoEditorConstants.maxUndoSteps
        ? newUndo.sublist(
            newUndo.length - VideoEditorConstants.maxUndoSteps,
          )
        : newUndo;

    return s.copyWith(undoStack: trimmed, redoStack: const []);
  }

  // === CLIP DATA ===

  void _onInitialized(
    ClipEditorInitialized event,
    Emitter<ClipEditorState> emit,
  ) {
    Log.debug(
      '📋 Initialized with ${event.clips.length} clip(s)',
      name: 'ClipEditorBloc',
      category: LogCategory.video,
    );
    emit(state.copyWith(clips: List.unmodifiable(event.clips)));
  }

  void _onClipRemoved(
    ClipEditorClipRemoved event,
    Emitter<ClipEditorState> emit,
  ) {
    final index = state.clips.indexWhere((c) => c.id == event.clipId);
    if (index == -1) return;

    final withUndo = _pushUndo(state);
    final newClips = List<DivineVideoClip>.of(withUndo.clips)..removeAt(index);

    Log.debug(
      '🗑️ Removed clip ${event.clipId} (${newClips.length} remaining)',
      name: 'ClipEditorBloc',
      category: LogCategory.video,
    );

    emit(withUndo.copyWith(clips: List.unmodifiable(newClips)));
  }

  void _onClipReordered(
    ClipEditorClipReordered event,
    Emitter<ClipEditorState> emit,
  ) {
    if (event.oldIndex == event.newIndex) return;
    if (event.oldIndex < 0 || event.oldIndex >= state.clips.length) return;

    final withUndo = _pushUndo(state);
    final newClips = List<DivineVideoClip>.of(withUndo.clips);
    final clip = newClips.removeAt(event.oldIndex);
    newClips.insert(event.newIndex.clamp(0, newClips.length), clip);

    Log.debug(
      '🔄 Reordered clip from ${event.oldIndex} to ${event.newIndex}',
      name: 'ClipEditorBloc',
      category: LogCategory.video,
    );

    emit(withUndo.copyWith(clips: List.unmodifiable(newClips)));
  }

  void _onClipInserted(
    ClipEditorClipInserted event,
    Emitter<ClipEditorState> emit,
  ) {
    final withUndo = _pushUndo(state);
    final newClips = List<DivineVideoClip>.of(withUndo.clips)
      ..insert(event.index.clamp(0, withUndo.clips.length), event.clip);

    Log.debug(
      '➕ Inserted clip ${event.clip.id} at index ${event.index}',
      name: 'ClipEditorBloc',
      category: LogCategory.video,
    );

    emit(withUndo.copyWith(clips: List.unmodifiable(newClips)));
  }

  void _onClipUpdated(
    ClipEditorClipUpdated event,
    Emitter<ClipEditorState> emit,
  ) {
    final index = state.clips.indexWhere((c) => c.id == event.clipId);
    if (index == -1) return;

    final newClips = List<DivineVideoClip>.of(state.clips)
      ..[index] = event.clip;

    // Clip updates (thumbnail, video render) are not undoable — they are
    // async refinements of a previous mutation that was already recorded.
    emit(state.copyWith(clips: List.unmodifiable(newClips)));
  }

  // === UNDO / REDO ===

  void _onUndo(
    ClipEditorUndoRequested event,
    Emitter<ClipEditorState> emit,
  ) {
    if (!state.canUndo) return;

    final snapshot = state.undoStack.last;
    final newUndo = List<ClipSnapshot>.of(state.undoStack)..removeLast();
    final newRedo = [
      ...state.redoStack,
      ClipSnapshot(List.unmodifiable(state.clips)),
    ];

    Log.debug(
      '↩️ Undo – restoring ${snapshot.clips.length} clip(s)',
      name: 'ClipEditorBloc',
      category: LogCategory.video,
    );

    final newIndex = state.currentClipIndex >= snapshot.clips.length
        ? (snapshot.clips.length - 1).clamp(0, snapshot.clips.length)
        : state.currentClipIndex;

    emit(
      state.copyWith(
        clips: snapshot.clips,
        undoStack: newUndo,
        redoStack: newRedo,
        currentClipIndex: newIndex,
      ),
    );
  }

  void _onRedo(
    ClipEditorRedoRequested event,
    Emitter<ClipEditorState> emit,
  ) {
    if (!state.canRedo) return;

    final snapshot = state.redoStack.last;
    final newRedo = List<ClipSnapshot>.of(state.redoStack)..removeLast();
    final newUndo = [
      ...state.undoStack,
      ClipSnapshot(List.unmodifiable(state.clips)),
    ];

    Log.debug(
      '↪️ Redo – restoring ${snapshot.clips.length} clip(s)',
      name: 'ClipEditorBloc',
      category: LogCategory.video,
    );

    final newIndex = state.currentClipIndex >= snapshot.clips.length
        ? (snapshot.clips.length - 1).clamp(0, snapshot.clips.length)
        : state.currentClipIndex;

    emit(
      state.copyWith(
        clips: snapshot.clips,
        undoStack: newUndo,
        redoStack: newRedo,
        currentClipIndex: newIndex,
      ),
    );
  }

  // === CLIP SELECTION ===

  void _onClipSelected(
    ClipEditorClipSelected event,
    Emitter<ClipEditorState> emit,
  ) {
    final clips = state.clips;
    if (event.index < 0 || event.index >= clips.length) return;

    final offset = clips
        .take(event.index)
        .fold(Duration.zero, (sum, clip) => sum + clip.trimmedDuration);

    Log.debug(
      '🎯 Selected clip ${event.index} (offset: ${offset.inSeconds}s)',
      name: 'ClipEditorBloc',
      category: LogCategory.video,
    );

    // During reorder we only update the visual index — the video player
    // stays on the same clip, so don't reset player readiness.
    emit(
      state.copyWith(
        currentClipIndex: event.index,
        isPlaying: false,
        isPlayerReady: state.isReordering ? null : false,
        hasPlayedOnce: state.isReordering ? null : false,
        currentPosition: offset,
        splitPosition: Duration.zero,
      ),
    );
  }

  // === PLAYBACK CONTROL ===

  void _onPlayPauseToggled(
    ClipEditorPlayPauseToggled event,
    Emitter<ClipEditorState> emit,
  ) {
    final newState = !state.isPlaying;

    // Prevent playing before player is initialized
    if (!state.isPlayerReady && newState) return;

    Log.debug(
      newState ? '▶️ Playing video' : '⏸️ Paused video',
      name: 'ClipEditorBloc',
      category: LogCategory.video,
    );

    emit(state.copyWith(isPlaying: newState));
  }

  void _onPlaybackPaused(
    ClipEditorPlaybackPaused event,
    Emitter<ClipEditorState> emit,
  ) {
    Log.debug(
      '⏸️ Paused video',
      name: 'ClipEditorBloc',
      category: LogCategory.video,
    );
    emit(state.copyWith(isPlaying: false));
  }

  void _onPlayerReadyChanged(
    ClipEditorPlayerReadyChanged event,
    Emitter<ClipEditorState> emit,
  ) {
    if (state.isPlayerReady == event.isReady) return;
    Log.debug(
      event.isReady ? '✅ Player ready' : '⏳ Player not ready',
      name: 'ClipEditorBloc',
      category: LogCategory.video,
    );
    emit(state.copyWith(isPlayerReady: event.isReady));
  }

  void _onFirstPlaybackStarted(
    ClipEditorFirstPlaybackStarted event,
    Emitter<ClipEditorState> emit,
  ) {
    if (state.hasPlayedOnce) return;
    emit(state.copyWith(hasPlayedOnce: true));
  }

  void _onMuteToggled(
    ClipEditorMuteToggled event,
    Emitter<ClipEditorState> emit,
  ) {
    final newState = !state.isMuted;
    Log.debug(
      newState ? '🔇 Muted audio' : '🔊 Unmuted audio',
      name: 'ClipEditorBloc',
      category: LogCategory.video,
    );
    emit(state.copyWith(isMuted: newState));
  }

  void _onPositionUpdated(
    ClipEditorPositionUpdated event,
    Emitter<ClipEditorState> emit,
  ) {
    final clips = state.clips;

    // Ignore stale position updates from previous clip's controller
    if (state.currentClipIndex >= clips.length ||
        event.clipId != clips[state.currentClipIndex].id) {
      return;
    }

    final offset = state.isEditing
        ? Duration.zero
        : clips
              .take(state.currentClipIndex)
              .fold(Duration.zero, (sum, clip) => sum + clip.trimmedDuration);

    emit(
      state.copyWith(
        currentPosition: Duration(
          milliseconds: (offset + event.position).inMilliseconds.clamp(
            0,
            VideoEditorConstants.maxDuration.inMilliseconds,
          ),
        ),
      ),
    );
  }

  // === EDITING MODE ===

  void _onEditingStarted(
    ClipEditorEditingStarted event,
    Emitter<ClipEditorState> emit,
  ) {
    final clips = state.clips;
    if (state.currentClipIndex >= clips.length) return;

    Log.info(
      '✂️ Started editing clip ${state.currentClipIndex}',
      name: 'ClipEditorBloc',
      category: LogCategory.video,
    );
    emit(
      state.copyWith(
        isEditing: true,
        isPlaying: false,
        splitPosition: clips[state.currentClipIndex].trimmedDuration ~/ 2,
      ),
    );
  }

  void _onEditingStopped(
    ClipEditorEditingStopped event,
    Emitter<ClipEditorState> emit,
  ) {
    Log.info(
      '✅ Stopped editing clip ${state.currentClipIndex}',
      name: 'ClipEditorBloc',
      category: LogCategory.video,
    );
    emit(state.copyWith(isEditing: false, isPlaying: false));
  }

  void _onEditingToggled(
    ClipEditorEditingToggled event,
    Emitter<ClipEditorState> emit,
  ) {
    if (state.isEditing) {
      _onEditingStopped(const ClipEditorEditingStopped(), emit);
    } else {
      _onEditingStarted(const ClipEditorEditingStarted(), emit);
    }
  }

  void _onSplitPositionChanged(
    ClipEditorSplitPositionChanged event,
    Emitter<ClipEditorState> emit,
  ) {
    emit(state.copyWith(splitPosition: event.position, isPlaying: false));
  }

  // === REORDERING ===

  void _onReorderingStarted(
    ClipEditorReorderingStarted event,
    Emitter<ClipEditorState> emit,
  ) {
    Log.debug(
      '🔄 Started clip reordering mode',
      name: 'ClipEditorBloc',
      category: LogCategory.video,
    );
    emit(state.copyWith(isReordering: true, isPlaying: false));
  }

  void _onReorderingStopped(
    ClipEditorReorderingStopped event,
    Emitter<ClipEditorState> emit,
  ) {
    Log.debug(
      '✅ Stopped clip reordering mode',
      name: 'ClipEditorBloc',
      category: LogCategory.video,
    );
    emit(state.copyWith(isReordering: false, isOverDeleteZone: false));
  }

  void _onDeleteZoneChanged(
    ClipEditorDeleteZoneChanged event,
    Emitter<ClipEditorState> emit,
  ) {
    if (state.isOverDeleteZone == event.isOver) return;

    Log.debug(
      event.isOver ? '🗑️  Clip over delete zone' : '⬅️  Clip left delete zone',
      name: 'ClipEditorBloc',
      category: LogCategory.video,
    );
    emit(state.copyWith(isOverDeleteZone: event.isOver));
  }

  // === SPLIT ===

  void _onOriginalClipReplaced(
    ClipEditorOriginalClipReplaced event,
    Emitter<ClipEditorState> emit,
  ) {
    final index = state.clips.indexWhere(
      (c) => c.id == event.sourceClipId,
    );
    if (index == -1) return;

    final withUndo = _pushUndo(state);
    final newClips = List<DivineVideoClip>.of(withUndo.clips)
      ..[index] = event.startClip
      ..insert(index + 1, event.endClip);

    Log.debug(
      '✂️ Replaced ${event.sourceClipId} with '
      '${event.startClip.id} + ${event.endClip.id}',
      name: 'ClipEditorBloc',
      category: LogCategory.video,
    );

    emit(
      withUndo.copyWith(
        clips: List.unmodifiable(newClips),
        isPlayerReady: false,
        hasPlayedOnce: false,
      ),
    );
  }

  Future<void> _onSplitRequested(
    ClipEditorSplitRequested event,
    Emitter<ClipEditorState> emit,
  ) async {
    final clips = state.clips;
    if (state.currentClipIndex >= clips.length) return;

    final selectedClip = clips[state.currentClipIndex];
    final splitPosition = state.splitPosition;

    // Validate split position before changing state
    if (!VideoEditorSplitService.isValidSplitPosition(
      selectedClip,
      splitPosition,
    )) {
      Log.warning(
        '⚠️ Invalid split position ${splitPosition.inSeconds}s - '
        'clips must be at least '
        '${VideoEditorSplitService.minClipDuration.inMilliseconds}ms',
        name: 'ClipEditorBloc',
        category: LogCategory.video,
      );
      return;
    }

    Log.info(
      '✂️ Splitting clip ${selectedClip.id} at '
      '${splitPosition.inSeconds}s',
      name: 'ClipEditorBloc',
      category: LogCategory.video,
    );

    // Stop editing mode
    emit(state.copyWith(isEditing: false, isPlaying: false));

    try {
      await VideoEditorSplitService.splitClip(
        sourceClip: selectedClip,
        splitPosition: splitPosition,
        onClipsCreated: (startClip, endClip) {
          add(
            ClipEditorOriginalClipReplaced(
              sourceClipId: selectedClip.id,
              startClip: startClip,
              endClip: endClip,
            ),
          );
        },
        onThumbnailExtracted: (clip, thumbnailPath) {
          add(
            ClipEditorClipUpdated(
              clipId: clip.id,
              clip: clip.copyWith(thumbnailPath: thumbnailPath),
            ),
          );
        },
        onClipRendered: (clip, video) {
          // Read the current clip from BLoC state to avoid
          // overwriting fields updated by earlier callbacks
          // (e.g. thumbnailPath from onThumbnailExtracted).
          final current = state.clips.where(
            (c) => c.id == clip.id,
          );
          final base = current.isNotEmpty ? current.first : clip;
          add(
            ClipEditorClipUpdated(
              clipId: clip.id,
              clip: base.copyWith(video: video),
            ),
          );
          Log.debug(
            '\u2705 Clip rendered: ${clip.id}',
            name: 'VideoClipEditorScreen',
            category: LogCategory.video,
          );
        },
      );

      onFinalClipInvalidated?.call();

      Log.info(
        '✅ Successfully split clip into 2 segments',
        name: 'ClipEditorBloc',
        category: LogCategory.video,
      );
    } catch (e, stackTrace) {
      addError(e, stackTrace);
      Log.error(
        '❌ Failed to split clip: $e',
        name: 'ClipEditorBloc',
        category: LogCategory.video,
      );
    }
  }

  // === TRIM ===

  void _onTrimUpdated(
    ClipEditorTrimUpdated event,
    Emitter<ClipEditorState> emit,
  ) {
    final index = state.clips.indexWhere((c) => c.id == event.clipId);
    if (index == -1) return;

    final clip = state.clips[index];
    final maxTrim = clip.duration - TimelineConstants.minTrimDuration;
    final clampedStart = event.trimStart < Duration.zero
        ? Duration.zero
        : event.trimStart > maxTrim - clip.trimEnd
        ? maxTrim - clip.trimEnd
        : event.trimStart;
    final clampedEnd = event.trimEnd < Duration.zero
        ? Duration.zero
        : event.trimEnd > maxTrim - clampedStart
        ? maxTrim - clampedStart
        : event.trimEnd;

    final base = event.isStart ? _pushUndo(state) : state;
    final newClips = List<DivineVideoClip>.of(base.clips);
    newClips[index] = newClips[index].copyWith(
      trimStart: clampedStart,
      trimEnd: clampedEnd,
    );

    emit(base.copyWith(clips: List.unmodifiable(newClips)));
  }

  void _onTrimDragStarted(
    ClipEditorTrimDragStarted event,
    Emitter<ClipEditorState> emit,
  ) {
    emit(state.copyWith(isTrimDragging: true));
  }

  void _onTrimDragEnded(
    ClipEditorTrimDragEnded event,
    Emitter<ClipEditorState> emit,
  ) {
    emit(state.copyWith(isTrimDragging: false));
  }
}
