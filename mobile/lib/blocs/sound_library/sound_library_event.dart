// ABOUTME: Events for the SoundLibraryBloc.
// ABOUTME: Defines provider load, provider switch, query change, and pagination.

part of 'sound_library_bloc.dart';

/// Base class for all sound-library events.
sealed class SoundLibraryEvent extends Equatable {
  const SoundLibraryEvent();

  @override
  List<Object?> get props => [];
}

/// Request to load the list of available proxy providers.
final class SoundLibraryProvidersRequested extends SoundLibraryEvent {
  const SoundLibraryProvidersRequested();
}

/// User selected a different provider (divine / nostr / freesound / …).
final class SoundLibraryProviderSelected extends SoundLibraryEvent {
  const SoundLibraryProviderSelected(this.provider);

  final String provider;

  @override
  List<Object?> get props => [provider];
}

/// The search query string changed.
///
/// Empty / whitespace-only queries reset the search to initial state.
final class SoundLibraryQueryChanged extends SoundLibraryEvent {
  const SoundLibraryQueryChanged(this.query);

  final String query;

  @override
  List<Object?> get props => [query];
}

/// Request to fetch the next page of search results.
final class SoundLibraryPageRequested extends SoundLibraryEvent {
  const SoundLibraryPageRequested();
}

/// Clear the current search query and results.
final class SoundLibrarySearchCleared extends SoundLibraryEvent {
  const SoundLibrarySearchCleared();
}
