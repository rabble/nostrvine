// ABOUTME: Unit tests for owner-only video action business logic.
// ABOUTME: Verifies delete success, typed failures, and exception handling.

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/owner_video_actions/owner_video_actions_cubit.dart';
import 'package:openvine/services/content_deletion_service.dart';
import 'package:openvine/services/video_event_service.dart';

class _MockContentDeletionService extends Mock
    implements ContentDeletionService {}

class _MockVideoEventService extends Mock implements VideoEventService {}

void main() {
  group(OwnerVideoActionsCubit, () {
    final video = VideoEvent(
      id: '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
      pubkey:
          'abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789',
      createdAt: 1757385263,
      content: 'Test video content',
      timestamp: DateTime.fromMillisecondsSinceEpoch(1757385263 * 1000),
      videoUrl: 'https://example.com/video.mp4',
    );

    late _MockContentDeletionService deletionService;
    late _MockVideoEventService videoEventService;

    OwnerVideoActionsCubit buildCubit() => OwnerVideoActionsCubit(
      contentDeletionServiceFuture: Future.value(deletionService),
      videoEventService: videoEventService,
    );

    setUp(() {
      deletionService = _MockContentDeletionService();
      videoEventService = _MockVideoEventService();
    });

    blocTest<OwnerVideoActionsCubit, OwnerVideoActionsState>(
      'removes the video locally after delete success',
      build: buildCubit,
      setUp: () {
        when(
          () => deletionService.quickDelete(
            video: video,
            reason: DeleteReason.personalChoice,
          ),
        ).thenAnswer(
          (_) async => DeleteResult.createSuccess('delete-event-id'),
        );
      },
      act: (cubit) => cubit.deleteVideo(video),
      expect: () => [
        const OwnerVideoActionsState(
          deleteStatus: OwnerVideoDeleteStatus.deleting,
        ),
        isA<OwnerVideoActionsState>()
            .having(
              (state) => state.deleteStatus,
              'deleteStatus',
              OwnerVideoDeleteStatus.success,
            )
            .having(
              (state) => state.deleteResult?.success,
              'deleteResult.success',
              isTrue,
            )
            .having(
              (state) => state.deleteResult?.deleteEventId,
              'deleteResult.deleteEventId',
              'delete-event-id',
            ),
      ],
      verify: (_) {
        verify(
          () => videoEventService.removeVideoEventCompletely(video),
        ).called(1);
      },
    );

    blocTest<OwnerVideoActionsCubit, OwnerVideoActionsState>(
      'surfaces typed delete failures without removing the video locally',
      build: buildCubit,
      setUp: () {
        when(
          () => deletionService.quickDelete(
            video: video,
            reason: DeleteReason.personalChoice,
          ),
        ).thenAnswer(
          (_) async => DeleteResult.failure(
            'Relay rejected delete event',
            DeleteFailureKind.relayRejected,
          ),
        );
      },
      act: (cubit) => cubit.deleteVideo(video),
      expect: () => [
        const OwnerVideoActionsState(
          deleteStatus: OwnerVideoDeleteStatus.deleting,
        ),
        isA<OwnerVideoActionsState>()
            .having(
              (state) => state.deleteStatus,
              'deleteStatus',
              OwnerVideoDeleteStatus.failure,
            )
            .having(
              (state) => state.deleteResult?.success,
              'deleteResult.success',
              isFalse,
            )
            .having(
              (state) => state.deleteResult?.failureKind,
              'deleteResult.failureKind',
              DeleteFailureKind.relayRejected,
            ),
      ],
      verify: (_) {
        verifyNever(() => videoEventService.removeVideoEventCompletely(video));
      },
    );

    blocTest<OwnerVideoActionsCubit, OwnerVideoActionsState>(
      'reports unknown failure when delete throws',
      build: buildCubit,
      setUp: () {
        when(
          () => deletionService.quickDelete(
            video: video,
            reason: DeleteReason.personalChoice,
          ),
        ).thenThrow(Exception('network failed'));
      },
      act: (cubit) => cubit.deleteVideo(video),
      expect: () => [
        const OwnerVideoActionsState(
          deleteStatus: OwnerVideoDeleteStatus.deleting,
        ),
        isA<OwnerVideoActionsState>()
            .having(
              (state) => state.deleteStatus,
              'deleteStatus',
              OwnerVideoDeleteStatus.failure,
            )
            .having(
              (state) => state.deleteResult?.success,
              'deleteResult.success',
              isFalse,
            )
            .having(
              (state) => state.deleteResult?.failureKind,
              'deleteResult.failureKind',
              DeleteFailureKind.unknown,
            ),
      ],
      verify: (_) {
        verifyNever(() => videoEventService.removeVideoEventCompletely(video));
      },
    );
  });
}
