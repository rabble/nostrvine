import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:models/models.dart' show AudioEvent;
import 'package:openvine/constants/video_editor_timeline_constants.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/observability/reportable_error.dart';
import 'package:openvine/services/audio_extraction_service.dart';
import 'package:openvine/services/video_editor/video_editor_reverse_service.dart';
import 'package:openvine/services/video_editor/video_editor_split_service.dart';
import 'package:openvine/services/video_editor/video_editor_transform_service.dart';
import 'package:pro_video_editor/pro_video_editor.dart'
    show EditorVideo, ExportTransform;
import 'package:unified_logger/unified_logger.dart';

part 'clip_editor_event.dart';
part 'clip_editor_state.dart';

/// Function signature matching [VideoEditorSplitService.splitClip], used as
/// an injectable seam so tests can swap in a pure-Dart fake that does not
/// touch `path_provider` or `pro_video_editor` plugins.
typedef SplitClipFn =
    Future<void> Function({
      required DivineVideoClip sourceClip,
      required Duration splitPosition,
      required void Function(
        DivineVideoClip startClip,
        DivineVideoClip endClip,
      )?
      onClipsCreated,
      required void Function(DivineVideoClip clip, String thumbnailPath)?
      onThumbnailExtracted,
      required void Function(DivineVideoClip clip, EditorVideo video)?
      onClipRendered,
    });

/// Function signature matching [VideoEditorReverseService.reverseClip], used as
/// an injectable seam so tests can swap in a pure-Dart fake.
typedef ReverseClipFn =
    Future<EditorVideo> Function({
      required DivineVideoClip sourceClip,
      required String renderId,
    });

/// Function signature matching [VideoEditorTransformService.transformClip],
/// used as an injectable seam so tests can swap in a pure-Dart fake.
typedef TransformClipFn =
    Future<EditorVideo> Function({
      required DivineVideoClip sourceClip,
      required ExportTransform transform,
      required String renderId,
    });

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
  ClipEditorBloc({
    required this.onFinalClipInvalidated,
    AudioExtractionService? audioExtractionService,
    SplitClipFn? splitClip,
    ReverseClipFn? reverseClip,
    TransformClipFn? transformClip,
  }) : _audioExtractionService =
           audioExtractionService ?? AudioExtractionService(),
       _splitClip = splitClip ?? VideoEditorSplitService.splitClip,
       _reverseClip = reverseClip ?? VideoEditorReverseService.reverseClip,
       _transformClip =
           transformClip ?? VideoEditorTransformService.transformClip,
       super(const ClipEditorState()) {
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

    // Audio extraction
    on<ClipEditorAudioExtractionRequested>(
      _onAudioExtractionRequested,
      transformer: droppable(),
    );

    // Reverse
    on<ClipEditorClipReverseRequested>(
      _onClipReverseRequested,
      transformer: droppable(),
    );

    // Transform (crop / rotate / flip)
    on<ClipEditorClipTransformRequested>(
      _onClipTransformRequested,
      transformer: droppable(),
    );

    // Volume
    on<ClipEditorClipVolumeChanged>(
      _onClipVolumeChanged,
      transformer: sequential(),
    );
    on<ClipEditorAllClipsVolumeChanged>(
      _onAllClipsVolumeChanged,
      transformer: sequential(),
    );
  }

  final void Function() onFinalClipInvalidated;
  final AudioExtractionService _audioExtractionService;
  final SplitClipFn _splitClip;
  final ReverseClipFn _reverseClip;
  final TransformClipFn _transformClip;

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
    final index = state.clips.indexWhere((c) => c.id == event.sourceClipId);
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
    emit(state.copyWith(isEditing: false, isSplitting: true));

    ClipSplitFailure? splitFailure;
    String? splitStartClipId;
    String? splitEndClipId;
    try {
      // Emit directly from callbacks instead of dispatching events.
      // Cross-event-type handlers run concurrently in BLoC, which
      // caused a race where ClipEditorClipUpdated (rendered video
      // file) was processed before ClipEditorOriginalClipReplaced
      // had inserted the new clip ids — the index lookup failed and
      // the clips kept pointing at the original source video.
      await _splitClip(
        sourceClip: selectedClip,
        splitPosition: splitPosition,
        onClipsCreated: (startClip, endClip) {
          splitStartClipId = startClip.id;
          splitEndClipId = endClip.id;

          // splitClip's render phase awaits Future.wait on parallel
          // video renders. If the bloc is closed mid-render (user
          // navigates away from the editor), the late callbacks fire
          // on a done emitter — guard each one.
          if (emit.isDone) return;
          final clips = state.clips;
          final index = clips.indexWhere((c) => c.id == selectedClip.id);
          if (index == -1) return;
          final newClips = List<DivineVideoClip>.of(clips)
            ..[index] = startClip
            ..insert(index + 1, endClip);
          emit(
            state.copyWith(
              clips: List.unmodifiable(newClips),
              lastSplit: ClipSplitEvent(
                sourceClipId: selectedClip.id,
                startClipId: startClip.id,
                endClipId: endClip.id,
                absoluteSplitPosition: selectedClip.trimStart + splitPosition,
                sourceDuration: selectedClip.duration,
                sourceTrimStart: selectedClip.trimStart,
                sourceTrimEnd: selectedClip.trimEnd,
              ),
            ),
          );
          Log.debug(
            '✂️ Replaced ${selectedClip.id} with '
            '${startClip.id} + ${endClip.id}',
            name: 'ClipEditorBloc',
            category: LogCategory.video,
          );
        },
        onThumbnailExtracted: (clip, thumbnailPath) {
          if (emit.isDone) return;
          final clips = state.clips;
          final index = clips.indexWhere((c) => c.id == clip.id);
          if (index == -1) return;
          final newClips = List<DivineVideoClip>.of(clips);
          newClips[index] = newClips[index].copyWith(
            thumbnailPath: thumbnailPath,
          );
          emit(state.copyWith(clips: List.unmodifiable(newClips)));
        },
        onClipRendered: (clip, video) {
          if (emit.isDone) return;
          final clips = state.clips;
          final index = clips.indexWhere((c) => c.id == clip.id);
          if (index == -1) return;
          final newClips = List<DivineVideoClip>.of(clips);
          newClips[index] = newClips[index].copyWith(
            video: video,
            duration: clip.duration,
            trimStart: clip.trimStart,
            trimEnd: clip.trimEnd,
          );
          emit(state.copyWith(clips: List.unmodifiable(newClips)));
          Log.debug(
            '\u2705 Clip rendered: ${clip.id}',
            name: 'ClipEditorBloc',
            category: LogCategory.video,
          );
        },
      );

      onFinalClipInvalidated.call();

      Log.info(
        '✅ Successfully split clip into 2 segments',
        name: 'ClipEditorBloc',
        category: LogCategory.video,
      );
    } catch (e, stackTrace) {
      // Matrix-NO: rethrown FFmpeg render exceptions, RenderCanceledException
      // (user nav-away mid-render), and file IO. ArgumentError from
      // VideoEditorSplitService is pre-validated by isValidSplitPosition at
      // line 259 above and cannot reach this catch.
      addError(e, stackTrace);
      Log.error(
        '❌ Failed to split clip: $e',
        name: 'ClipEditorBloc',
        category: LogCategory.video,
      );
      splitFailure = ClipSplitFailure();
    } finally {
      if (!emit.isDone) {
        final rollbackClips = splitFailure == null
            ? null
            : _clipsWithFailedSplitRolledBack(
                state.clips,
                sourceClip: selectedClip,
                startClipId: splitStartClipId,
                endClipId: splitEndClipId,
              );
        emit(
          state.copyWith(
            clips: rollbackClips,
            isSplitting: false,
            lastSplitFailure: splitFailure,
            clearLastSplit: splitFailure != null,
          ),
        );
      }
    }
  }

  List<DivineVideoClip>? _clipsWithFailedSplitRolledBack(
    List<DivineVideoClip> clips, {
    required DivineVideoClip sourceClip,
    required String? startClipId,
    required String? endClipId,
  }) {
    if (startClipId == null || endClipId == null) return null;

    final startIndex = clips.indexWhere((clip) => clip.id == startClipId);
    if (startIndex == -1 || startIndex + 1 >= clips.length) return null;
    if (clips[startIndex + 1].id != endClipId) return null;

    final restoredClips = List<DivineVideoClip>.of(clips)
      ..replaceRange(startIndex, startIndex + 2, [sourceClip]);
    return List.unmodifiable(restoredClips);
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

    // Position of the dragged handle within the clip's *untrimmed*
    // timeline (0..clip.duration). The preview player is switched to
    // a single-clip view of [event.clipId] for the duration of the
    // gesture, so seeking to this position lands on the correct frame.
    final trimPosition = event.isStart
        ? clampedStart
        : clip.duration - clampedEnd;

    emit(
      state.copyWith(
        clips: List.unmodifiable(newClips),
        trimPosition: trimPosition,
        trimmingClipId: event.clipId,
      ),
    );
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
    emit(
      state.copyWith(
        isTrimDragging: false,
        clearTrimPosition: true,
        clearTrimmingClipId: true,
      ),
    );
  }

  // === VOLUME ===

  void _onClipVolumeChanged(
    ClipEditorClipVolumeChanged event,
    Emitter<ClipEditorState> emit,
  ) {
    final index = state.clips.indexWhere((c) => c.id == event.clipId);
    if (index == -1) return;
    final nextVolume = event.volume.clamp(0.0, 1.0);
    if (state.clips[index].volume == nextVolume) return;
    final updated = List<DivineVideoClip>.of(state.clips);
    updated[index] = updated[index].copyWith(volume: nextVolume);
    emit(
      state.copyWith(
        clips: List.unmodifiable(updated),
        clipsVolumeRevision: state.clipsVolumeRevision + 1,
      ),
    );
  }

  void _onAllClipsVolumeChanged(
    ClipEditorAllClipsVolumeChanged event,
    Emitter<ClipEditorState> emit,
  ) {
    final nextVolume = event.volume.clamp(0.0, 1.0);
    if (state.clips.isEmpty) return;
    if (state.clips.every((c) => c.volume == nextVolume)) return;
    final updated = state.clips
        .map((c) => c.copyWith(volume: nextVolume))
        .toList(growable: false);
    emit(
      state.copyWith(
        clips: List.unmodifiable(updated),
        clipsVolumeRevision: state.clipsVolumeRevision + 1,
      ),
    );
  }

  // === REVERSE ===

  Future<void> _onClipReverseRequested(
    ClipEditorClipReverseRequested event,
    Emitter<ClipEditorState> emit,
  ) async {
    final index = state.clips.indexWhere((c) => c.id == event.clipId);
    if (index == -1) return;

    final clip = state.clips[index];
    final videoPath = clip.video.file?.path;

    if (videoPath == null) {
      Log.warning(
        '⚠️ Reverse skipped: clip ${clip.id} has no local file',
        name: 'ClipEditorBloc',
        category: LogCategory.video,
      );
      emit(state.copyWith(lastReverseResult: ClipReverseNoLocalFile()));
      return;
    }

    if (clip.reversed && clip.forwardVideoPath != null) {
      final restoredClip = clip.copyWith(
        video: EditorVideo.file(clip.forwardVideoPath),
        trimStart: clip.trimEnd,
        trimEnd: clip.trimStart,
        reversed: false,
      );
      final newClips = List<DivineVideoClip>.of(state.clips)
        ..[index] = restoredClip;
      emit(
        state.copyWith(
          clips: List.unmodifiable(newClips),
          lastReverseResult: ClipReverseSuccess(),
        ),
      );
      onFinalClipInvalidated.call();
      return;
    }

    if (!clip.reversed && clip.reversedVideoPath != null) {
      final restoredClip = clip.copyWith(
        video: EditorVideo.file(clip.reversedVideoPath),
        trimStart: clip.trimEnd,
        trimEnd: clip.trimStart,
        reversed: true,
      );
      final newClips = List<DivineVideoClip>.of(state.clips)
        ..[index] = restoredClip;
      emit(
        state.copyWith(
          clips: List.unmodifiable(newClips),
          lastReverseResult: ClipReverseSuccess(),
        ),
      );
      onFinalClipInvalidated.call();
      return;
    }

    emit(state.copyWith(isReversing: true, reversingClipId: clip.id));

    try {
      final reversedVideo = await _reverseClip(
        sourceClip: clip,
        renderId: clip.id,
      );

      final currentClips = state.clips;
      final currentIndex = currentClips.indexWhere((c) => c.id == clip.id);
      if (currentIndex == -1) {
        Log.warning(
          '⚠️ Reverse result discarded: clip ${clip.id} no longer exists',
          name: 'ClipEditorBloc',
          category: LogCategory.video,
        );
        emit(
          state.copyWith(
            isReversing: false,
            clearReversingClipId: true,
            lastReverseResult: ClipReverseDiscarded(),
          ),
        );
        return;
      }

      final currentClip = currentClips[currentIndex];

      // The render input (`videoPath`) holds content in the clip's current
      // direction (`clip.reversed`); the render output (`reversedVideo`) holds
      // the opposite. Assign each to its matching cache slot so the branch is
      // also correct when the input is already reversed — e.g. a duplicate or
      // split of a reversed clip, which preserves `reversed` but clears both
      // cache paths. Mapping by output direction instead would store forward
      // content as the reversed path (and vice versa), making every later
      // cached toggle play the wrong direction.
      final renderedPath = reversedVideo.file?.path;
      final String? forwardVideoPath;
      final String? reversedVideoPath;
      if (clip.reversed) {
        forwardVideoPath = renderedPath ?? currentClip.forwardVideoPath;
        reversedVideoPath = currentClip.reversedVideoPath ?? videoPath;
      } else {
        forwardVideoPath = currentClip.forwardVideoPath ?? videoPath;
        reversedVideoPath = renderedPath ?? currentClip.reversedVideoPath;
      }

      final updatedClip = currentClip.copyWith(
        video: reversedVideo,
        trimStart: currentClip.trimEnd,
        trimEnd: currentClip.trimStart,
        reversed: !clip.reversed,
        forwardVideoPath: forwardVideoPath,
        reversedVideoPath: reversedVideoPath,
      );
      final newClips = List<DivineVideoClip>.of(currentClips)
        ..[currentIndex] = updatedClip;

      emit(
        state.copyWith(
          clips: List.unmodifiable(newClips),
          isReversing: false,
          clearReversingClipId: true,
          lastReverseResult: ClipReverseSuccess(),
        ),
      );

      onFinalClipInvalidated.call();
    } catch (e, stackTrace) {
      final error = switch (e) {
        StateError() ||
        TypeError() ||
        RangeError() => Reportable(e, context: '_onClipReverseRequested'),
        _ => e,
      };
      addError(error, stackTrace);
      Log.error(
        '❌ Failed to reverse clip ${clip.id}: $e',
        name: 'ClipEditorBloc',
        category: LogCategory.video,
      );
      emit(
        state.copyWith(
          isReversing: false,
          clearReversingClipId: true,
          lastReverseResult: ClipReverseFailure(),
        ),
      );
    }
  }

  // === TRANSFORM ===

  Future<void> _onClipTransformRequested(
    ClipEditorClipTransformRequested event,
    Emitter<ClipEditorState> emit,
  ) async {
    final index = state.clips.indexWhere((c) => c.id == event.clipId);
    if (index == -1) return;

    final clip = state.clips[index];
    final videoPath = clip.video.file?.path;

    if (videoPath == null) {
      Log.warning(
        '⚠️ Transform skipped: clip ${clip.id} has no local file',
        name: 'ClipEditorBloc',
        category: LogCategory.video,
      );
      emit(state.copyWith(lastTransformResult: ClipTransformNoLocalFile()));
      return;
    }

    // Namespace the render id so a transform never shares an id with a
    // concurrent reverse render on the same clip — both would otherwise key on
    // clip.id, letting the transform's cancel() abort the in-flight reverse.
    final renderId = '${clip.id}_transform';
    emit(state.copyWith(isTransforming: true, transformingClipId: renderId));

    try {
      final transformedVideo = await _transformClip(
        sourceClip: clip,
        transform: event.transform,
        renderId: renderId,
      );

      final currentClips = state.clips;
      final currentIndex = currentClips.indexWhere((c) => c.id == clip.id);
      if (currentIndex == -1) {
        Log.warning(
          '⚠️ Transform result discarded: clip ${clip.id} no longer exists',
          name: 'ClipEditorBloc',
          category: LogCategory.video,
        );
        emit(
          state.copyWith(
            isTransforming: false,
            clearTransformingClipId: true,
            lastTransformResult: ClipTransformDiscarded(),
          ),
        );
        return;
      }

      // The transform bakes a new file from the clip's *current* video, so the
      // cached forward/reversed paths now point at stale (pre-transform)
      // files — clear them so a later reverse re-renders from the transformed
      // source instead of restoring untransformed content.
      final updatedClip = currentClips[currentIndex].copyWith(
        video: transformedVideo,
        clearForwardVideoPath: true,
        clearReversedVideoPath: true,
      );
      final newClips = List<DivineVideoClip>.of(currentClips)
        ..[currentIndex] = updatedClip;

      emit(
        state.copyWith(
          clips: List.unmodifiable(newClips),
          isTransforming: false,
          clearTransformingClipId: true,
          lastTransformResult: ClipTransformSuccess(),
        ),
      );

      onFinalClipInvalidated.call();
    } catch (e, stackTrace) {
      final error = switch (e) {
        StateError() ||
        TypeError() ||
        RangeError() => Reportable(e, context: '_onClipTransformRequested'),
        _ => e,
      };
      addError(error, stackTrace);
      Log.error(
        '❌ Failed to transform clip ${clip.id}: $e',
        name: 'ClipEditorBloc',
        category: LogCategory.video,
      );
      emit(
        state.copyWith(
          isTransforming: false,
          clearTransformingClipId: true,
          lastTransformResult: ClipTransformFailure(),
        ),
      );
    }
  }

  // === AUDIO EXTRACTION ===

  Future<void> _onAudioExtractionRequested(
    ClipEditorAudioExtractionRequested event,
    Emitter<ClipEditorState> emit,
  ) async {
    final clips = state.clips;
    if (state.currentClipIndex >= clips.length) return;

    final clip = clips[state.currentClipIndex];
    final videoPath = clip.video.file?.path;
    final extractionSpeed = _effectiveAudioExtractionSpeed(clip);

    if (videoPath == null) {
      Log.warning(
        '⚠️ Audio extraction skipped: clip ${clip.id} has no local file',
        name: 'ClipEditorBloc',
        category: LogCategory.video,
      );
      emit(
        state.copyWith(lastAudioExtraction: ClipAudioExtractionNoLocalFile()),
      );
      return;
    }

    emit(state.copyWith(isExtractingAudio: true));

    try {
      final result = await _audioExtractionService.extractAudio(
        videoPath: videoPath,
        speed: extractionSpeed,
      );

      // Reconcile against current state after the async gap.
      // Other event handlers (remove, split, insert) may have mutated
      // the clip list while extraction was running. Using the pre-await
      // snapshot would overwrite newer state or resurrect deleted clips.
      final currentClips = state.clips;
      final currentIndex = currentClips.indexWhere((c) => c.id == clip.id);
      if (currentIndex == -1) {
        // Source clip was removed while extraction was in progress —
        // discard the result to avoid resurrecting a deleted clip.
        Log.warning(
          '⚠️ Audio extraction result discarded: clip ${clip.id} '
          'no longer exists in the timeline',
          name: 'ClipEditorBloc',
          category: LogCategory.video,
        );
        await _cleanupDiscardedAudioExtraction(result.audioFilePath);
        emit(
          state.copyWith(
            isExtractingAudio: false,
            lastAudioExtraction: ClipAudioExtractionDiscarded(),
          ),
        );
        return;
      }

      final currentClip = currentClips[currentIndex];
      final currentVideoPath = currentClip.video.file?.path;
      final currentExtractionSpeed = _effectiveAudioExtractionSpeed(
        currentClip,
      );
      if (currentVideoPath != videoPath ||
          currentExtractionSpeed != extractionSpeed) {
        Log.warning(
          '⚠️ Audio extraction result discarded: clip ${clip.id} source '
          'changed while extraction was running',
          name: 'ClipEditorBloc',
          category: LogCategory.video,
        );
        await _cleanupDiscardedAudioExtraction(result.audioFilePath);
        emit(
          state.copyWith(
            isExtractingAudio: false,
            lastAudioExtraction: ClipAudioExtractionDiscarded(),
          ),
        );
        return;
      }

      // Recompute absolute start from current state so clips inserted
      // or removed before this one are accounted for.
      var clipStart = Duration.zero;
      for (var i = 0; i < currentIndex; i++) {
        clipStart += currentClips[i].playbackDuration;
      }

      final audioEvent = AudioEvent(
        id: 'local_extracted_${DateTime.now().microsecondsSinceEpoch}',
        pubkey: '',
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        url: result.audioFilePath,
        mimeType: result.mimeType,
        sha256: result.sha256Hash,
        fileSize: result.fileSize,
        duration: result.duration,
        title: event.clipTitle,
        startOffset: currentClip.sourceDurationToPlaybackDuration(
          currentClip.trimStart,
        ),
        startTime: clipStart,
        endTime: clipStart + currentClip.playbackDuration,
        // Anchor the extracted audio to its source clip so it follows the
        // clip's trims (J-Cut) until the user manually moves it.
        anchorClipId: currentClip.id,
      );

      // Mute the source clip now that its audio has been extracted.
      final newClips = List<DivineVideoClip>.of(currentClips)
        ..[currentIndex] = currentClip.copyWith(volume: 0);

      Log.info(
        '🎵 Audio extracted for clip ${currentClip.id}',
        name: 'ClipEditorBloc',
        category: LogCategory.video,
      );

      emit(
        state.copyWith(
          clips: List.unmodifiable(newClips),
          isExtractingAudio: false,
          lastAudioExtraction: ClipAudioExtractionSuccess(
            audioEvent: audioEvent,
          ),
        ),
      );
    } on AudioExtractionException catch (e, stackTrace) {
      Log.error(
        '❌ Audio extraction failed: ${e.message}',
        name: 'ClipEditorBloc',
        error: e,
        stackTrace: stackTrace,
        category: LogCategory.video,
      );
      // Matrix-NO: AudioExtractionException is the typed expected failure
      // (Network/IO — FFmpeg + file IO).
      addError(e, stackTrace);
      emit(
        state.copyWith(
          isExtractingAudio: false,
          lastAudioExtraction: ClipAudioExtractionFailure(),
        ),
      );
    } catch (e, stackTrace) {
      Log.error(
        '❌ Unexpected error during audio extraction: $e',
        name: 'ClipEditorBloc',
        error: e,
        stackTrace: stackTrace,
        category: LogCategory.video,
      );
      addError(
        Reportable(e, context: '_onAudioExtractionRequested'),
        stackTrace,
      );
      emit(
        state.copyWith(
          isExtractingAudio: false,
          lastAudioExtraction: ClipAudioExtractionFailure(),
        ),
      );
    }
  }

  double _effectiveAudioExtractionSpeed(DivineVideoClip clip) {
    final speed = clip.playbackSpeed;
    return speed != null && speed > 0 ? speed : 1.0;
  }

  Future<void> _cleanupDiscardedAudioExtraction(String audioFilePath) async {
    try {
      await _audioExtractionService.cleanupAudioFile(audioFilePath);
    } catch (e) {
      Log.warning(
        '⚠️ Failed to cleanup discarded extracted audio: $e',
        name: 'ClipEditorBloc',
        category: LogCategory.video,
      );
    }
  }
}
