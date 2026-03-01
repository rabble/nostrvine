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
  final List<VineDraft> drafts;

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
