// ABOUTME: States for ClipsLibraryBloc - managing saved video clips
// ABOUTME: Tracks clips list, selection state, and async operation status

part of 'clips_library_bloc.dart';

/// Sort order for clips in the library grid.
///
/// The string returned by [persistenceKey] is the stable identifier
/// stored in [SharedPreferences] — never use [Enum.name] for
/// persistence, since renaming an enum value would silently invalidate
/// every saved preference.
enum ClipSort {
  newestCreation,
  oldestCreation,
  longestClip,
  shortestClip,
  squareFirst,
  verticalFirst
  ;

  static const _persistenceKeys = <ClipSort, String>{
    ClipSort.newestCreation: 'newest_creation',
    ClipSort.oldestCreation: 'oldest_creation',
    ClipSort.longestClip: 'longest_clip',
    ClipSort.shortestClip: 'shortest_clip',
    ClipSort.squareFirst: 'square_first',
    ClipSort.verticalFirst: 'vertical_first',
  };

  /// Stable string used to persist this sort in [SharedPreferences].
  String get persistenceKey => _persistenceKeys[this]!;

  /// Parses [key] back to a [ClipSort], falling back to
  /// [ClipSort.newestCreation] when the key is unknown (e.g. from a
  /// future build that wrote a value this build doesn't recognize).
  static ClipSort fromPersistenceKey(String key) {
    for (final entry in _persistenceKeys.entries) {
      if (entry.value == key) return entry.key;
    }
    return ClipSort.newestCreation;
  }
}

/// Operation status for clips library actions.
enum ClipsLibraryStatus {
  /// Initial state, no operation in progress.
  initial,

  /// Loading clips from storage.
  loading,

  /// Clips loaded successfully.
  loaded,

  /// Deleting selected clips.
  deleting,

  /// Saving to gallery.
  savingToGallery,

  /// An error occurred.
  error,
}

/// Result of a gallery save operation.
sealed class GallerySaveResult extends Equatable {
  const GallerySaveResult();

  @override
  List<Object?> get props => [];
}

/// Gallery save completed successfully.
final class GallerySaveResultSuccess extends GallerySaveResult {
  const GallerySaveResultSuccess({
    required this.successCount,
    required this.failureCount,
  });

  /// Number of clips saved successfully.
  final int successCount;

  /// Number of clips that failed to save.
  final int failureCount;

  @override
  List<Object?> get props => [successCount, failureCount];
}

/// Gallery save failed due to permission denial.
final class GallerySaveResultPermissionDenied extends GallerySaveResult {
  const GallerySaveResultPermissionDenied();
}

/// Gallery save failed with an error.
final class GallerySaveResultError extends GallerySaveResult {
  const GallerySaveResultError(this.message);

  /// Error message.
  final String message;

  @override
  List<Object?> get props => [message];
}

/// State for the clips library.
final class ClipsLibraryState extends Equatable {
  const ClipsLibraryState({
    this.status = ClipsLibraryStatus.initial,
    this.clips = const [],
    this.sortedClips = const [],
    this.selectedClipIds = const {},
    this.disabledClipIds = const {},
    this.preSelectedIds = const {},
    this.selectedDuration = Duration.zero,
    this.clipSort = ClipSort.newestCreation,
    this.isLibrarySelectionMode = false,
    this.didAutoOpenSelectionMode = false,
    this.lastGallerySaveResult,
    this.lastDeletedCount,
  });

  /// Current operation status.
  final ClipsLibraryStatus status;

  /// All available clips, in their original load order.
  final List<DivineVideoClip> clips;

  /// [clips] sorted by the current [clipSort] for display.
  final List<DivineVideoClip> sortedClips;

  /// IDs of currently selected clips.
  final Set<String> selectedClipIds;

  /// IDs of clips already in the editor that cannot be toggled.
  final Set<String> disabledClipIds;

  /// IDs that should be marked selected after the next reload (e.g.
  /// the editor's current clip set). Stored so background reloads
  /// (asset recovery, retry-on-error) preserve the original
  /// selection intent.
  final Set<String> preSelectedIds;

  /// Total duration of selected clips.
  final Duration selectedDuration;

  /// Active sort order for [sortedClips]. Persisted via
  /// [SharedPreferences] using [ClipSort.persistenceKey].
  final ClipSort clipSort;

  /// Whether the library UI is currently in multi-select mode (the
  /// non-`selectionMode` screen entry-point can toggle this on/off).
  final bool isLibrarySelectionMode;

  /// Whether [isLibrarySelectionMode] was entered automatically by
  /// the auto-open BlocListener rather than a manual user action.
  /// The toolbar uses this to lock the close button when the screen
  /// is opened in clips-only mode and the first selection arrives.
  final bool didAutoOpenSelectionMode;

  /// Result of the last gallery save operation (for UI feedback).
  final GallerySaveResult? lastGallerySaveResult;

  /// Number of clips deleted in the last delete operation (for UI feedback).
  final int? lastDeletedCount;

  /// Whether clips are currently loading.
  bool get isLoading => status == ClipsLibraryStatus.loading;

  /// Whether a delete operation is in progress.
  bool get isDeleting => status == ClipsLibraryStatus.deleting;

  /// Whether a gallery save is in progress.
  bool get isSavingToGallery => status == ClipsLibraryStatus.savingToGallery;

  /// Returns the currently selected clips in selection order.
  List<DivineVideoClip> get selectedClips {
    final clipsById = {for (final c in clips) c.id: c};
    return [for (final id in selectedClipIds) ?clipsById[id]];
  }

  /// Creates a copy of this state with the given fields replaced.
  ClipsLibraryState copyWith({
    ClipsLibraryStatus? status,
    List<DivineVideoClip>? clips,
    List<DivineVideoClip>? sortedClips,
    Set<String>? selectedClipIds,
    Set<String>? disabledClipIds,
    Set<String>? preSelectedIds,
    Duration? selectedDuration,
    ClipSort? clipSort,
    bool? isLibrarySelectionMode,
    bool? didAutoOpenSelectionMode,
    GallerySaveResult? lastGallerySaveResult,
    int? lastDeletedCount,
    bool clearGallerySaveResult = false,
    bool clearDeletedCount = false,
  }) {
    return ClipsLibraryState(
      status: status ?? this.status,
      clips: clips ?? this.clips,
      sortedClips: sortedClips ?? this.sortedClips,
      selectedClipIds: selectedClipIds ?? this.selectedClipIds,
      disabledClipIds: disabledClipIds ?? this.disabledClipIds,
      preSelectedIds: preSelectedIds ?? this.preSelectedIds,
      selectedDuration: selectedDuration ?? this.selectedDuration,
      clipSort: clipSort ?? this.clipSort,
      isLibrarySelectionMode:
          isLibrarySelectionMode ?? this.isLibrarySelectionMode,
      didAutoOpenSelectionMode:
          didAutoOpenSelectionMode ?? this.didAutoOpenSelectionMode,
      lastGallerySaveResult: clearGallerySaveResult
          ? null
          : (lastGallerySaveResult ?? this.lastGallerySaveResult),
      lastDeletedCount: clearDeletedCount
          ? null
          : (lastDeletedCount ?? this.lastDeletedCount),
    );
  }

  @override
  List<Object?> get props => [
    status,
    clips,
    sortedClips,
    selectedClipIds,
    disabledClipIds,
    preSelectedIds,
    selectedDuration,
    clipSort,
    isLibrarySelectionMode,
    didAutoOpenSelectionMode,
    lastGallerySaveResult,
    lastDeletedCount,
  ];
}
