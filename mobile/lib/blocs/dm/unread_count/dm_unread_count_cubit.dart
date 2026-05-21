// ABOUTME: Cubit that exposes the current unread DM conversation count.
// ABOUTME: Subscribes to the DmRepository's watchUnreadCount() stream
// ABOUTME: and emits the latest count as state.

import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:dm_repository/dm_repository.dart';

/// Cubit that tracks the number of unread DM conversations.
///
/// Subscribes to [DmRepository.watchUnreadAcceptedCount] and emits the
/// latest count. Only counts conversations where the user has sent at
/// least one message, excluding message requests from unknown contacts.
/// Used by the bottom nav badge and inbox tab toggle.
class DmUnreadCountCubit extends Cubit<int> {
  DmUnreadCountCubit({required DmRepository dmRepository})
    : _dmRepository = dmRepository,
      super(0) {
    // Stream errors here are Drift IO from `watchUnreadAcceptedCount`.
    // Per .claude/rules/error_handling.md these are matrix-NO; the
    // tear-off forwards them to `addError` so they land in the unified
    // log without flooding Crashlytics.
    _subscription = _dmRepository.watchUnreadAcceptedCount().listen(
      emit,
      onError: addError,
    );
  }

  final DmRepository _dmRepository;
  StreamSubscription<int>? _subscription;

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    await super.close();
  }
}
