// ABOUTME: BLoC for searching curated video lists (kind 30005).
// ABOUTME: Streams local + relay results progressively via CuratedListRepository.

import 'package:curated_list_repository/curated_list_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:models/models.dart';
import 'package:openvine/constants/search_constants.dart';

part 'list_search_event.dart';
part 'list_search_state.dart';

/// BLoC for searching curated video lists (kind 30005).
///
/// Delegates to [CuratedListRepository.searchAllLists] which yields local
/// results first, then progressively merges relay results.
class ListSearchBloc extends Bloc<ListSearchEvent, ListSearchState> {
  ListSearchBloc({
    required CuratedListRepository curatedListRepository,
  }) : _curatedListRepository = curatedListRepository,
       super(const ListSearchState()) {
    on<ListSearchQueryChanged>(
      _onQueryChanged,
      transformer: debounceRestartable(),
    );
    on<ListSearchCleared>(_onCleared);
  }

  final CuratedListRepository _curatedListRepository;

  Future<void> _onQueryChanged(
    ListSearchQueryChanged event,
    Emitter<ListSearchState> emit,
  ) async {
    final query = event.query.trim();

    if (query.isEmpty || query.length < minSearchQueryLength) {
      emit(const ListSearchState());
      return;
    }

    if (query == state.query &&
        state.status != ListSearchStatus.initial &&
        state.status != ListSearchStatus.failure) {
      return;
    }

    emit(state.copyWith(status: ListSearchStatus.loading, query: query));

    try {
      await emit.forEach(
        _curatedListRepository.searchAllLists(query),
        onData: (results) => state.copyWith(
          status: ListSearchStatus.success,
          results: results,
        ),
      );

      // If stream completes without emitting, still emit success
      if (state.status == ListSearchStatus.loading) {
        emit(
          state.copyWith(
            status: ListSearchStatus.success,
            results: const [],
          ),
        );
      }
    } on Exception catch (e, stackTrace) {
      addError(e, stackTrace);
      emit(state.copyWith(status: ListSearchStatus.failure));
    }
  }

  void _onCleared(
    ListSearchCleared event,
    Emitter<ListSearchState> emit,
  ) {
    emit(const ListSearchState());
  }
}
