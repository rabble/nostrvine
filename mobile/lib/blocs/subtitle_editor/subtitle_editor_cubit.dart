// ABOUTME: Cubit that orchestrates the subtitle-editor flow: load cues,
// ABOUTME: allow text edits, and publish the updated subtitle track.

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:models/models.dart';
import 'package:openvine/repositories/subtitle_repository.dart';
import 'package:openvine/services/subtitle_fetcher.dart';
import 'package:openvine/services/subtitle_service.dart';

part 'subtitle_editor_state.dart';

/// Manages the subtitle-editing lifecycle for a single video.
class SubtitleEditorCubit extends Cubit<SubtitleEditorState> {
  /// Creates the cubit with the [repository] and the [video] being edited.
  SubtitleEditorCubit({
    required SubtitleRepository repository,
    required VideoEvent video,
  }) : _repository = repository,
       _video = video,
       super(const SubtitleEditorState());

  /// How long a hand-authored cue runs before the creator adjusts it.
  static const _newCueDurationMs = 2000;

  final SubtitleRepository _repository;
  final VideoEvent _video;

  /// Loads existing subtitle cues for the video.
  ///
  /// Emits [SubtitleEditorStatus.loading] then either:
  /// - [SubtitleEditorStatus.ready] with cues when they are available.
  /// - [SubtitleEditorStatus.processing] when transcription is still running.
  /// - [SubtitleEditorStatus.empty] when transcription finished but found
  ///   nothing to transcribe.
  /// - [SubtitleEditorStatus.unavailable] when no source held a track.
  /// - [SubtitleEditorStatus.failure] and calls [addError] on any exception.
  Future<void> load() async {
    if (isClosed) return;
    emit(state.copyWith(status: SubtitleEditorStatus.loading));
    try {
      final result = await _repository.loadCues(_video);
      if (isClosed) return;
      switch (result.status) {
        case SubtitleFetchStatus.available:
          emit(
            state.copyWith(
              status: SubtitleEditorStatus.ready,
              cues: result.cues.map(EditableCue.fromCue).toList(),
              isDirty: false,
            ),
          );
        case SubtitleFetchStatus.processing:
          emit(state.copyWith(status: SubtitleEditorStatus.processing));
        case SubtitleFetchStatus.empty:
          emit(state.copyWith(status: SubtitleEditorStatus.empty));
        case SubtitleFetchStatus.unavailable:
          emit(state.copyWith(status: SubtitleEditorStatus.unavailable));
      }
    } catch (e, st) {
      if (isClosed) return;
      addError(e, st);
      emit(state.copyWith(status: SubtitleEditorStatus.failure));
    }
  }

  /// Whether an edit must be dropped: the cubit is gone, or a publish is in
  /// flight. Editing mid-publish would clear the busy state and let a second
  /// save start on top of the first.
  bool get _rejectsEdits =>
      isClosed || state.status == SubtitleEditorStatus.saving;

  /// Replaces the text of the cue at [index] with [text] and marks the
  /// state as dirty.
  ///
  /// Out-of-range indices are silently ignored, as are edits made while a
  /// save is in flight.
  void updateCueText(int index, String text) =>
      _replaceCue(index, (cue) => cue.copyWith(text: text));

  /// Replaces the timing of the cue at [index], in milliseconds.
  ///
  /// Leaves a bound untouched when it is `null`. Out-of-range indices are
  /// silently ignored, as are edits made while a save is in flight. Timings
  /// are not validated here so the creator can type through an intermediate
  /// state; [SubtitleEditorState.isValid] gates the save instead.
  void updateCueTiming(int index, {int? start, int? end}) =>
      _replaceCue(index, (cue) => cue.copyWith(start: start, end: end));

  /// Appends a blank cue after the last one and switches to editing.
  ///
  /// The new cue starts where the previous one ends and runs for
  /// [_newCueDurationMs], trimmed to the video's end when its duration is
  /// known. This is the entry point for authoring captions on a video that
  /// has none. Ignored while a save is in flight.
  void addCue() {
    if (_rejectsEdits) return;
    final start = state.cues.isEmpty ? 0 : state.cues.last.end;
    final videoEndMs = (_video.duration ?? 0) * Duration.millisecondsPerSecond;
    var end = start + _newCueDurationMs;
    if (videoEndMs > start && end > videoEndMs) end = videoEndMs;

    emit(
      state.copyWith(
        status: SubtitleEditorStatus.ready,
        cues: [
          ...state.cues,
          EditableCue(start: start, end: end, text: ''),
        ],
        isDirty: true,
      ),
    );
  }

  /// Removes the cue at [index].
  ///
  /// Out-of-range indices are silently ignored, as are removals made while a
  /// save is in flight.
  void removeCue(int index) {
    if (_rejectsEdits) return;
    if (index < 0 || index >= state.cues.length) return;
    final updated = List<EditableCue>.from(state.cues)..removeAt(index);
    emit(state.copyWith(cues: updated, isDirty: true));
  }

  void _replaceCue(int index, EditableCue Function(EditableCue cue) update) {
    if (_rejectsEdits) return;
    if (index < 0 || index >= state.cues.length) return;
    final updated = List<EditableCue>.from(state.cues);
    updated[index] = update(updated[index]);
    emit(state.copyWith(cues: updated, isDirty: true));
  }

  /// Publishes the current cues via the repository.
  ///
  /// Cues are published in timeline order — hand-edited timings can leave the
  /// list out of order, and VTT readers expect ascending cues.
  ///
  /// Emits [SubtitleEditorStatus.saving] then either:
  /// - [SubtitleEditorStatus.success] with `isDirty` reset to `false`.
  /// - [SubtitleEditorStatus.failure] and calls [addError] on any exception.
  Future<void> save() async {
    if (isClosed) return;
    emit(state.copyWith(status: SubtitleEditorStatus.saving));
    try {
      final ordered = List<EditableCue>.from(state.cues)
        ..sort((a, b) => a.start.compareTo(b.start));
      final updatedVideo = await _repository.publishEditedSubtitles(
        video: _video,
        cues: ordered.map((c) => c.toCue()).toList(),
      );
      if (isClosed) return;
      emit(
        state.copyWith(
          status: SubtitleEditorStatus.success,
          isDirty: false,
          updatedVideo: updatedVideo,
        ),
      );
    } catch (e, st) {
      if (isClosed) return;
      addError(e, st);
      emit(state.copyWith(status: SubtitleEditorStatus.failure));
    }
  }
}
