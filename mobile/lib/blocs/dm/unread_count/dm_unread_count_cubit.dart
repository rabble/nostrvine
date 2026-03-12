// ABOUTME: Cubit that exposes the current unread DM conversation count.
// ABOUTME: Subscribes to the DmRepository's watchUnreadCount() stream
// ABOUTME: and emits the latest count as state.

import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:openvine/repositories/dm_repository.dart';

/// Cubit that tracks the number of unread DM conversations.
///
/// Subscribes to [DmRepository.watchUnreadCount] and emits the latest
/// count. Used by the bottom nav badge and inbox tab toggle.
class DmUnreadCountCubit extends Cubit<int> {
  DmUnreadCountCubit({required DmRepository dmRepository})
    : _dmRepository = dmRepository,
      super(0) {
    _subscription = _dmRepository.watchUnreadCount().listen(
      emit,
      onError: addError,
    );
  }

  final DmRepository _dmRepository;
  StreamSubscription<int>? _subscription;

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }
}
