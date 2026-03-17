import 'dart:async';

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/models/divine_video_draft.dart';
import 'package:openvine/services/draft_storage_service.dart';
import 'package:openvine/services/video_publish/video_publish_service.dart';
import 'package:openvine/utils/unified_logger.dart';

part 'background_publish_event.dart';
part 'background_publish_state.dart';

class BackgroundPublishBloc
    extends Bloc<BackgroundPublishEvent, BackgroundPublishState> {
  BackgroundPublishBloc({
    required Future<VideoPublishService> Function({
      required OnProgressChanged onProgress,
    })
    videoPublishServiceFactory,
    required DraftStorageService draftStorageService,
  }) : _videoPublishServiceFactory = videoPublishServiceFactory,
       _draftStorageService = draftStorageService,
       super(const BackgroundPublishState()) {
    on<BackgroundPublishRequested>(
      _onBackgroundPublishRequested,
      transformer: sequential(),
    );
    on<BackgroundPublishProgressChanged>(_onBackgroundPublishProgressChanged);
    on<BackgroundPublishVanished>(_onBackgroundPublishVanished);
    on<BackgroundPublishRetryRequested>(_onBackgroundPublishRetryRequested);
    on<BackgroundPublishFailed>(_onBackgroundPublishFailed);
  }

  final Future<VideoPublishService> Function({
    required OnProgressChanged onProgress,
  })
  _videoPublishServiceFactory;

  final DraftStorageService _draftStorageService;

  Future<void> _onBackgroundPublishRequested(
    BackgroundPublishRequested event,
    Emitter<BackgroundPublishState> emit,
  ) async {
    // Check if the upload is already in progress
    final alreadyUploading = state.uploads.any(
      (upload) => upload.draft.id == event.draft.id,
    );
    if (!alreadyUploading) {
      final newUpload = BackgroundUpload(
        draft: event.draft,
        result: null,
        progress: 0,
      );
      emit(state.copyWith(uploads: [...state.uploads, newUpload]));
    }

    PublishResult result;
    try {
      result = await event.publishmentProcess;
    } catch (e, stackTrace) {
      Log.error(
        'Publish process threw an exception: $e',
        category: LogCategory.video,
        error: e,
        stackTrace: stackTrace,
      );
      addError(e, stackTrace);
      // TODO(l10n): Replace with context.l10n when localization is added.
      result = const PublishError('Something went wrong. Please try again.');
    }

    // Remove the upload if it was successful
    if (result is PublishSuccess) {
      final updatedUploads = state.uploads
          .where((upload) => upload.draft.id != event.draft.id)
          .toList();

      emit(state.copyWith(uploads: updatedUploads));

      // Draft is no longer needed after successful publish
      unawaited(_draftStorageService.deleteDraft(event.draft.id));
    } else {
      // Update the upload with the result
      final updatedUploads = state.uploads.map((upload) {
        if (upload.draft.id == event.draft.id) {
          return upload.copyWith(result: result, progress: 1.0);
        }
        return upload;
      }).toList();

      emit(state.copyWith(uploads: updatedUploads));

      // Persist failed status in the database
      final errorMessage = result is PublishError ? result.userMessage : null;
      unawaited(
        _draftStorageService.updatePublishStatus(
          draftId: event.draft.id,
          status: PublishStatus.failed,
          publishError: errorMessage,
        ),
      );
    }
  }

  void _onBackgroundPublishProgressChanged(
    BackgroundPublishProgressChanged event,
    Emitter<BackgroundPublishState> emit,
  ) {
    final upload = state.uploads.cast<BackgroundUpload?>().firstWhere(
      (upload) => upload!.draft.id == event.draftId,
      orElse: () => null,
    );

    // Disregard progress events if the upload already has a result
    // or if the progress is not greater than the current value,
    // since events can arrive out of order.
    if (upload == null ||
        upload.result != null ||
        event.progress <= upload.progress) {
      return;
    }

    final updatedUploads = state.uploads.map((upload) {
      if (upload.draft.id == event.draftId) {
        return upload.copyWith(progress: event.progress);
      }
      return upload;
    }).toList();

    emit(state.copyWith(uploads: updatedUploads));
  }

  void _onBackgroundPublishVanished(
    BackgroundPublishVanished event,
    Emitter<BackgroundPublishState> emit,
  ) {
    final remainingUploads = state.uploads.where((upload) {
      return upload.draft.id != event.draftId;
    }).toList();
    emit(state.copyWith(uploads: remainingUploads));

    // Reset to draft so resumePendingPublishes won't re-surface it
    unawaited(
      _draftStorageService.updatePublishStatus(
        draftId: event.draftId,
        status: PublishStatus.draft,
      ),
    );
  }

  Future<void> _onBackgroundPublishRetryRequested(
    BackgroundPublishRetryRequested event,
    Emitter<BackgroundPublishState> emit,
  ) async {
    final uploadToRetry = state.uploads.firstWhere(
      (upload) => upload.draft.id == event.draftId,
    );

    // Clear previous result
    final clearedUploads = state.uploads.where((upload) {
      return upload.draft.id != event.draftId;
    }).toList();
    emit(state.copyWith(uploads: clearedUploads));

    final videoPublishService = await _videoPublishServiceFactory(
      onProgress: ({required String draftId, required double progress}) {
        add(
          BackgroundPublishProgressChanged(
            draftId: draftId,
            progress: progress,
          ),
        );
      },
    );

    final newPublishProcess = videoPublishService.publishVideo(
      draft: uploadToRetry.draft,
    );

    add(
      BackgroundPublishRequested(
        draft: uploadToRetry.draft,
        publishmentProcess: newPublishProcess,
      ),
    );
  }

  void _onBackgroundPublishFailed(
    BackgroundPublishFailed event,
    Emitter<BackgroundPublishState> emit,
  ) {
    final alreadyTracked = state.uploads.any(
      (upload) => upload.draft.id == event.draft.id,
    );
    if (alreadyTracked) return;

    final failedUpload = BackgroundUpload(
      draft: event.draft,
      result: PublishError(event.userMessage),
      progress: 0,
    );
    emit(state.copyWith(uploads: [...state.uploads, failedUpload]));
  }
}
