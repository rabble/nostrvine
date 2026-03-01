// ABOUTME: BLoC for managing draft video projects in the library
// ABOUTME: Handles loading and deleting drafts with proper state management

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/models/vine_draft.dart';
import 'package:openvine/services/draft_storage_service.dart';
import 'package:openvine/utils/unified_logger.dart';

part 'drafts_library_event.dart';
part 'drafts_library_state.dart';

/// BLoC for managing draft video projects in the library.
///
/// Loads drafts from [DraftStorageService] and handles deletion.
/// Filters out autosave and already published drafts.
class DraftsLibraryBloc extends Bloc<DraftsLibraryEvent, DraftsLibraryState> {
  DraftsLibraryBloc({
    required DraftStorageService draftStorageService,
  }) : _draftStorageService = draftStorageService,
       super(const DraftsLibraryInitial()) {
    on<DraftsLibraryLoadRequested>(
      _onLoadRequested,
      transformer: droppable(),
    );
    on<DraftsLibraryDeleteRequested>(_onDeleteRequested);
  }

  final DraftStorageService _draftStorageService;

  Future<void> _onLoadRequested(
    DraftsLibraryLoadRequested event,
    Emitter<DraftsLibraryState> emit,
  ) async {
    emit(const DraftsLibraryLoading());

    try {
      final allDrafts = await _draftStorageService.getAllDrafts();

      // Filter out autosave and already published drafts, sort by newest first
      final filteredDrafts =
          allDrafts
              .where(
                (d) =>
                    d.id != VideoEditorConstants.autoSaveId &&
                    d.publishStatus != PublishStatus.published &&
                    d.publishStatus != PublishStatus.publishing,
              )
              .toList()
            ..sort((a, b) => b.lastModified.compareTo(a.lastModified));

      Log.debug(
        '📚 Loaded ${filteredDrafts.length} drafts',
        name: 'DraftsLibraryBloc',
        category: LogCategory.video,
      );

      emit(DraftsLibraryLoaded(drafts: filteredDrafts));
    } catch (e, stackTrace) {
      Log.error(
        '📚 Failed to load drafts: $e',
        name: 'DraftsLibraryBloc',
        category: LogCategory.video,
      );
      addError(e, stackTrace);
      emit(DraftsLibraryError(message: e.toString()));
    }
  }

  Future<void> _onDeleteRequested(
    DraftsLibraryDeleteRequested event,
    Emitter<DraftsLibraryState> emit,
  ) async {
    final currentState = state;
    if (currentState is! DraftsLibraryLoaded) return;

    try {
      Log.info(
        '📚 Deleting draft: ${event.draftId}',
        name: 'DraftsLibraryBloc',
        category: LogCategory.video,
      );

      await _draftStorageService.deleteDraft(event.draftId);

      // Update the list by removing the deleted draft
      final updatedDrafts = currentState.drafts
          .where((d) => d.id != event.draftId)
          .toList();

      emit(
        DraftsLibraryLoaded(
          drafts: updatedDrafts,
          deleteResult: DeleteResult.success,
        ),
      );
    } catch (e, stackTrace) {
      Log.error(
        '📚 Failed to delete draft: $e',
        name: 'DraftsLibraryBloc',
        category: LogCategory.video,
      );
      addError(e, stackTrace);
      // Keep showing the current list on error, but signal failure
      emit(
        DraftsLibraryLoaded(
          drafts: currentState.drafts,
          deleteResult: DeleteResult.failure,
          deleteError: e.toString(),
        ),
      );
    }
  }
}
