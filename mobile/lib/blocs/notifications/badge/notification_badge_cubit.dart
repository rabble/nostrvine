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
/// at zero with no subscription, and a fresh cubit is constructed once
/// the repository is available (callers should `ValueKey` on the
/// repository identity for re-instantiation).
class NotificationBadgeCubit extends Cubit<int> {
  NotificationBadgeCubit({NotificationRepository? repository}) : super(0) {
    if (repository != null) {
      _subscription = repository.watchUnreadCount().listen(
        emit,
        onError: addError,
      );
    }
  }

  StreamSubscription<int>? _subscription;

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    await super.close();
  }
}
