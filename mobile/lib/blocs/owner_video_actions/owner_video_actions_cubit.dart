// ABOUTME: Cubit for owner-only video actions such as deleting own videos.
// ABOUTME: Keeps service-layer calls out of feed UI widgets.

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:models/models.dart' hide LogCategory;
import 'package:openvine/services/content_deletion_service.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:unified_logger/unified_logger.dart';

enum OwnerVideoDeleteStatus { idle, deleting, success, failure }

enum OwnerVideoDeleteFailureKind {
  notInitialized,
  notOwner,
  notAuthenticated,
  couldNotSign,
  relayRejected,
  relayNoResponse,
  unknown,
}

class OwnerVideoActionsState {
  const OwnerVideoActionsState({
    this.deleteStatus = OwnerVideoDeleteStatus.idle,
    this.deleteFailureKind,
  });

  final OwnerVideoDeleteStatus deleteStatus;
  final OwnerVideoDeleteFailureKind? deleteFailureKind;

  OwnerVideoActionsState copyWith({
    OwnerVideoDeleteStatus? deleteStatus,
    OwnerVideoDeleteFailureKind? deleteFailureKind,
  }) => OwnerVideoActionsState(
    deleteStatus: deleteStatus ?? this.deleteStatus,
    deleteFailureKind: deleteFailureKind,
  );
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
          const OwnerVideoActionsState(
            deleteStatus: OwnerVideoDeleteStatus.success,
          ),
        );
      } else {
        emit(
          OwnerVideoActionsState(
            deleteStatus: OwnerVideoDeleteStatus.failure,
            deleteFailureKind: _mapFailureKind(result.failureKind),
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
        const OwnerVideoActionsState(
          deleteStatus: OwnerVideoDeleteStatus.failure,
          deleteFailureKind: OwnerVideoDeleteFailureKind.unknown,
        ),
      );
    }
  }

  OwnerVideoDeleteFailureKind _mapFailureKind(DeleteFailureKind? kind) {
    switch (kind) {
      case DeleteFailureKind.notInitialized:
        return OwnerVideoDeleteFailureKind.notInitialized;
      case DeleteFailureKind.notOwner:
        return OwnerVideoDeleteFailureKind.notOwner;
      case DeleteFailureKind.notAuthenticated:
        return OwnerVideoDeleteFailureKind.notAuthenticated;
      case DeleteFailureKind.couldNotSign:
        return OwnerVideoDeleteFailureKind.couldNotSign;
      case DeleteFailureKind.relayRejected:
        return OwnerVideoDeleteFailureKind.relayRejected;
      case DeleteFailureKind.relayNoResponse:
        return OwnerVideoDeleteFailureKind.relayNoResponse;
      case DeleteFailureKind.unknown:
      case null:
        return OwnerVideoDeleteFailureKind.unknown;
    }
  }
}
