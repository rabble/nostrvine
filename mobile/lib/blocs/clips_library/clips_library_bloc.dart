// ABOUTME: BLoC for managing saved video clips in the library
// ABOUTME: Handles loading, selection, deletion, and gallery export

import 'dart:async';

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/services/clip_library_service.dart';
import 'package:openvine/services/gallery_save_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unified_logger/unified_logger.dart';

part 'clips_library_event.dart';
part 'clips_library_state.dart';

/// BLoC for managing saved video clips in the library.
///
/// Loads clips from [ClipLibraryService], manages selection state,
/// handles deletion, and exports to gallery via [GallerySaveService].
class ClipsLibraryBloc extends Bloc<ClipsLibraryEvent, ClipsLibraryState> {
  ClipsLibraryBloc({
    required ClipLibraryService clipLibraryService,
    required GallerySaveService gallerySaveService,
    required SharedPreferences sharedPreferences,
  }) : _clipLibraryService = clipLibraryService,
       _gallerySaveService = gallerySaveService,
       _sharedPreferences = sharedPreferences,
       super(
         ClipsLibraryState(
           clipSort: _readPersistedSort(sharedPreferences),
         ),
       ) {
    on<ClipsLibraryLoadRequested>(_onLoadRequested, transformer: droppable());
    on<ClipsLibraryToggleSelection>(_onToggleSelection);
    on<ClipsLibraryClearSelection>(_onClearSelection);
    on<ClipsLibraryDeleteSelected>(_onDeleteSelected, transformer: droppable());
    on<ClipsLibraryDeleteClip>(_onDeleteClip, transformer: droppable());
    on<ClipsLibrarySaveToGallery>(_onSaveToGallery, transformer: droppable());
    on<ClipsLibrarySortChanged>(_onSortChanged);
    on<ClipsLibraryEnterSelectionMode>(_onEnterSelectionMode);
    on<ClipsLibraryExitSelectionMode>(_onExitSelectionMode);
    on<ClipsLibraryAutoOpenSelectionMode>(_onAutoOpenSelectionMode);
    on<ClipsLibraryTrashLoadRequested>(
      _onTrashLoadRequested,
      transformer: droppable(),
    );
    on<ClipsLibraryRestoreClips>(_onRestoreClips, transformer: droppable());
    on<ClipsLibraryHardDeleteClip>(_onHardDeleteClip, transformer: droppable());
    on<ClipsLibraryEmptyTrash>(_onEmptyTrash, transformer: droppable());
  }

  /// SharedPreferences key for the persisted [ClipSort] selection.
  static const _sortPrefsKey = 'library_clip_sort';

  final ClipLibraryService _clipLibraryService;
  final GallerySaveService _gallerySaveService;
  final SharedPreferences _sharedPreferences;

  static ClipSort _readPersistedSort(SharedPreferences prefs) {
    final saved = prefs.getString(_sortPrefsKey);
    if (saved == null) return ClipSort.newestCreation;
    return ClipSort.fromPersistenceKey(saved);
  }

  /// Returns [clips] sorted according to [sort]. Pure — does not
  /// mutate the input list.
  static List<DivineVideoClip> _applySort(
    List<DivineVideoClip> clips,
    ClipSort sort,
  ) {
    final sorted = List<DivineVideoClip>.from(clips);
    switch (sort) {
      case ClipSort.newestCreation:
        sorted.sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
      case ClipSort.oldestCreation:
        sorted.sort((a, b) => a.recordedAt.compareTo(b.recordedAt));
      case ClipSort.longestClip:
        sorted.sort((a, b) => b.duration.compareTo(a.duration));
      case ClipSort.shortestClip:
        sorted.sort((a, b) => a.duration.compareTo(b.duration));
      case ClipSort.squareFirst:
        sorted.sort((a, b) {
          final aRank = a.targetAspectRatio == .square ? 0 : 1;
          final bRank = b.targetAspectRatio == .square ? 0 : 1;
          if (aRank != bRank) return aRank.compareTo(bRank);
          return b.recordedAt.compareTo(a.recordedAt);
        });
      case ClipSort.verticalFirst:
        sorted.sort((a, b) {
          final aRank = a.targetAspectRatio == .vertical ? 0 : 1;
          final bRank = b.targetAspectRatio == .vertical ? 0 : 1;
          if (aRank != bRank) return aRank.compareTo(bRank);
          return b.recordedAt.compareTo(a.recordedAt);
        });
    }
    return sorted;
  }

  Future<void> _onLoadRequested(
    ClipsLibraryLoadRequested event,
    Emitter<ClipsLibraryState> emit,
  ) async {
    emit(state.copyWith(status: ClipsLibraryStatus.loading));

    try {
      final clips = await _clipLibraryService.getAllClips();

      Log.debug(
        '📚 Loaded ${clips.length} clips from library',
        name: 'ClipsLibraryBloc',
        category: LogCategory.video,
      );

      // Pre-select clips that are already in the editor.
      // Iterate preSelectedIds (which preserves ClipManager order)
      // so the selection indices match the editor timeline.
      final clipsById = {for (final c in clips) c.id: c};
      final preSelectedIds = <String>{};
      var preSelectedDuration = Duration.zero;
      for (final id in event.preSelectedIds) {
        final clip = clipsById[id];
        if (clip != null) {
          preSelectedIds.add(id);
          preSelectedDuration += clip.duration;
        }
      }

      emit(
        state.copyWith(
          status: ClipsLibraryStatus.loaded,
          clips: clips,
          sortedClips: _applySort(clips, state.clipSort),
          selectedClipIds: preSelectedIds,
          preSelectedIds: event.preSelectedIds,
          disabledClipIds: event.disabledClipIds,
          selectedDuration: preSelectedDuration,
        ),
      );

      // Kick off background recovery for clips missing thumbnails/ghost
      // frames. When done, a fresh load event is dispatched so the UI
      // picks up the updated assets.
      final hasIncomplete = clips.any(
        (c) => c.thumbnailPath == null || c.ghostFramePath == null,
      );
      if (hasIncomplete) {
        unawaited(_recoverAndReload(clips));
      }
    } catch (e, stackTrace) {
      Log.error(
        '📚 Failed to load clips: $e',
        name: 'ClipsLibraryBloc',
        category: LogCategory.video,
      );
      // Matrix-NO: ClipLibraryService.getAllClips is local Drift IO.
      addError(e, stackTrace);
      emit(state.copyWith(status: ClipsLibraryStatus.error));
    }
  }

  void _onToggleSelection(
    ClipsLibraryToggleSelection event,
    Emitter<ClipsLibraryState> emit,
  ) {
    final clip = event.clip;

    // Disabled clips (already in the editor) cannot be toggled.
    if (state.disabledClipIds.contains(clip.id)) return;

    final selectedIds = Set<String>.from(state.selectedClipIds);
    var selectedDuration = state.selectedDuration;

    if (selectedIds.contains(clip.id)) {
      selectedIds.remove(clip.id);
      selectedDuration -= clip.duration;
    } else {
      selectedIds.add(clip.id);
      selectedDuration += clip.duration;
    }

    emit(
      state.copyWith(
        selectedClipIds: selectedIds,
        selectedDuration: selectedDuration,
      ),
    );
  }

  void _onClearSelection(
    ClipsLibraryClearSelection event,
    Emitter<ClipsLibraryState> emit,
  ) {
    emit(
      state.copyWith(
        selectedClipIds: const {},
        selectedDuration: Duration.zero,
      ),
    );
  }

  Future<void> _onDeleteSelected(
    ClipsLibraryDeleteSelected event,
    Emitter<ClipsLibraryState> emit,
  ) async {
    if (state.selectedClipIds.isEmpty) return;

    emit(
      state.copyWith(
        status: ClipsLibraryStatus.deleting,
        clearDeletedCount: true,
      ),
    );

    final deletedIds = Set<String>.from(state.selectedClipIds);
    final deletedCount = deletedIds.length;

    try {
      Log.info(
        '📚 Soft-deleting $deletedCount clips',
        name: 'ClipsLibraryBloc',
        category: LogCategory.video,
      );

      for (final clipId in deletedIds) {
        await _clipLibraryService.softDelete(clipId);
      }

      // Reload clips and clear selection
      final clips = await _clipLibraryService.getAllClips();

      emit(
        state.copyWith(
          status: ClipsLibraryStatus.loaded,
          clips: clips,
          sortedClips: _applySort(clips, state.clipSort),
          selectedClipIds: const {},
          selectedDuration: Duration.zero,
          lastDeletedCount: deletedCount,
          lastDeletedClipIds: deletedIds,
        ),
      );
    } catch (e, stackTrace) {
      Log.error(
        '📚 Failed to delete clips: $e',
        name: 'ClipsLibraryBloc',
        category: LogCategory.video,
      );
      // Matrix-NO: deleteClip loop + getAllClips reload are local Drift IO.
      addError(e, stackTrace);
      emit(state.copyWith(status: ClipsLibraryStatus.error));
    }
  }

  Future<void> _onDeleteClip(
    ClipsLibraryDeleteClip event,
    Emitter<ClipsLibraryState> emit,
  ) async {
    emit(
      state.copyWith(
        status: ClipsLibraryStatus.deleting,
        clearDeletedCount: true,
      ),
    );

    try {
      Log.info(
        '📚 Deleting clip: ${event.clip.id}',
        name: 'ClipsLibraryBloc',
        category: LogCategory.video,
      );

      await _clipLibraryService.softDelete(event.clip.id);

      // Reload clips
      final clips = await _clipLibraryService.getAllClips();

      // Remove from selection if selected
      final selectedIds = Set<String>.from(state.selectedClipIds);
      var selectedDuration = state.selectedDuration;
      if (selectedIds.contains(event.clip.id)) {
        selectedIds.remove(event.clip.id);
        selectedDuration -= event.clip.duration;
      }

      emit(
        state.copyWith(
          status: ClipsLibraryStatus.loaded,
          clips: clips,
          sortedClips: _applySort(clips, state.clipSort),
          selectedClipIds: selectedIds,
          selectedDuration: selectedDuration,
          lastDeletedCount: 1,
          lastDeletedClipIds: {event.clip.id},
        ),
      );
    } catch (e, stackTrace) {
      Log.error(
        '📚 Failed to delete clip: $e',
        name: 'ClipsLibraryBloc',
        category: LogCategory.video,
      );
      // Matrix-NO: deleteClip + getAllClips reload are local Drift IO.
      addError(e, stackTrace);
      emit(state.copyWith(status: ClipsLibraryStatus.error));
    }
  }

  Future<void> _onSaveToGallery(
    ClipsLibrarySaveToGallery event,
    Emitter<ClipsLibraryState> emit,
  ) async {
    if (state.selectedClipIds.isEmpty) return;

    emit(
      state.copyWith(
        status: ClipsLibraryStatus.savingToGallery,
        clearGallerySaveResult: true,
      ),
    );

    final clipsToSave = state.selectedClips;
    final clipCount = clipsToSave.length;

    Log.info(
      '📚 Saving $clipCount clips to gallery',
      name: 'ClipsLibraryBloc',
      category: LogCategory.video,
    );

    var successCount = 0;
    var failureCount = 0;

    for (final clip in clipsToSave) {
      try {
        final result = await _gallerySaveService.saveVideoToGallery(clip.video);

        switch (result) {
          case GallerySaveSuccess():
            successCount++;
          case GallerySavePermissionDenied():
            // Stop immediately on permission denied
            emit(
              state.copyWith(
                status: ClipsLibraryStatus.loaded,
                lastGallerySaveResult:
                    const GallerySaveResultPermissionDenied(),
              ),
            );
            return;
          case GallerySaveFailure():
            failureCount++;
        }
      } catch (e, s) {
        // Matrix-NO: GallerySaveService is documented as never throwing
        // (returns result objects). This catch is defensive against the
        // contract drifting; when-in-doubt classification applies.
        addError(e, s);
        emit(
          state.copyWith(
            status: ClipsLibraryStatus.loaded,
            lastGallerySaveResult: GallerySaveResultError(e.toString()),
          ),
        );
        return;
      }
    }

    // Clear selection after saving
    emit(
      state.copyWith(
        status: ClipsLibraryStatus.loaded,
        selectedClipIds: const {},
        selectedDuration: Duration.zero,
        lastGallerySaveResult: GallerySaveResultSuccess(
          successCount: successCount,
          failureCount: failureCount,
        ),
      ),
    );
  }

  /// Runs asset recovery in the background and dispatches a fresh load
  /// event when done so the UI picks up the updated thumbnails/ghost frames.
  Future<void> _recoverAndReload(List<DivineVideoClip> clips) async {
    try {
      final recovered = await _clipLibraryService.recoverMissingAssets(clips);
      if (!identical(recovered, clips) && !isClosed) {
        add(
          ClipsLibraryLoadRequested(
            preSelectedIds: state.preSelectedIds,
            disabledClipIds: state.disabledClipIds,
          ),
        );
      }
    } catch (e, stackTrace) {
      Log.error(
        '📚 Background asset recovery failed: $e',
        name: 'ClipsLibraryBloc',
        category: LogCategory.video,
      );
      // Matrix-NO: background recoverMissingAssets is filesystem + thumbnail
      // IO (Network/IO category).
      // Guarded for symmetry with the sibling add() above: this method
      // runs fire-and-forget via unawaited() and post-close addError
      // throws StateError.
      if (!isClosed) {
        addError(e, stackTrace);
      }
    }
  }

  Future<void> _onSortChanged(
    ClipsLibrarySortChanged event,
    Emitter<ClipsLibraryState> emit,
  ) async {
    if (event.sort == state.clipSort) return;
    try {
      await _sharedPreferences.setString(
        _sortPrefsKey,
        event.sort.persistenceKey,
      );
    } catch (e, stackTrace) {
      Log.warning(
        '📚 Failed to persist clip sort: $e',
        name: 'ClipsLibraryBloc',
        category: LogCategory.video,
      );
      // Matrix-NO: SharedPreferences.setString is local platform-channel IO.
      addError(e, stackTrace);
    }
    emit(
      state.copyWith(
        clipSort: event.sort,
        sortedClips: _applySort(state.clips, event.sort),
      ),
    );
  }

  void _onEnterSelectionMode(
    ClipsLibraryEnterSelectionMode event,
    Emitter<ClipsLibraryState> emit,
  ) {
    emit(
      state.copyWith(
        isLibrarySelectionMode: true,
        didAutoOpenSelectionMode: false,
      ),
    );
  }

  void _onExitSelectionMode(
    ClipsLibraryExitSelectionMode event,
    Emitter<ClipsLibraryState> emit,
  ) {
    emit(
      state.copyWith(
        isLibrarySelectionMode: false,
        didAutoOpenSelectionMode: false,
        selectedClipIds: const {},
        selectedDuration: Duration.zero,
      ),
    );
  }

  void _onAutoOpenSelectionMode(
    ClipsLibraryAutoOpenSelectionMode event,
    Emitter<ClipsLibraryState> emit,
  ) {
    if (state.isLibrarySelectionMode) return;
    emit(
      state.copyWith(
        isLibrarySelectionMode: true,
        didAutoOpenSelectionMode: true,
      ),
    );
  }

  Future<void> _onTrashLoadRequested(
    ClipsLibraryTrashLoadRequested event,
    Emitter<ClipsLibraryState> emit,
  ) async {
    emit(state.copyWith(status: ClipsLibraryStatus.trashLoading));
    try {
      final trashed = await _clipLibraryService.getTrashedClips();
      emit(
        state.copyWith(
          status: ClipsLibraryStatus.trashLoaded,
          trashedClips: trashed,
        ),
      );
    } catch (e, stackTrace) {
      Log.error(
        '📚 Failed to load trashed clips: $e',
        name: 'ClipsLibraryBloc',
        category: LogCategory.video,
      );
      addError(e, stackTrace);
      emit(state.copyWith(status: ClipsLibraryStatus.error));
    }
  }

  Future<void> _onRestoreClips(
    ClipsLibraryRestoreClips event,
    Emitter<ClipsLibraryState> emit,
  ) async {
    if (event.clipIds.isEmpty) return;
    try {
      for (final id in event.clipIds) {
        await _clipLibraryService.restore(id);
      }
      Log.info(
        '♻️ Restored ${event.clipIds.length} clip(s) from trash',
        name: 'ClipsLibraryBloc',
        category: LogCategory.video,
      );
      await _reloadClipsAndTrash(emit);
    } catch (e, stackTrace) {
      Log.error(
        '📚 Failed to restore clips: $e',
        name: 'ClipsLibraryBloc',
        category: LogCategory.video,
      );
      addError(e, stackTrace);
      emit(state.copyWith(status: ClipsLibraryStatus.error));
    }
  }

  Future<void> _onHardDeleteClip(
    ClipsLibraryHardDeleteClip event,
    Emitter<ClipsLibraryState> emit,
  ) async {
    try {
      await _clipLibraryService.hardDelete(event.clip.id);
      final trashed = await _clipLibraryService.getTrashedClips();
      emit(
        state.copyWith(
          status: ClipsLibraryStatus.trashLoaded,
          trashedClips: trashed,
        ),
      );
    } catch (e, stackTrace) {
      Log.error(
        '📚 Failed to hard-delete clip: $e',
        name: 'ClipsLibraryBloc',
        category: LogCategory.video,
      );
      addError(e, stackTrace);
      emit(state.copyWith(status: ClipsLibraryStatus.error));
    }
  }

  Future<void> _onEmptyTrash(
    ClipsLibraryEmptyTrash event,
    Emitter<ClipsLibraryState> emit,
  ) async {
    try {
      final trashed = await _clipLibraryService.getTrashedClips();
      for (final clip in trashed) {
        await _clipLibraryService.hardDelete(clip.id);
      }
      Log.info(
        '🧹 Emptied trash (${trashed.length} clip(s))',
        name: 'ClipsLibraryBloc',
        category: LogCategory.video,
      );
      emit(
        state.copyWith(
          status: ClipsLibraryStatus.trashLoaded,
          trashedClips: const [],
        ),
      );
    } catch (e, stackTrace) {
      Log.error(
        '📚 Failed to empty trash: $e',
        name: 'ClipsLibraryBloc',
        category: LogCategory.video,
      );
      addError(e, stackTrace);
      emit(state.copyWith(status: ClipsLibraryStatus.error));
    }
  }

  /// Reloads both the active and trashed clip lists. Used after restore
  /// so both views reflect the change.
  Future<void> _reloadClipsAndTrash(Emitter<ClipsLibraryState> emit) async {
    final clips = await _clipLibraryService.getAllClips();
    final trashed = await _clipLibraryService.getTrashedClips();
    emit(
      state.copyWith(
        status:
            state.status == ClipsLibraryStatus.trashLoading ||
                state.status == ClipsLibraryStatus.trashLoaded
            ? ClipsLibraryStatus.trashLoaded
            : ClipsLibraryStatus.loaded,
        clips: clips,
        sortedClips: _applySort(clips, state.clipSort),
        trashedClips: trashed,
        clearDeletedClipIds: true,
      ),
    );
  }
}
