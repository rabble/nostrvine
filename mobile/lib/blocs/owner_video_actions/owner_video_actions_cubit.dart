// ABOUTME: Cubit for owner-only video actions such as deleting own videos.
// ABOUTME: Keeps service-layer calls out of feed UI widgets.

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:models/models.dart' hide LogCategory;
import 'package:openvine/services/content_deletion_service.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:unified_logger/unified_logger.dart';

enum OwnerVideoDeleteStatus { idle, deleting, success, failure }

class OwnerVideoActionsState extends Equatable {
  const OwnerVideoActionsState({
    this.deleteStatus = OwnerVideoDeleteStatus.idle,
    this.deleteResult,
  });

  final OwnerVideoDeleteStatus deleteStatus;
  final DeleteResult? deleteResult;

  @override
  List<Object?> get props => [
    deleteStatus,
    deleteResult?.success,
    deleteResult?.failureKind,
    deleteResult?.deleteEventId,
    deleteResult?.error,
  ];
}

class OwnerVideoActionsCubit extends Cubit<OwnerVideoActionsState> {
  OwnerVideoActionsCubit({
    required Future<ContentDeletionService> contentDeletionServiceFuture,
    required VideoEventService videoEventService,
  }) : _contentDeletionServiceFuture = contentDeletionServiceFuture,
       _videoEventService = videoEventService,
       super(const OwnerVideoActionsState());

  final Future<ContentDeletionService> _contentDeletionServiceFuture;
  final VideoEventService _videoEventService;

  Future<void> deleteVideo(VideoEvent video) async {
    emit(
      const OwnerVideoActionsState(
        deleteStatus: OwnerVideoDeleteStatus.deleting,
      ),
    );

    try {
      final deletionService = await _contentDeletionServiceFuture;
      final result = await deletionService.quickDelete(
        video: video,
        reason: DeleteReason.personalChoice,
      );

      if (isClosed) return;

      if (result.success) {
        _videoEventService.removeVideoEventCompletely(video);
        emit(
          OwnerVideoActionsState(
            deleteStatus: OwnerVideoDeleteStatus.success,
            deleteResult: result,
          ),
        );
      } else {
        emit(
          OwnerVideoActionsState(
            deleteStatus: OwnerVideoDeleteStatus.failure,
            deleteResult: result,
          ),
        );
      }
    } catch (e) {
      Log.error(
        'Failed to delete video: $e',
        name: 'OwnerVideoActionsCubit',
        category: LogCategory.ui,
      );
      if (isClosed) return;
      emit(
        OwnerVideoActionsState(
          deleteStatus: OwnerVideoDeleteStatus.failure,
          deleteResult: DeleteResult.failure(
            'Failed to delete video',
            DeleteFailureKind.unknown,
          ),
        ),
      );
    }
  }
}
