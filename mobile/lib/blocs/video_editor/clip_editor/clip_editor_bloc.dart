import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/services/video_editor/video_editor_split_service.dart';
import 'package:openvine/utils/unified_logger.dart';

part 'clip_editor_event.dart';
part 'clip_editor_state.dart';

/// Signature for a function that returns the current list of clips.
typedef ClipsGetter = List<DivineVideoClip> Function();

/// Callback that executes the clip split operation and post-split
/// side effects (clip manager mutations, rendered clip invalidation,
/// autosave). Receives the source clip, split position, and clip index.
typedef SplitExecutor =
    Future<void> Function({
      required DivineVideoClip sourceClip,
      required Duration splitPosition,
      required int currentClipIndex,
    });

/// BLoC for managing video clip editor playback, editing mode,
/// clip selection, and reorder state.
///
/// Handles:
/// - Playback control (play/pause, mute, position tracking)
/// - Clip selection and navigation
/// - Editing mode (split position, enter/exit)
/// - Clip reordering mode and delete zone tracking
/// - Clip splitting (delegated via [SplitExecutor])
class ClipEditorBloc extends Bloc<ClipEditorEvent, ClipEditorState> {
  ClipEditorBloc({
    required ClipsGetter clipsGetter,
    SplitExecutor? splitExecutor,
  }) : _clipsGetter = clipsGetter,
       _splitExecutor = splitExecutor,
       super(const ClipEditorState()) {
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
    on<ClipEditorSplitRequested>(_onSplitRequested);
  }

  final ClipsGetter _clipsGetter;
  final SplitExecutor? _splitExecutor;

  // === CLIP SELECTION ===

  void _onClipSelected(
    ClipEditorClipSelected event,
    Emitter<ClipEditorState> emit,
  ) {
    final clips = _clipsGetter();
    if (event.index < 0 || event.index >= clips.length) return;

    final offset = clips
        .take(event.index)
        .fold(Duration.zero, (sum, clip) => sum + clip.duration);

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
    final clips = _clipsGetter();

    // Ignore stale position updates from previous clip's controller
    if (state.currentClipIndex >= clips.length ||
        event.clipId != clips[state.currentClipIndex].id) {
      return;
    }

    final offset = state.isEditing
        ? Duration.zero
        : clips
              .take(state.currentClipIndex)
              .fold(Duration.zero, (sum, clip) => sum + clip.duration);

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
    final clips = _clipsGetter();
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
        splitPosition: clips[state.currentClipIndex].duration ~/ 2,
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
    if (state.isOverDeleteZone != event.isOver) {
      Log.debug(
        event.isOver
            ? '🗑️  Clip over delete zone'
            : '⬅️  Clip left delete zone',
        name: 'ClipEditorBloc',
        category: LogCategory.video,
      );
    }
    emit(state.copyWith(isOverDeleteZone: event.isOver));
  }

  // === SPLIT ===

  Future<void> _onSplitRequested(
    ClipEditorSplitRequested event,
    Emitter<ClipEditorState> emit,
  ) async {
    final clips = _clipsGetter();
    if (state.currentClipIndex >= clips.length) return;

    final selectedClip = clips[state.currentClipIndex];
    final splitPosition = state.splitPosition;
    final currentClipIndex = state.currentClipIndex;

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

    if (_splitExecutor == null) return;

    try {
      await _splitExecutor(
        sourceClip: selectedClip,
        splitPosition: splitPosition,
        currentClipIndex: currentClipIndex,
      );

      Log.info(
        '✅ Successfully split clip into 2 segments',
        name: 'ClipEditorBloc',
        category: LogCategory.video,
      );
    } catch (e) {
      Log.error(
        '❌ Failed to split clip: $e',
        name: 'ClipEditorBloc',
        category: LogCategory.video,
      );
    }
  }
}
