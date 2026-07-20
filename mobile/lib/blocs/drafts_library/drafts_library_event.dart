// ABOUTME: Events for DraftsLibraryBloc - managing draft video projects
// ABOUTME: Supports loading, duplicating, and deleting drafts from the library

part of 'drafts_library_bloc.dart';

/// Base class for all drafts library events.
sealed class DraftsLibraryEvent extends Equatable {
  const DraftsLibraryEvent();

  @override
  List<Object?> get props => [];
}

/// Event to load all drafts from storage.
final class DraftsLibraryLoadRequested extends DraftsLibraryEvent {
  const DraftsLibraryLoadRequested();
}

/// Base class for events that mutate the persisted draft list (duplicate,
/// delete).
///
/// These share a single `sequential()` queue in [DraftsLibraryBloc] so their
/// handlers never interleave: each reads the current list, awaits a storage
/// write, then emits the updated list. Registering them in separate buckets
/// would let a delete complete mid-duplicate (or vice versa) and emit a stale
/// snapshot that resurrects a deleted draft or drops a fresh copy.
sealed class DraftsLibraryMutationEvent extends DraftsLibraryEvent {
  const DraftsLibraryMutationEvent();
}

/// Event to duplicate a specific draft into a new independent project.
final class DraftsLibraryDuplicateRequested extends DraftsLibraryMutationEvent {
  const DraftsLibraryDuplicateRequested(this.draftId, {this.newTitle});

  /// The ID of the draft to duplicate.
  final String draftId;

  /// Title for the copy. When null, the original title is kept.
  final String? newTitle;

  @override
  List<Object?> get props => [draftId, newTitle];
}

/// Event to delete a specific draft.
final class DraftsLibraryDeleteRequested extends DraftsLibraryMutationEvent {
  const DraftsLibraryDeleteRequested(this.draftId);

  /// The ID of the draft to delete.
  final String draftId;

  @override
  List<Object?> get props => [draftId];
}
