// ABOUTME: Cubit for queued collaborator-invite banner retry state.
// ABOUTME: Owns retry orchestration so the banner widget only renders + listens.

import 'package:dm_repository/dm_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

enum PendingCollaboratorInviteBannerFeedback {
  none,
  retryUnavailable,
  retryCompleted,
}

class PendingCollaboratorInviteBannerState extends Equatable {
  const PendingCollaboratorInviteBannerState({
    this.isRetrying = false,
    this.feedback = PendingCollaboratorInviteBannerFeedback.none,
    this.remainingInviteCount = 0,
  });

  final bool isRetrying;
  final PendingCollaboratorInviteBannerFeedback feedback;
  final int remainingInviteCount;

  PendingCollaboratorInviteBannerState copyWith({
    bool? isRetrying,
    PendingCollaboratorInviteBannerFeedback? feedback,
    int? remainingInviteCount,
  }) {
    return PendingCollaboratorInviteBannerState(
      isRetrying: isRetrying ?? this.isRetrying,
      feedback: feedback ?? this.feedback,
      remainingInviteCount: remainingInviteCount ?? this.remainingInviteCount,
    );
  }

  @override
  List<Object?> get props => [isRetrying, feedback, remainingInviteCount];
}

class PendingCollaboratorInviteBannerCubit
    extends Cubit<PendingCollaboratorInviteBannerState> {
  PendingCollaboratorInviteBannerCubit(this._dmRepository)
    : super(const PendingCollaboratorInviteBannerState());

  final DmRepository? _dmRepository;

  Future<void> retry(PendingCollaboratorInviteGroup group) async {
    final repository = _dmRepository;
    if (repository == null) {
      emit(
        state.copyWith(
          feedback: PendingCollaboratorInviteBannerFeedback.retryUnavailable,
        ),
      );
      return;
    }

    emit(
      state.copyWith(
        isRetrying: true,
        feedback: PendingCollaboratorInviteBannerFeedback.none,
      ),
    );

    final summary = await repository.retryPendingCollaboratorInvites(
      group.invites,
    );

    emit(
      state.copyWith(
        isRetrying: false,
        feedback: PendingCollaboratorInviteBannerFeedback.retryCompleted,
        remainingInviteCount: summary.failureCount,
      ),
    );
  }
}
