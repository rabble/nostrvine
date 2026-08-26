// ABOUTME: Cubit for owner-only video actions such as deleting own videos.
// ABOUTME: Keeps service-layer calls out of feed UI widgets.

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:models/models.dart' hide LogCategory;
import 'package:openvine/blocs/close_guard.dart';
import 'package:openvine/observability/reportable_error.dart';
import 'package:openvine/repositories/creator_delete_enforcement_repository.dart';
import 'package:openvine/services/content_deletion_service.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:unified_logger/unified_logger.dart';

enum OwnerVideoDeleteStatus { idle, deleting, success, failure }

enum OwnerVideoCleanupStatus { idle, inProgress, confirmed, delayed, failed }

class OwnerVideoActionsState extends Equatable {
  const OwnerVideoActionsState({
    this.deleteStatus = OwnerVideoDeleteStatus.idle,
    this.cleanupStatus = OwnerVideoCleanupStatus.idle,
    this.deleteResult,
  });

  final OwnerVideoDeleteStatus deleteStatus;
  final OwnerVideoCleanupStatus cleanupStatus;
  final DeleteResult? deleteResult;

  @override
  List<Object?> get props => [
    deleteStatus,
    cleanupStatus,
    deleteResult?.success,
    deleteResult?.failureKind,
    deleteResult?.acceptance,
    deleteResult?.deleteEventId,
    deleteResult?.error,
  ];
}

class OwnerVideoActionsCubit extends Cubit<OwnerVideoActionsState>
    with CloseGuardedEmit<OwnerVideoActionsState> {
  OwnerVideoActionsCubit({
    required Future<ContentDeletionService> contentDeletionServiceFuture,
    required VideoEventService Function() videoEventService,
    required CreatorDeleteEnforcementRepository Function()
    enforcementRepository,
  }) : _contentDeletionServiceFuture = contentDeletionServiceFuture,
       _videoEventService = videoEventService,
       _enforcementRepository = enforcementRepository,
       super(const OwnerVideoActionsState());

  final Future<ContentDeletionService> _contentDeletionServiceFuture;
  final VideoEventService Function() _videoEventService;
  final CreatorDeleteEnforcementRepository Function() _enforcementRepository;

  Future<void> deleteVideo(VideoEvent video) async {
    if (state.deleteStatus == OwnerVideoDeleteStatus.deleting ||
        state.cleanupStatus == OwnerVideoCleanupStatus.inProgress) {
      return;
    }
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

      if (result.success) {
        _videoEventService().removeVideoEventCompletely(video);
        if (!emitIfOpen(
          OwnerVideoActionsState(
            deleteStatus: OwnerVideoDeleteStatus.success,
            cleanupStatus: OwnerVideoCleanupStatus.inProgress,
            deleteResult: result,
          ),
        )) {
          return;
        }
        await _confirmCleanup(result);
      } else {
        emitIfOpen(
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
      emitIfOpen(
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

  Future<void> _confirmCleanup(DeleteResult deleteResult) async {
    final kind5Id = deleteResult.deleteEventId;
    if (kind5Id == null) {
      addError(
        Reportable<StateError>(
          StateError('Successful creator delete omitted the kind-5 id'),
          context: 'OwnerVideoActionsCubit._confirmCleanup',
        ),
        StackTrace.current,
      );
      emitIfOpen(
        OwnerVideoActionsState(
          deleteStatus: OwnerVideoDeleteStatus.success,
          cleanupStatus: OwnerVideoCleanupStatus.failed,
          deleteResult: deleteResult,
        ),
      );
      return;
    }

    final result = await _enforcementRepository().enforce(kind5Id);
    emitIfOpen(
      OwnerVideoActionsState(
        deleteStatus: OwnerVideoDeleteStatus.success,
        cleanupStatus: switch (result.status) {
          CreatorDeleteEnforcementStatus.confirmed =>
            OwnerVideoCleanupStatus.confirmed,
          CreatorDeleteEnforcementStatus.delayed =>
            OwnerVideoCleanupStatus.delayed,
          CreatorDeleteEnforcementStatus.failed =>
            OwnerVideoCleanupStatus.failed,
        },
        deleteResult: deleteResult,
      ),
    );
  }
}
