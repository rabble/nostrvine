// ABOUTME: BLoC for the notification feed — handles initial load, pagination,
// ABOUTME: pull-to-refresh, push/realtime events, mark-read, and follow-back.

import 'dart:async';

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:follow_repository/follow_repository.dart';
import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:models/models.dart';
import 'package:notification_repository/notification_repository.dart';

part 'notification_feed_event.dart';
part 'notification_feed_state.dart';

/// BLoC for managing the notification feed.
///
/// Handles:
/// - Initial load and pagination
/// - Pull-to-refresh and push notification nudges
/// - WebSocket real-time notification insertion
/// - Mark as read (single and all)
/// - Follow-back from follow notifications
class NotificationFeedBloc
    extends Bloc<NotificationFeedEvent, NotificationFeedState> {
  NotificationFeedBloc({
    required NotificationRepository notificationRepository,
    required FollowRepository followRepository,
  }) : _notificationRepository = notificationRepository,
       _followRepository = followRepository,
       super(const NotificationFeedState()) {
    on<NotificationFeedStarted>(
      _onStarted,
      transformer: droppable(),
    );
    on<NotificationFeedLoadMore>(
      _onLoadMore,
      transformer: droppable(),
    );
    on<NotificationFeedRefreshed>(
      _onRefreshed,
      transformer: droppable(),
    );
    on<NotificationFeedPushReceived>(
      _onPushReceived,
      transformer: droppable(),
    );
    on<NotificationFeedRealtimeReceived>(
      _onRealtimeReceived,
      transformer: sequential(),
    );
    on<NotificationFeedItemTapped>(_onItemTapped);
    on<NotificationFeedMarkAllRead>(_onMarkAllRead);
    on<NotificationFeedFollowBack>(
      _onFollowBack,
      transformer: sequential(),
    );
  }

  final NotificationRepository _notificationRepository;
  final FollowRepository _followRepository;

  /// Handle initial load.
  Future<void> _onStarted(
    NotificationFeedStarted event,
    Emitter<NotificationFeedState> emit,
  ) async {
    emit(state.copyWith(status: NotificationFeedStatus.loading));

    try {
      final page = await _notificationRepository.refresh();

      emit(
        state.copyWith(
          status: NotificationFeedStatus.loaded,
          notifications: page.items,
          unreadCount: page.unreadCount,
          hasMore: page.hasMore,
        ),
      );
    } catch (e, s) {
      addError(e, s);
      emit(state.copyWith(status: NotificationFeedStatus.failure));
    }
  }

  /// Handle scroll pagination.
  Future<void> _onLoadMore(
    NotificationFeedLoadMore event,
    Emitter<NotificationFeedState> emit,
  ) async {
    if (!state.hasMore || state.isLoadingMore) return;

    emit(state.copyWith(isLoadingMore: true));

    try {
      final page = await _notificationRepository.getNotifications();

      // Deduplicate by ID — keep existing items, append only new ones.
      final existingIds = state.notifications.map((n) => n.id).toSet();
      final newItems = page.items
          .where((n) => !existingIds.contains(n.id))
          .toList();

      emit(
        state.copyWith(
          notifications: [...state.notifications, ...newItems],
          hasMore: page.hasMore,
          isLoadingMore: false,
        ),
      );
    } catch (e, s) {
      addError(e, s);
      emit(state.copyWith(isLoadingMore: false));
    }
  }

  /// Handle pull-to-refresh.
  Future<void> _onRefreshed(
    NotificationFeedRefreshed event,
    Emitter<NotificationFeedState> emit,
  ) async {
    try {
      final page = await _notificationRepository.refresh();

      emit(
        state.copyWith(
          status: NotificationFeedStatus.loaded,
          notifications: page.items,
          unreadCount: page.unreadCount,
          hasMore: page.hasMore,
        ),
      );
    } catch (e, s) {
      addError(e, s);
      emit(state.copyWith(status: NotificationFeedStatus.failure));
    }
  }

  /// Handle push notification — triggers a full refresh.
  Future<void> _onPushReceived(
    NotificationFeedPushReceived event,
    Emitter<NotificationFeedState> emit,
  ) async {
    try {
      final page = await _notificationRepository.refresh();

      emit(
        state.copyWith(
          status: NotificationFeedStatus.loaded,
          notifications: page.items,
          unreadCount: page.unreadCount,
          hasMore: page.hasMore,
        ),
      );
    } catch (e, s) {
      addError(e, s);
      // Keep current state on push-refresh failure — don't lose data.
    }
  }

  /// Handle WebSocket real-time notification.
  ///
  /// Enriches the raw [RelayNotification] via the repository (profile +
  /// video metadata fetched in parallel), then either merges the new
  /// actor into an existing matching [VideoNotification] group or
  /// inserts the enriched item at the top.
  Future<void> _onRealtimeReceived(
    NotificationFeedRealtimeReceived event,
    Emitter<NotificationFeedState> emit,
  ) async {
    final enriched = await _notificationRepository.enrichOne(event.raw);
    if (enriched == null) return;

    // Already shown? skip.
    final exists = state.notifications.any((n) => n.id == enriched.id);
    if (exists) return;

    // Try to merge into an existing matching VideoNotification group.
    if (enriched is VideoNotification) {
      final mergedList = <NotificationItem>[];
      var merged = false;
      for (final existing in state.notifications) {
        if (!merged &&
            existing is VideoNotification &&
            existing.videoEventId == enriched.videoEventId &&
            existing.type == enriched.type) {
          final mergedActors = [
            enriched.actors.first,
            ...existing.actors,
          ].take(3).toList();
          mergedList.add(
            existing.copyWith(
              actors: mergedActors,
              totalCount: existing.totalCount + 1,
              isRead: false,
              timestamp: enriched.timestamp,
            ),
          );
          merged = true;
        } else {
          mergedList.add(existing);
        }
      }
      if (merged) {
        emit(
          state.copyWith(
            notifications: mergedList,
            unreadCount: state.unreadCount + 1,
          ),
        );
        return;
      }
    }

    emit(
      state.copyWith(
        notifications: [enriched, ...state.notifications],
        unreadCount: state.unreadCount + 1,
      ),
    );
  }

  /// Handle notification tap — mark as read locally and on server.
  Future<void> _onItemTapped(
    NotificationFeedItemTapped event,
    Emitter<NotificationFeedState> emit,
  ) async {
    final updated = state.notifications.map((n) {
      if (n.id != event.notificationId || n.isRead) return n;
      return switch (n) {
        VideoNotification() => n.copyWith(isRead: true),
        ActorNotification() => n.copyWith(isRead: true),
      };
    }).toList();

    final wasUnread = state.notifications.any(
      (n) => n.id == event.notificationId && !n.isRead,
    );

    emit(
      state.copyWith(
        notifications: updated,
        unreadCount: wasUnread
            ? (state.unreadCount - 1).clamp(0, state.unreadCount)
            : state.unreadCount,
      ),
    );

    unawaited(
      _notificationRepository.markAsRead([event.notificationId]),
    );
  }

  /// Handle mark all as read.
  Future<void> _onMarkAllRead(
    NotificationFeedMarkAllRead event,
    Emitter<NotificationFeedState> emit,
  ) async {
    emit(state.copyWith(unreadCount: 0));

    unawaited(_notificationRepository.markAllAsRead());
  }

  /// Handle follow-back action.
  ///
  /// Calls the follow repository, then updates the matching notification
  /// to show the follow-back state.
  Future<void> _onFollowBack(
    NotificationFeedFollowBack event,
    Emitter<NotificationFeedState> emit,
  ) async {
    try {
      await _followRepository.follow(event.pubkey);

      final updated = state.notifications.map((n) {
        if (n is ActorNotification &&
            n.type == NotificationKind.follow &&
            n.actor.pubkey == event.pubkey) {
          return n.copyWith(isFollowingBack: true);
        }
        return n;
      }).toList();

      emit(state.copyWith(notifications: updated));
    } catch (e, s) {
      addError(e, s);
    }
  }
}
