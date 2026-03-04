// ABOUTME: States for DraftsLibraryBloc - managing draft video projects
// ABOUTME: Supports loading, loaded, and error states for draft management

part of 'drafts_library_bloc.dart';

/// Base class for all drafts library states.
sealed class DraftsLibraryState extends Equatable {
  const DraftsLibraryState();

  @override
  List<Object?> get props => [];
}

/// Initial state before drafts have been loaded.
final class DraftsLibraryInitial extends DraftsLibraryState {
  const DraftsLibraryInitial();
}

/// Loading state while drafts are being fetched.
final class DraftsLibraryLoading extends DraftsLibraryState {
  const DraftsLibraryLoading();
}

/// Successfully loaded drafts state.
final class DraftsLibraryLoaded extends DraftsLibraryState {
  const DraftsLibraryLoaded({required this.drafts});

  /// List of loaded drafts, sorted by most recent first.
  final List<DivineVideoDraft> drafts;

  @override
  List<Object?> get props => [drafts];
}

/// A draft was successfully deleted.
final class DraftsLibraryDraftDeleted extends DraftsLibraryState {
  const DraftsLibraryDraftDeleted({required this.drafts});

  /// Updated list of drafts after deletion.
  final List<DivineVideoDraft> drafts;

  @override
  List<Object?> get props => [drafts];
}

/// Draft deletion failed.
final class DraftsLibraryDeleteFailed extends DraftsLibraryState {
  const DraftsLibraryDeleteFailed({required this.drafts});

  /// Original list of drafts (unchanged due to failure).
  final List<DivineVideoDraft> drafts;

  @override
  List<Object?> get props => [drafts];
}

/// Error state when draft operations fail.
final class DraftsLibraryError extends DraftsLibraryState {
  const DraftsLibraryError({required this.message});

  /// Error message describing what went wrong.
  final String message;

  @override
  List<Object?> get props => [message];
}
