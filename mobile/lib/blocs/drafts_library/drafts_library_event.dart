// ABOUTME: Events for DraftsLibraryBloc - managing draft video projects
// ABOUTME: Supports loading, and deleting drafts from the library

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

/// Event to delete a specific draft.
final class DraftsLibraryDeleteRequested extends DraftsLibraryEvent {
  const DraftsLibraryDeleteRequested(this.draftId);

  /// The ID of the draft to delete.
  final String draftId;

  @override
  List<Object?> get props => [draftId];
}
