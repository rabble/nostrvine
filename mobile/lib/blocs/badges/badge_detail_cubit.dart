// ABOUTME: Cubit for one badge's detail page: definition, awardees, awarding
// ABOUTME: new recipients, and accepting or removing the viewer's own award.

import 'package:badge_repository/badge_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'badge_detail_state.dart';

/// Loads and mutates a single badge.
class BadgeDetailCubit extends Cubit<BadgeDetailState> {
  /// Creates the cubit for the badge at [coordinate].
  BadgeDetailCubit({
    required BadgeRepository repository,
    required BadgeCoordinate coordinate,
  }) : _repository = repository,
       super(BadgeDetailState(coordinate: coordinate));

  final BadgeRepository _repository;

  /// Loads the badge, showing the loading state.
  Future<void> load() async {
    emit(
      state.copyWith(
        status: BadgeDetailStatus.loading,
        actionStatus: BadgeDetailActionStatus.idle,
      ),
    );
    await _load();
  }

  /// Reloads the badge without clearing what is already on screen.
  Future<void> refresh() => _load();

  /// Awards this badge to [recipientPubkeys].
  ///
  /// Does not reload afterwards: the award screen owns this cubit purely to
  /// publish, and pops the moment it completes. Reloading first would spend
  /// two relay round trips per recipient building a detail the route throws
  /// away — the screen underneath refreshes itself on return.
  Future<void> award(List<String> recipientPubkeys) {
    return _runAction(
      BadgeDetailActionStatus.awarding,
      () => _repository.awardBadge(
        coordinate: state.coordinate,
        recipientPubkeys: recipientPubkeys,
      ),
      reload: false,
    );
  }

  /// Pins the viewer's award to their profile badge list.
  Future<void> acceptAward() {
    final award = state.detail?.viewerAward;
    if (award == null) return Future<void>.value();
    return _runAction(
      BadgeDetailActionStatus.accepting,
      () => _repository.acceptAward(award),
    );
  }

  /// Requests deletion of the badge and the awards issued for it.
  ///
  /// Unlike the other actions this does not reload afterwards — the badge is
  /// gone, and the view pops.
  Future<void> deleteBadge() async {
    emit(state.copyWith(actionStatus: BadgeDetailActionStatus.deleting));
    try {
      await _repository.deleteBadge(state.coordinate);
      emit(state.copyWith(actionStatus: BadgeDetailActionStatus.deleted));
    } on BadgePublishException catch (error, stackTrace) {
      addError(error, stackTrace);
      emit(
        state.copyWith(
          actionStatus: error.outcome.rejectedBy.isEmpty
              ? BadgeDetailActionStatus.failure
              : BadgeDetailActionStatus.deleteRejected,
        ),
      );
    } catch (error, stackTrace) {
      addError(error, stackTrace);
      emit(state.copyWith(actionStatus: BadgeDetailActionStatus.failure));
    }
  }

  /// Removes the viewer's award from their profile badge list.
  Future<void> removeAward() {
    final award = state.detail?.viewerAward;
    if (award == null) return Future<void>.value();
    return _runAction(
      BadgeDetailActionStatus.removing,
      () => _repository.removeAward(award),
    );
  }

  Future<void> _load() async {
    try {
      final detail = await _repository.loadBadgeDetail(state.coordinate);
      emit(
        state.copyWith(
          status: BadgeDetailStatus.loaded,
          // Same as the catch below: a reload clears the previous action's
          // outcome rather than leaving a stale failure note on screen.
          actionStatus: BadgeDetailActionStatus.idle,
          detail: detail,
        ),
      );
    } catch (error, stackTrace) {
      addError(error, stackTrace);
      emit(
        state.copyWith(
          status: BadgeDetailStatus.failure,
          actionStatus: BadgeDetailActionStatus.idle,
        ),
      );
    }
  }

  Future<void> _runAction(
    BadgeDetailActionStatus actionStatus,
    Future<void> Function() action, {
    bool reload = true,
  }) async {
    emit(state.copyWith(actionStatus: actionStatus));
    try {
      await action();
      if (!reload) {
        emit(
          state.copyWith(actionStatus: BadgeDetailActionStatus.completed),
        );
        return;
      }
      final detail = await _repository.loadBadgeDetail(state.coordinate);
      emit(
        state.copyWith(
          status: BadgeDetailStatus.loaded,
          actionStatus: BadgeDetailActionStatus.completed,
          detail: detail,
        ),
      );
    } catch (error, stackTrace) {
      addError(error, stackTrace);
      emit(state.copyWith(actionStatus: BadgeDetailActionStatus.failure));
    }
  }
}
