// ABOUTME: Cubit that exposes the current unread notification count.
// ABOUTME: Subscribes to NotificationRepository.watchUnreadCount() and emits
// ABOUTME: the latest count as state.

import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:notification_repository/notification_repository.dart';

/// Cubit that tracks the number of unread notifications.
///
/// Subscribes to [NotificationRepository.watchUnreadCount] and emits the
/// latest post-consolidation count. Used by the bottom-nav badge and the
/// inbox segmented toggle.
///
/// Mirrors `DmUnreadCountCubit` in shape so the inbox treats DMs and
/// notifications symmetrically.
///
/// `repository` may be `null` during early auth — the badge then stays
/// at zero with no subscription. Call [setRepository] when the repository
/// identity changes so only this cubit's stream subscription is replaced.
class NotificationBadgeCubit extends Cubit<int> {
  NotificationBadgeCubit({NotificationRepository? repository}) : super(0) {
    setRepository(repository);
  }

  NotificationRepository? _repository;
  StreamSubscription<int>? _subscription;

  void setRepository(NotificationRepository? repository) {
    if (identical(_repository, repository)) return;

    _repository = repository;
    final oldSubscription = _subscription;
    _subscription = null;
    if (oldSubscription != null) {
      unawaited(oldSubscription.cancel());
    }

    if (repository == null) {
      emit(0);
      return;
    }

    _subscription = repository.watchUnreadCount().listen(
      emit,
      onError: addError,
    );
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    await super.close();
  }
}
