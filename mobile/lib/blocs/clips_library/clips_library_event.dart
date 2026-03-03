// ABOUTME: Events for ClipsLibraryBloc - managing saved video clips
// ABOUTME: Supports loading, selection, deletion, and gallery export

part of 'clips_library_bloc.dart';

/// Base class for all clips library events.
sealed class ClipsLibraryEvent extends Equatable {
  const ClipsLibraryEvent();

  @override
  List<Object?> get props => [];
}

/// Event to load all clips from storage.
final class ClipsLibraryLoadRequested extends ClipsLibraryEvent {
  const ClipsLibraryLoadRequested();
}

/// Event to toggle selection of a clip.
final class ClipsLibraryToggleSelection extends ClipsLibraryEvent {
  const ClipsLibraryToggleSelection(this.clip);

  /// The clip to toggle selection for.
  final DivineVideoClip clip;

  @override
  List<Object?> get props => [clip];
}

/// Event to clear all selections.
final class ClipsLibraryClearSelection extends ClipsLibraryEvent {
  const ClipsLibraryClearSelection();
}

/// Event to delete all selected clips.
final class ClipsLibraryDeleteSelected extends ClipsLibraryEvent {
  const ClipsLibraryDeleteSelected();
}

/// Event to delete a single clip.
final class ClipsLibraryDeleteClip extends ClipsLibraryEvent {
  const ClipsLibraryDeleteClip(this.clip);

  /// The clip to delete.
  final DivineVideoClip clip;

  @override
  List<Object?> get props => [clip];
}

/// Event to save selected clips to gallery.
final class ClipsLibrarySaveToGallery extends ClipsLibraryEvent {
  const ClipsLibrarySaveToGallery();
}
