import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/constants/video_editor_timeline_constants.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/services/video_editor/video_editor_split_service.dart';
import 'package:unified_logger/unified_logger.dart';

part 'clip_editor_event.dart';
part 'clip_editor_state.dart';

/// BLoC for managing video clip editor state.
///
/// Owns a local copy of the clip list so that all mutations (add, remove,
/// trim, split) happen in-memory without touching the Riverpod
/// [ClipManagerProvider]. The parent screen syncs the final clip list
/// back to the provider when the editor closes.
///
/// **Transition seam**: This BLoC receives its initial clip list from the
/// Riverpod [ClipManagerProvider] via [ClipEditorInitialized] dispatched in
/// the widget layer. This is an intentional migration boundary — the target
/// architecture replaces the Riverpod provider with a [VideoEditorRepository]
/// injected directly into this BLoC.
class ClipEditorBloc extends Bloc<ClipEditorEvent, ClipEditorState> {
  ClipEditorBloc({required void Function() this.onFinalClipInvalidated})
    : super(const ClipEditorState()) {
    // Clip data
    on<ClipEditorInitialized>(_onInitialized);
    on<ClipEditorClipRemoved>(_onClipRemoved);
    on<ClipEditorClipInserted>(_onClipInserted);
    on<ClipEditorClipUpdated>(_onClipUpdated);

    // Clip selection
    on<ClipEditorClipSelected>(_onClipSelected);

    // Editing mode
    on<ClipEditorEditingStarted>(_onEditingStarted);
    on<ClipEditorEditingStopped>(_onEditingStopped);
    on<ClipEditorEditingToggled>(_onEditingToggled);
    on<ClipEditorSplitPositionChanged>(_onSplitPositionChanged);

    // Split
    on<ClipEditorOriginalClipReplaced>(_onOriginalClipReplaced);
    on<ClipEditorSplitRequested>(_onSplitRequested, transformer: droppable());

    // Trim
    on<ClipEditorTrimUpdated>(_onTrimUpdated, transformer: restartable());
    on<ClipEditorTrimDragStarted>(_onTrimDragStarted);
    on<ClipEditorTrimDragEnded>(_onTrimDragEnded);
  }

  final void Function()? onFinalClipInvalidated;

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

    final newClips = List<DivineVideoClip>.of(state.clips)..removeAt(index);

    Log.debug(
      '🗑️ Removed clip ${event.clipId} (${newClips.length} remaining)',
      name: 'ClipEditorBloc',
      category: LogCategory.video,
    );

    emit(state.copyWith(clips: List.unmodifiable(newClips)));
  }

  void _onClipInserted(
    ClipEditorClipInserted event,
    Emitter<ClipEditorState> emit,
  ) {
    final newClips = List<DivineVideoClip>.of(state.clips)
      ..insert(event.index.clamp(0, state.clips.length), event.clip);

    Log.debug(
      '➕ Inserted clip ${event.clip.id} at index ${event.index}',
      name: 'ClipEditorBloc',
      category: LogCategory.video,
    );

    emit(state.copyWith(clips: List.unmodifiable(newClips)));
  }

  void _onClipUpdated(
    ClipEditorClipUpdated event,
    Emitter<ClipEditorState> emit,
  ) {
    final index = state.clips.indexWhere((c) => c.id == event.clipId);
    if (index == -1) return;

    final newClips = List<DivineVideoClip>.of(state.clips)
      ..[index] = event.clip;

    emit(state.copyWith(clips: List.unmodifiable(newClips)));
  }

  // === CLIP SELECTION ===

  void _onClipSelected(
    ClipEditorClipSelected event,
    Emitter<ClipEditorState> emit,
  ) {
    final clips = state.clips;
    if (event.index < 0 || event.index >= clips.length) return;

    Log.debug(
      '🎯 Selected clip ${event.index}',
      name: 'ClipEditorBloc',
      category: LogCategory.video,
    );
    emit(
      state.copyWith(
        currentClipIndex: event.index,
        splitPosition: Duration.zero,
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
    emit(state.copyWith(isEditing: false));
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
    emit(state.copyWith(splitPosition: event.position));
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

    final newClips = List<DivineVideoClip>.of(state.clips)
      ..[index] = event.startClip
      ..insert(index + 1, event.endClip);

    Log.debug(
      '✂️ Replaced ${event.sourceClipId} with '
      '${event.startClip.id} + ${event.endClip.id}',
      name: 'ClipEditorBloc',
      category: LogCategory.video,
    );

    emit(state.copyWith(clips: List.unmodifiable(newClips)));
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
    emit(state.copyWith(isEditing: false));

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
            name: 'ClipEditorBloc',
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

    final newClips = List<DivineVideoClip>.of(state.clips);
    newClips[index] = newClips[index].copyWith(
      trimStart: clampedStart,
      trimEnd: clampedEnd,
    );

    emit(state.copyWith(clips: List.unmodifiable(newClips)));
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
