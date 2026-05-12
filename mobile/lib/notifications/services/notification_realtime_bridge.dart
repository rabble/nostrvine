// ABOUTME: Forwards real-time WebSocket notifications from
// ABOUTME: NotificationServiceEnhanced into the new NotificationRepository
// ABOUTME: snapshot so the badge cubit and feed bloc see them.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:meta/meta.dart';
import 'package:models/models.dart';
import 'package:notification_repository/notification_repository.dart';
import 'package:openvine/notifications/providers/notification_repository_provider.dart';
import 'package:openvine/services/notification_service_enhanced.dart';
import 'package:unified_logger/unified_logger.dart';

/// Riverpod provider that builds (and disposes) a
/// [NotificationRealtimeBridge] keyed on the active
/// [NotificationRepository]'s identity.
///
/// Returns `null` while the repository itself is null (early auth). When
/// the repository flips (account switch, sign-out + sign-in), the
/// provider rebuilds, the previous bridge is disposed, and a fresh one
/// subscribes to the new repository's [NotificationRepository.acceptRealtime].
final notificationRealtimeBridgeProvider =
    Provider<NotificationRealtimeBridge?>((ref) {
      final repository = ref.watch(notificationRepositoryProvider);
      if (repository == null) return null;
      final bridge = NotificationRealtimeBridge(repository: repository);
      ref.onDispose(bridge.dispose);
      return bridge;
    });

/// Bridge that listens to WebSocket notifications from
/// [NotificationServiceEnhanced] and pushes them into
/// [NotificationRepository.acceptRealtime] so the new single-source-of-truth
/// snapshot — and therefore both the badge cubit and the feed bloc — see
/// real-time arrivals.
///
/// Replaces the BLoC's previous unfired realtime event path; WS arrivals
/// now flow through the repository so the badge cubit and the feed bloc
/// stay in lock-step.
///
/// Construct one instance per repository identity (i.e. per authenticated
/// user). The bridge holds the subscription for its lifetime; call [dispose]
/// when the underlying repository is being replaced (auth flip, sign-out).
class NotificationRealtimeBridge {
  /// Creates a bridge and starts listening immediately.
  ///
  /// [stream] defaults to `NotificationServiceEnhanced.instance.onNewNotification`
  /// in production. Tests inject a controlled stream so the bridge can be
  /// exercised without driving the WS service singleton.
  NotificationRealtimeBridge({
    required NotificationRepository repository,
    Stream<NotificationModel>? stream,
  }) : _repository = repository {
    _subscription =
        (stream ?? NotificationServiceEnhanced.instance.onNewNotification)
            .listen(_onModel, onError: _onError);
  }

  final NotificationRepository _repository;
  StreamSubscription<NotificationModel>? _subscription;

  Future<void> _onModel(NotificationModel model) async {
    try {
      await _repository.acceptRealtime(modelToRelay(model));
    } catch (e, s) {
      Log.error(
        'NotificationRealtimeBridge: failed to accept realtime: $e',
        name: 'NotificationRealtimeBridge',
        category: LogCategory.system,
        error: e,
        stackTrace: s,
      );
    }
  }

  void _onError(Object error, StackTrace stackTrace) {
    Log.error(
      'NotificationRealtimeBridge: stream error: $error',
      name: 'NotificationRealtimeBridge',
      category: LogCategory.system,
      error: error,
      stackTrace: stackTrace,
    );
  }

  /// Cancels the WebSocket subscription. Call when the repository this
  /// bridge feeds is being replaced.
  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
  }

  /// Adapts a legacy [NotificationModel] (the WS service's emission shape)
  /// to a [RelayNotification] (the REST/repository ingest shape).
  ///
  /// Lossy by design — fields the WS path does not carry (server-side
  /// `referenced_video` payload) are populated best-effort from the
  /// model's metadata map.
  @visibleForTesting
  static RelayNotification modelToRelay(NotificationModel model) {
    final metadata = model.metadata;
    final sourceEventId = (metadata?['sourceEventId'] as String?) ?? model.id;
    final referencedDTag = metadata?['referencedDTag'] as String?;
    final referencedVideoTitle = metadata?['referencedVideoTitle'] as String?;
    return RelayNotification(
      id: model.id,
      sourcePubkey: model.actorPubkey,
      sourceEventId: sourceEventId,
      sourceKind: _kindForType(model.type),
      notificationType: _notificationTypeStringFor(model.type),
      createdAt: model.timestamp,
      read: model.isRead,
      referencedEventId: model.targetEventId,
      content: _contentForType(model.type, metadata),
      isReferencedVideo:
          model.targetVideoUrl != null || model.targetVideoThumbnail != null,
      referencedVideoTitle: referencedVideoTitle,
      referencedVideoThumbnail: model.targetVideoThumbnail,
      referencedDTag: referencedDTag,
    );
  }

  /// Extracts the raw body text for [type] from a [NotificationModel]'s
  /// metadata.
  ///
  /// `NotificationServiceEnhanced` puts the comment body under
  /// `metadata['comment']` and mention text under `metadata['text']`.
  /// The REST path also surfaces a unified `metadata['content']`
  /// alongside those — accepted here as a fallback. Likes, reposts,
  /// follows, and system notifications have no raw body, so [content]
  /// stays null and rows fall back to the presentation message
  /// produced by the repository.
  static String? _contentForType(
    NotificationType type,
    Map<String, dynamic>? metadata,
  ) {
    if (metadata == null) return null;
    return switch (type) {
      NotificationType.comment =>
        (metadata['comment'] as String?) ?? (metadata['content'] as String?),
      NotificationType.mention =>
        (metadata['text'] as String?) ?? (metadata['content'] as String?),
      NotificationType.like ||
      NotificationType.repost ||
      NotificationType.follow ||
      NotificationType.system => null,
    };
  }

  /// Returns the Nostr kind the WS service uses for the given
  /// notification type. Mirrors the routing in
  /// `notification_service_enhanced.dart`.
  static int _kindForType(NotificationType type) => switch (type) {
    NotificationType.like => 7, // reaction
    NotificationType.comment => 1111, // NIP-22 comment
    NotificationType.repost => 6, // repost
    NotificationType.follow => 3, // contact list
    NotificationType.mention => 1, // text note with mention
    NotificationType.system => 0,
  };

  /// String form expected by the REST API for the same set of kinds.
  static String _notificationTypeStringFor(NotificationType type) =>
      switch (type) {
        NotificationType.like => 'reaction',
        NotificationType.comment => 'comment',
        NotificationType.repost => 'repost',
        NotificationType.follow => 'follow',
        NotificationType.mention => 'mention',
        NotificationType.system => 'system',
      };
}
