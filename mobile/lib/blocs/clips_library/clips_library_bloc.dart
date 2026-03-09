// ABOUTME: BLoC for managing saved video clips in the library
// ABOUTME: Handles loading, selection, deletion, and gallery export

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/services/clip_library_service.dart';
import 'package:openvine/services/gallery_save_service.dart';
import 'package:openvine/utils/unified_logger.dart';

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
  }) : _clipLibraryService = clipLibraryService,
       _gallerySaveService = gallerySaveService,
       super(const ClipsLibraryState()) {
    on<ClipsLibraryLoadRequested>(
      _onLoadRequested,
      transformer: droppable(),
    );
    on<ClipsLibraryToggleSelection>(_onToggleSelection);
    on<ClipsLibraryClearSelection>(_onClearSelection);
    on<ClipsLibraryDeleteSelected>(
      _onDeleteSelected,
      transformer: droppable(),
    );
    on<ClipsLibraryDeleteClip>(
      _onDeleteClip,
      transformer: droppable(),
    );
    on<ClipsLibrarySaveToGallery>(
      _onSaveToGallery,
      transformer: droppable(),
    );
  }

  final ClipLibraryService _clipLibraryService;
  final GallerySaveService _gallerySaveService;

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

      emit(
        state.copyWith(
          status: ClipsLibraryStatus.loaded,
          clips: clips,
          clearError: true,
        ),
      );
    } catch (e, stackTrace) {
      Log.error(
        '📚 Failed to load clips: $e',
        name: 'ClipsLibraryBloc',
        category: LogCategory.video,
      );
      addError(e, stackTrace);
      emit(
        state.copyWith(
          status: ClipsLibraryStatus.error,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  void _onToggleSelection(
    ClipsLibraryToggleSelection event,
    Emitter<ClipsLibraryState> emit,
  ) {
    final clip = event.clip;
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

    emit(state.copyWith(status: ClipsLibraryStatus.deleting));

    final deletedCount = state.selectedClipIds.length;

    try {
      Log.info(
        '📚 Deleting $deletedCount clips',
        name: 'ClipsLibraryBloc',
        category: LogCategory.video,
      );

      for (final clipId in state.selectedClipIds) {
        await _clipLibraryService.deleteClip(clipId);
      }

      // Reload clips and clear selection
      final clips = await _clipLibraryService.getAllClips();

      emit(
        state.copyWith(
          status: ClipsLibraryStatus.loaded,
          clips: clips,
          selectedClipIds: const {},
          selectedDuration: Duration.zero,
          lastDeletedCount: deletedCount,
          clearError: true,
        ),
      );
    } catch (e, stackTrace) {
      Log.error(
        '📚 Failed to delete clips: $e',
        name: 'ClipsLibraryBloc',
        category: LogCategory.video,
      );
      addError(e, stackTrace);
      emit(
        state.copyWith(
          status: ClipsLibraryStatus.error,
          errorMessage: 'Failed to delete clips: $e',
        ),
      );
    }
  }

  Future<void> _onDeleteClip(
    ClipsLibraryDeleteClip event,
    Emitter<ClipsLibraryState> emit,
  ) async {
    emit(state.copyWith(status: ClipsLibraryStatus.deleting));

    try {
      Log.info(
        '📚 Deleting clip: ${event.clip.id}',
        name: 'ClipsLibraryBloc',
        category: LogCategory.video,
      );

      await _clipLibraryService.deleteClip(event.clip.id);

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
          selectedClipIds: selectedIds,
          selectedDuration: selectedDuration,
          lastDeletedCount: 1,
          clearError: true,
        ),
      );
    } catch (e, stackTrace) {
      Log.error(
        '📚 Failed to delete clip: $e',
        name: 'ClipsLibraryBloc',
        category: LogCategory.video,
      );
      addError(e, stackTrace);
      emit(
        state.copyWith(
          status: ClipsLibraryStatus.error,
          errorMessage: 'Failed to delete clip: $e',
        ),
      );
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
}
