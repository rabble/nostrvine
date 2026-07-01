// ABOUTME: Screen-scoped Cubit for the "Help classify this" content-warning
// ABOUTME: suggestion flow (#4771). Publishes viewer-suggested kind 1985 labels.

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/community_suggest/community_suggest_state.dart';
import 'package:openvine/models/content_label.dart';
import 'package:openvine/repositories/community_content_label_repository.dart';

/// Cubit backing the community content-warning suggestion sheet.
///
/// Loads the viewer's existing suggestions for a video, tracks the labels they
/// select, and publishes the suggestion via
/// [CommunityContentLabelRepository]. Errors are reported via [addError] and
/// surfaced to the UI as a [CommunitySuggestStatus.failure] status — never as
/// error strings in state.
class CommunitySuggestCubit extends Cubit<CommunitySuggestState> {
  /// Creates the cubit for a specific [video] and the current viewer's
  /// [myPubkey].
  CommunitySuggestCubit({
    required CommunityContentLabelRepository repository,
    required VideoEvent video,
    required String myPubkey,
  }) : _repository = repository,
       _video = video,
       _myPubkey = myPubkey,
       super(const CommunitySuggestState());

  final CommunityContentLabelRepository _repository;
  final VideoEvent _video;
  final String _myPubkey;

  /// Loads the labels the viewer has already suggested for this video.
  Future<void> loadExisting() async {
    emit(state.copyWith(status: CommunitySuggestStatus.loading));
    try {
      final existing = await _repository.mySuggestedLabels(_video, _myPubkey);
      emit(
        state.copyWith(
          status: CommunitySuggestStatus.ready,
          alreadySuggested: existing,
        ),
      );
    } catch (e, stackTrace) {
      addError(e, stackTrace);
      emit(state.copyWith(status: CommunitySuggestStatus.failure));
    }
  }

  /// Toggles selection of [label]. Labels already suggested cannot be
  /// re-selected (NIP-32 has no un-vote).
  void toggle(ContentLabel label) {
    if (state.alreadySuggested.contains(label.value)) return;
    final selected = Set<ContentLabel>.of(state.selected);
    if (!selected.add(label)) {
      selected.remove(label);
    }
    emit(
      state.copyWith(
        status: CommunitySuggestStatus.ready,
        selected: selected,
      ),
    );
  }

  /// Publishes the selected labels as a community suggestion.
  Future<void> submit() async {
    if (state.selected.isEmpty) return;
    emit(state.copyWith(status: CommunitySuggestStatus.submitting));
    try {
      await _repository.suggestLabels(video: _video, labels: state.selected);
      emit(
        state.copyWith(
          status: CommunitySuggestStatus.success,
          alreadySuggested: {
            ...state.alreadySuggested,
            ...state.selected.map((label) => label.value),
          },
          selected: const {},
        ),
      );
    } catch (e, stackTrace) {
      addError(e, stackTrace);
      emit(state.copyWith(status: CommunitySuggestStatus.failure));
    }
  }
}
