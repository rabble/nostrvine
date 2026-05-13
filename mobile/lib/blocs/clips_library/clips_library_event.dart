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
///
/// When [preSelectedIds] is provided, clips matching those IDs will
/// be marked as selected after loading.
final class ClipsLibraryLoadRequested extends ClipsLibraryEvent {
  const ClipsLibraryLoadRequested({
    this.preSelectedIds = const {},
    this.disabledClipIds = const {},
  });

  /// Clip IDs to pre-select after loading (e.g. clips already in the editor).
  final Set<String> preSelectedIds;

  /// Clip IDs that are already in the editor and cannot be deselected.
  final Set<String> disabledClipIds;

  @override
  List<Object?> get props => [preSelectedIds, disabledClipIds];
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

/// Event to change the active clip sort order. The new sort is
/// persisted to [SharedPreferences] using [ClipSort.persistenceKey].
final class ClipsLibrarySortChanged extends ClipsLibraryEvent {
  const ClipsLibrarySortChanged(this.sort);

  /// The new sort order to apply.
  final ClipSort sort;

  @override
  List<Object?> get props => [sort];
}

/// Event to manually enter multi-select mode (toolbar "Select" button).
final class ClipsLibraryEnterSelectionMode extends ClipsLibraryEvent {
  const ClipsLibraryEnterSelectionMode();
}

/// Event to exit multi-select mode and clear current selection.
final class ClipsLibraryExitSelectionMode extends ClipsLibraryEvent {
  const ClipsLibraryExitSelectionMode();
}

/// Event to enter multi-select mode automatically as a result of
/// the first selection arriving in clips-only mode. Sets
/// [ClipsLibraryState.didAutoOpenSelectionMode] so the toolbar can
/// lock the close button accordingly.
final class ClipsLibraryAutoOpenSelectionMode extends ClipsLibraryEvent {
  const ClipsLibraryAutoOpenSelectionMode();
}
