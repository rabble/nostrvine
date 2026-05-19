// ABOUTME: BLoC for the proxy-backed external sound library search feature.
// ABOUTME: Loads provider options and runs paged search queries via SoundsRepository.

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:models/models.dart' show AudioEvent;
import 'package:sounds_repository/sounds_repository.dart';

part 'sound_library_event.dart';
part 'sound_library_state.dart';

/// BLoC for searching the proxy-backed sound library.
///
/// Fetches the available providers (divine / nostr / freesound / openverse)
/// on init and runs paged search queries. All composition / source-selection
/// lives in [SoundsRepository]; this BLoC just maps user intent to repository
/// calls and surfaces results via state status.
class SoundLibraryBloc extends Bloc<SoundLibraryEvent, SoundLibraryState> {
  SoundLibraryBloc({required SoundsRepository soundsRepository})
    : _soundsRepository = soundsRepository,
      super(const SoundLibraryState()) {
    on<SoundLibraryProvidersRequested>(_onProvidersRequested);
    on<SoundLibraryProviderSelected>(_onProviderSelected);
    on<SoundLibraryQueryChanged>(
      _onQueryChanged,
      transformer: restartable(),
    );
    on<SoundLibraryPageRequested>(
      _onPageRequested,
      transformer: droppable(),
    );
    on<SoundLibrarySearchCleared>(_onSearchCleared);
  }

  final SoundsRepository _soundsRepository;

  Future<void> _onProvidersRequested(
    SoundLibraryProvidersRequested event,
    Emitter<SoundLibraryState> emit,
  ) async {
    if (state.providersStatus == SoundLibraryProvidersStatus.loading) return;

    emit(
      state.copyWith(providersStatus: SoundLibraryProvidersStatus.loading),
    );

    try {
      final providers = await _soundsRepository.fetchExternalProviders();
      emit(
        state.copyWith(
          providersStatus: SoundLibraryProvidersStatus.loaded,
          providers: providers,
        ),
      );
    } catch (e, stackTrace) {
      addError(e, stackTrace);
      emit(
        state.copyWith(providersStatus: SoundLibraryProvidersStatus.failure),
      );
    }
  }

  void _onProviderSelected(
    SoundLibraryProviderSelected event,
    Emitter<SoundLibraryState> emit,
  ) {
    if (event.provider == state.selectedProvider) return;
    emit(
      state.copyWith(
        selectedProvider: event.provider,
        searchStatus: SoundLibrarySearchStatus.initial,
        sounds: const [],
        page: 1,
        clearNextPage: true,
      ),
    );
  }

  Future<void> _onQueryChanged(
    SoundLibraryQueryChanged event,
    Emitter<SoundLibraryState> emit,
  ) async {
    final trimmedQuery = event.query.trim();
    if (trimmedQuery.isEmpty) {
      emit(
        state.copyWith(
          query: '',
          searchStatus: SoundLibrarySearchStatus.initial,
          sounds: const [],
          page: 1,
          clearNextPage: true,
        ),
      );
      return;
    }

    emit(
      state.copyWith(
        query: trimmedQuery,
        searchStatus: SoundLibrarySearchStatus.loading,
        sounds: const [],
        page: 1,
        clearNextPage: true,
      ),
    );

    await _runSearch(
      emit,
      query: trimmedQuery,
      provider: state.selectedProvider,
      page: 1,
      append: false,
    );
  }

  Future<void> _onPageRequested(
    SoundLibraryPageRequested event,
    Emitter<SoundLibraryState> emit,
  ) async {
    final nextPage = state.nextPage;
    if (nextPage == null) return;
    if (state.query.isEmpty) return;
    if (state.searchStatus == SoundLibrarySearchStatus.loadingMore) return;

    emit(state.copyWith(searchStatus: SoundLibrarySearchStatus.loadingMore));

    await _runSearch(
      emit,
      query: state.query,
      provider: state.selectedProvider,
      page: nextPage,
      append: true,
    );
  }

  void _onSearchCleared(
    SoundLibrarySearchCleared event,
    Emitter<SoundLibraryState> emit,
  ) {
    emit(
      state.copyWith(
        query: '',
        searchStatus: SoundLibrarySearchStatus.initial,
        sounds: const [],
        page: 1,
        clearNextPage: true,
      ),
    );
  }

  Future<void> _runSearch(
    Emitter<SoundLibraryState> emit, {
    required String query,
    required String provider,
    required int page,
    required bool append,
  }) async {
    try {
      final response = await _soundsRepository.searchExternalLibrary(
        SoundLibrarySearchRequest(
          query: query,
          provider: provider,
          page: page,
          pageSize: state.pageSize,
        ),
      );
      emit(
        state.copyWith(
          searchStatus: SoundLibrarySearchStatus.loaded,
          sounds: append
              ? <AudioEvent>[...state.sounds, ...response.sounds]
              : response.sounds,
          page: page,
          nextPage: response.nextPage,
          clearNextPage: response.nextPage == null,
          count: response.count,
        ),
      );
    } catch (e, stackTrace) {
      addError(e, stackTrace);
      emit(state.copyWith(searchStatus: SoundLibrarySearchStatus.failure));
    }
  }
}
