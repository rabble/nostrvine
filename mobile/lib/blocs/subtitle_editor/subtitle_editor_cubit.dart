// ABOUTME: Cubit that orchestrates the subtitle-editor flow: load cues,
// ABOUTME: allow text edits, and publish the updated subtitle track.

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:models/models.dart';
import 'package:openvine/repositories/subtitle_repository.dart';
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

  final SubtitleRepository _repository;
  final VideoEvent _video;

  /// Loads existing subtitle cues for the video.
  ///
  /// Emits [SubtitleEditorStatus.loading] then either:
  /// - [SubtitleEditorStatus.ready] with cues when they are available.
  /// - [SubtitleEditorStatus.processing] when no cues are available yet.
  /// - [SubtitleEditorStatus.failure] and calls [addError] on any exception.
  Future<void> load() async {
    emit(state.copyWith(status: SubtitleEditorStatus.loading));
    try {
      final cues = await _repository.loadCues(_video);
      if (cues.isEmpty) {
        emit(state.copyWith(status: SubtitleEditorStatus.processing));
        return;
      }
      emit(
        state.copyWith(
          status: SubtitleEditorStatus.ready,
          cues: cues.map(EditableCue.fromCue).toList(),
          isDirty: false,
        ),
      );
    } catch (e, st) {
      addError(e, st);
      emit(state.copyWith(status: SubtitleEditorStatus.failure));
    }
  }

  /// Replaces the text of the cue at [index] with [text] and marks the
  /// state as dirty.
  ///
  /// Out-of-range indices are silently ignored.
  void updateCueText(int index, String text) {
    if (index < 0 || index >= state.cues.length) return;
    final updated = List<EditableCue>.from(state.cues);
    updated[index] = updated[index].copyWith(text: text);
    emit(state.copyWith(cues: updated, isDirty: true));
  }

  /// Publishes the current cues via the repository.
  ///
  /// Emits [SubtitleEditorStatus.saving] then either:
  /// - [SubtitleEditorStatus.success] with `isDirty` reset to `false`.
  /// - [SubtitleEditorStatus.failure] and calls [addError] on any exception.
  Future<void> save() async {
    emit(state.copyWith(status: SubtitleEditorStatus.saving));
    try {
      await _repository.publishEditedSubtitles(
        video: _video,
        cues: state.cues.map((c) => c.toCue()).toList(),
      );
      emit(
        state.copyWith(
          status: SubtitleEditorStatus.success,
          isDirty: false,
        ),
      );
    } catch (e, st) {
      addError(e, st);
      emit(state.copyWith(status: SubtitleEditorStatus.failure));
    }
  }
}
