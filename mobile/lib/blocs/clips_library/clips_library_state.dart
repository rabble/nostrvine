// ABOUTME: States for ClipsLibraryBloc - managing saved video clips
// ABOUTME: Tracks clips list, selection state, and async operation status

part of 'clips_library_bloc.dart';

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
    this.selectedClipIds = const {},
    this.disabledClipIds = const {},
    this.selectedDuration = Duration.zero,
    this.lastGallerySaveResult,
    this.lastDeletedCount,
  });

  /// Current operation status.
  final ClipsLibraryStatus status;

  /// All available clips.
  final List<DivineVideoClip> clips;

  /// IDs of currently selected clips.
  final Set<String> selectedClipIds;

  /// IDs of clips already in the editor that cannot be toggled.
  final Set<String> disabledClipIds;

  /// Total duration of selected clips.
  final Duration selectedDuration;

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
    return [
      for (final id in selectedClipIds) ?clipsById[id],
    ];
  }

  /// Creates a copy of this state with the given fields replaced.
  ClipsLibraryState copyWith({
    ClipsLibraryStatus? status,
    List<DivineVideoClip>? clips,
    Set<String>? selectedClipIds,
    Set<String>? disabledClipIds,
    Duration? selectedDuration,
    GallerySaveResult? lastGallerySaveResult,
    int? lastDeletedCount,
    bool clearGallerySaveResult = false,
    bool clearDeletedCount = false,
  }) {
    return ClipsLibraryState(
      status: status ?? this.status,
      clips: clips ?? this.clips,
      selectedClipIds: selectedClipIds ?? this.selectedClipIds,
      disabledClipIds: disabledClipIds ?? this.disabledClipIds,
      selectedDuration: selectedDuration ?? this.selectedDuration,
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
    selectedClipIds,
    disabledClipIds,
    selectedDuration,
    lastGallerySaveResult,
    lastDeletedCount,
  ];
}
