// ABOUTME: Cubit that loads NIP-58 badge dashboard data and
// ABOUTME: coordinates accept, remove, and hide badge actions.

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/services/badges/badge_repository.dart';

part 'badges_state.dart';

/// Loads and mutates the current user's NIP-58 badge dashboard.
class BadgesCubit extends Cubit<BadgesState> {
  /// Creates the cubit with the given [repository].
  BadgesCubit({required BadgeRepository repository})
    : _repository = repository,
      super(const BadgesState());

  final BadgeRepository _repository;

  /// Loads awarded and issued badges for the current account.
  Future<void> load() async {
    emit(
      state.copyWith(
        status: BadgesStatus.loading,
        actionStatus: BadgeActionStatus.idle,
      ),
    );
    await _loadDashboard();
  }

  /// Refreshes badge data without forcing a full loading state.
  Future<void> refresh() => _loadDashboard();

  /// Accepts an award by publishing a NIP-58 profile badges event.
  Future<void> acceptAward(BadgeAwardViewData award) {
    return _runAction(
      BadgeActionStatus.accepting,
      () => _repository.acceptAward(award),
    );
  }

  /// Removes an accepted award from the user's profile badges event.
  Future<void> removeAward(BadgeAwardViewData award) {
    return _runAction(
      BadgeActionStatus.removing,
      () => _repository.removeAward(award),
    );
  }

  /// Locally hides an awarded badge without publishing anything.
  Future<void> hideAward(BadgeAwardViewData award) {
    return _runAction(
      BadgeActionStatus.hiding,
      () => _repository.hideAward(award.awardEventId),
    );
  }

  Future<void> _loadDashboard() async {
    try {
      final dashboard = await _repository.loadDashboard();
      emit(
        state.copyWith(
          status: BadgesStatus.loaded,
          awarded: dashboard.awarded,
          issued: dashboard.issued,
        ),
      );
    } catch (error, stackTrace) {
      addError(error, stackTrace);
      emit(
        state.copyWith(
          status: BadgesStatus.error,
          actionStatus: BadgeActionStatus.idle,
        ),
      );
    }
  }

  Future<void> _runAction(
    BadgeActionStatus actionStatus,
    Future<void> Function() action,
  ) async {
    emit(
      state.copyWith(
        actionStatus: actionStatus,
      ),
    );

    try {
      await action();
      final dashboard = await _repository.loadDashboard();
      emit(
        state.copyWith(
          status: BadgesStatus.loaded,
          actionStatus: BadgeActionStatus.completed,
          awarded: dashboard.awarded,
          issued: dashboard.issued,
        ),
      );
    } catch (error, stackTrace) {
      addError(error, stackTrace);
      emit(
        state.copyWith(
          actionStatus: BadgeActionStatus.error,
        ),
      );
    }
  }
}
