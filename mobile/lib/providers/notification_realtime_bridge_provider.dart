// ABOUTME: Bridge provider connecting WebSocket real-time notifications
// ABOUTME: to the REST-based Riverpod notification state for instant updates

import 'dart:async';

import 'package:openvine/providers/relay_notifications_provider.dart';
import 'package:openvine/services/notification_service_enhanced.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'notification_realtime_bridge_provider.g.dart';

/// Bridge that listens to WebSocket notifications from
/// [NotificationServiceEnhanced] and inserts them into the
/// REST-based [RelayNotifications] provider for instant UI updates.
///
/// This provider is kept alive so it runs in the background as long as
/// the app is active.
@Riverpod(keepAlive: true)
class NotificationRealtimeBridge extends _$NotificationRealtimeBridge {
  StreamSubscription<void>? _subscription;

  @override
  int build() {
    final service = NotificationServiceEnhanced.instance;

    _subscription?.cancel();
    _subscription = service.onNewNotification.listen((notification) {
      Log.debug(
        'NotificationRealtimeBridge: Received WebSocket notification '
        '${notification.id}',
        name: 'NotificationRealtimeBridge',
        category: LogCategory.system,
      );

      // Insert into the Riverpod notification state
      ref
          .read(relayNotificationsProvider.notifier)
          .insertFromWebSocket(notification);

      // Increment counter to track bridged notifications
      if (ref.mounted) {
        state = state + 1;
      }
    });

    ref.onDispose(() {
      _subscription?.cancel();
      _subscription = null;
    });

    return 0;
  }
}
