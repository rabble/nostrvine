// ABOUTME: Tests for NotificationService permission handling and local notification display
// ABOUTME: Verifies platform-specific permission requests and notification sending functionality

import 'dart:convert';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/services/notification_helpers.dart'
    show localNotificationTapPayload;
import 'package:openvine/services/notification_service.dart';

class _MockFlutterLocalNotificationsPlugin extends Mock
    implements FlutterLocalNotificationsPlugin {}

void main() {
  group('NotificationService Permission Tests', () {
    late NotificationService notificationService;

    setUp(() {
      notificationService = NotificationService();
    });

    tearDown(() {
      notificationService.dispose();
    });

    test(
      'ensurePermission requests platform permissions on first call',
      () async {
        // Initially permissions should be false (not yet granted)
        expect(notificationService.hasPermissions, isFalse);

        // Request permissions
        await notificationService.ensurePermission();

        // After requesting, permissions should be granted
        // Note: In test environment, this will simulate granting permissions
        expect(notificationService.hasPermissions, isTrue);
      },
    );

    test(
      'ensurePermission skips re-request if permissions already granted',
      () async {
        // Grant permissions first time
        await notificationService.ensurePermission();
        expect(notificationService.hasPermissions, isTrue);

        // Second call should not throw or change state
        await notificationService.ensurePermission();
        expect(notificationService.hasPermissions, isTrue);
      },
    );

    test('ensurePermission handles permission denial gracefully', () async {
      // This test verifies that even if permissions are denied,
      // the service doesn't crash and sets state correctly
      await notificationService.ensurePermission();

      // Service should be in a valid state regardless of permission result
      expect(notificationService.mounted, isTrue);
    });

    test('sendLocal shows notification with title and body', () async {
      // Ensure permissions are granted first
      await notificationService.ensurePermission();

      // Send a local notification
      await notificationService.sendLocal(
        title: 'Test Notification',
        body: 'This is a test notification body',
      );

      // Verify notification was added to internal list
      expect(notificationService.notifications.length, equals(1));
      expect(
        notificationService.notifications.first.title,
        equals('Test Notification'),
      );
      expect(
        notificationService.notifications.first.body,
        equals('This is a test notification body'),
      );
    });

    test('sendLocal without permissions only adds to internal list', () async {
      // Do NOT call ensurePermission - no permissions granted
      expect(notificationService.hasPermissions, isFalse);

      // Send notification without permissions
      await notificationService.sendLocal(
        title: 'No Permission Test',
        body: 'Should only show in-app',
      );

      // Should still add to internal list for in-app display
      expect(notificationService.notifications.length, equals(1));
      expect(
        notificationService.notifications.first.title,
        equals('No Permission Test'),
      );
    });

    test('sendLocal handles empty title and body', () async {
      await notificationService.ensurePermission();

      // Send notification with empty strings
      await notificationService.sendLocal(title: '', body: '');

      // Should not crash and should add to list
      expect(notificationService.notifications.length, equals(1));
    });

    test('sendLocal adds multiple notifications in order', () async {
      await notificationService.ensurePermission();

      await notificationService.sendLocal(
        title: 'First',
        body: 'First notification',
      );
      await notificationService.sendLocal(
        title: 'Second',
        body: 'Second notification',
      );
      await notificationService.sendLocal(
        title: 'Third',
        body: 'Third notification',
      );

      expect(notificationService.notifications.length, equals(3));
      // Newest first (inserted at beginning)
      expect(notificationService.notifications[0].title, equals('Third'));
      expect(notificationService.notifications[1].title, equals('Second'));
      expect(notificationService.notifications[2].title, equals('First'));
    });
  });

  group('NotificationService Web Platform Tests', () {
    test('ensurePermission no-ops gracefully on web', () async {
      final service = NotificationService();

      // On web, this should not crash
      await service.ensurePermission();

      // Service should be in valid state
      expect(service.mounted, isTrue);

      service.dispose();
    });

    test('sendLocal works on web with limited functionality', () async {
      final service = NotificationService();

      await service.ensurePermission();
      await service.sendLocal(title: 'Web Test', body: 'Web notification');

      // Should at least add to internal list
      expect(service.notifications.isNotEmpty, isTrue);

      service.dispose();
    });
  });

  group('NotificationService Integration with existing methods', () {
    late NotificationService service;

    setUp(() {
      service = NotificationService();
    });

    tearDown(() {
      service.dispose();
    });

    test(
      'show() calls sendLocal internally when using custom notification',
      () async {
        await service.ensurePermission();

        final notification = AppNotification(
          title: 'Custom Notification',
          body: 'Custom body text',
          type: NotificationType.uploadComplete,
        );

        await service.show(notification);

        expect(service.notifications.length, equals(1));
        expect(
          service.notifications.first.title,
          equals('Custom Notification'),
        );
      },
    );

    test('showVideoPublished sends local notification', () async {
      await service.ensurePermission();

      await service.showVideoPublished(
        videoTitle: 'My Video',
        nostrEventId: 'event123',
        videoUrl: 'https://example.com/video',
      );

      expect(service.notifications.length, equals(1));
      expect(
        service.notifications.first.type,
        equals(NotificationType.videoPublished),
      );
    });

    test('showUploadComplete sends local notification', () async {
      await service.ensurePermission();

      await service.showUploadComplete(videoTitle: 'Upload Test');

      expect(service.notifications.length, equals(1));
      expect(
        service.notifications.first.type,
        equals(NotificationType.uploadComplete),
      );
    });

    test('showUploadFailed sends local notification', () async {
      await service.ensurePermission();

      await service.showUploadFailed(
        videoTitle: 'Failed Video',
        reason: 'Network error',
      );

      expect(service.notifications.length, equals(1));
      expect(
        service.notifications.first.type,
        equals(NotificationType.uploadFailed),
      );
    });
  });

  group('NotificationService.notificationTapStream', () {
    late NotificationService service;

    setUp(() {
      service = NotificationService();
    });

    tearDown(() {
      service.dispose();
    });

    // The FCM data map from divine-push-service uses 'type' (not 'notificationType').
    // _firebaseMessagingBackgroundHandler re-encodes it into our internal JSON
    // payload as 'notificationType' so the local notification tap handler can
    // read it back with the consistent internal key name.
    // See: docs/superpowers/specs/2026-04-07-push-notifications-design.md
    test('emits eventId and type from JSON payload', () async {
      final events = <NotificationTapEvent>[];
      final sub = service.notificationTapStream.listen(events.add);
      addTearDown(sub.cancel);

      service.handleNotificationTapPayload(
        jsonEncode({
          'referencedEventId': 'abc123',
          'notificationType': 'reply',
        }),
      );

      await Future<void>.delayed(Duration.zero);

      expect(events, hasLength(1));
      expect(events.single.referencedEventId, equals('abc123'));
      expect(events.single.notificationType, equals('reply'));
    });

    test(
      'emits the authoritative referencedAddress from JSON payload',
      () async {
        final events = <NotificationTapEvent>[];
        final sub = service.notificationTapStream.listen(events.add);
        addTearDown(sub.cancel);

        service.handleNotificationTapPayload(
          jsonEncode({
            'referencedEventId': 'video_event',
            'referencedAddress': '34236:owner_hex:my-vine-id',
            'notificationType': 'like',
          }),
        );

        await Future<void>.delayed(Duration.zero);

        expect(events, hasLength(1));
        expect(
          events.single.referencedAddress,
          equals('34236:owner_hex:my-vine-id'),
        );
      },
    );

    test('routes a payload that carries only referencedAddress', () async {
      // The coordinate alone is a valid video target — it must still emit.
      final events = <NotificationTapEvent>[];
      final sub = service.notificationTapStream.listen(events.add);
      addTearDown(sub.cancel);

      service.handleNotificationTapPayload(
        jsonEncode({'referencedAddress': '34236:owner_hex:vine-id'}),
      );

      await Future<void>.delayed(Duration.zero);

      expect(events, hasLength(1));
      expect(
        events.single.referencedAddress,
        equals('34236:owner_hex:vine-id'),
      );
    });

    test('emits null type when notificationType missing', () async {
      final events = <NotificationTapEvent>[];
      final sub = service.notificationTapStream.listen(events.add);
      addTearDown(sub.cancel);

      service.handleNotificationTapPayload(
        jsonEncode({'referencedEventId': 'def456'}),
      );

      await Future<void>.delayed(Duration.zero);

      expect(events, hasLength(1));
      expect(events.single.referencedEventId, equals('def456'));
      expect(events.single.notificationType, isNull);
    });

    test('does not emit and does not throw on non-JSON payload', () async {
      final events = <NotificationTapEvent>[];
      final sub = service.notificationTapStream.listen(events.add);
      addTearDown(sub.cancel);

      expect(
        () => service.handleNotificationTapPayload('not-json-at-all'),
        returnsNormally,
      );

      await Future<void>.delayed(Duration.zero);

      expect(events, isEmpty);
    });

    test(
      'does not emit and does not throw when JSON is not an object',
      () async {
        final events = <NotificationTapEvent>[];
        final sub = service.notificationTapStream.listen(events.add);
        addTearDown(sub.cancel);

        // A JSON array is valid JSON but not a Map<String, dynamic>.
        expect(
          () => service.handleNotificationTapPayload('[1,2,3]'),
          returnsNormally,
        );

        await Future<void>.delayed(Duration.zero);

        expect(events, isEmpty);
      },
    );

    test(
      'does not emit and does not throw when referencedEventId is not a string',
      () async {
        final events = <NotificationTapEvent>[];
        final sub = service.notificationTapStream.listen(events.add);
        addTearDown(sub.cancel);

        // referencedEventId is a number, not a String — field() returns null,
        // and the emit guard should suppress without throwing.
        expect(
          () => service.handleNotificationTapPayload(
            jsonEncode({'referencedEventId': 12345}),
          ),
          returnsNormally,
        );

        await Future<void>.delayed(Duration.zero);

        expect(events, isEmpty);
      },
    );

    test('does not emit when payload is null', () async {
      final events = <NotificationTapEvent>[];
      final sub = service.notificationTapStream.listen(events.add);
      addTearDown(sub.cancel);

      service.handleNotificationTapPayload(null);

      await Future<void>.delayed(Duration.zero);

      expect(events, isEmpty);
    });

    test('does not emit when nothing routable is present', () async {
      final events = <NotificationTapEvent>[];
      final sub = service.notificationTapStream.listen(events.add);
      addTearDown(sub.cancel);

      // No referencedEventId, eventId, or senderPubkey → nothing to route.
      service.handleNotificationTapPayload(
        jsonEncode({'notificationType': 'comment'}),
      );

      await Future<void>.delayed(Duration.zero);

      expect(events, isEmpty);
    });

    test('emits a follow tap via senderPubkey (no referencedEventId)', () async {
      final events = <NotificationTapEvent>[];
      final sub = service.notificationTapStream.listen(events.add);
      addTearDown(sub.cancel);

      // Follows carry senderPubkey + eventId but no referencedEventId; the tap
      // must still emit so the router can open the actor's profile.
      service.handleNotificationTapPayload(
        jsonEncode({
          'notificationType': 'follow',
          'eventId': 'contact_list_event',
          'senderPubkey': 'follower_hex',
        }),
      );

      await Future<void>.delayed(Duration.zero);

      expect(events, hasLength(1));
      expect(events.single.referencedEventId, isNull);
      expect(events.single.senderPubkey, equals('follower_hex'));
      expect(events.single.eventId, equals('contact_list_event'));
      expect(events.single.notificationType, equals('follow'));
    });

    test('a foreground-built local payload round-trips to a routable tap '
        'event', () async {
      final events = <NotificationTapEvent>[];
      final sub = service.notificationTapStream.listen(events.add);
      addTearDown(sub.cancel);

      // The exact payload the foreground path now attaches (built from FCM
      // data via the shared helper); tapping it must yield a routable event.
      final payload = jsonEncode(
        localNotificationTapPayload(const {
          'type': 'follow',
          'eventId': 'contact_event',
          'senderPubkey': 'follower_hex',
        }),
      );
      service.handleNotificationTapPayload(payload);
      await Future<void>.delayed(Duration.zero);

      expect(events, hasLength(1));
      expect(events.single.notificationType, equals('follow'));
      expect(events.single.senderPubkey, equals('follower_hex'));
      expect(events.single.eventId, equals('contact_event'));
      expect(events.single.referencedEventId, isNull);
    });

    test('no-ops gracefully when the stream has no listeners', () {
      expect(
        () => service.handleNotificationTapPayload(
          jsonEncode({
            'referencedEventId': 'abc',
            'notificationType': 'reply',
          }),
        ),
        returnsNormally,
      );
    });
  });

  group('sendLocal payload forwarding', () {
    late NotificationService service;
    late _MockFlutterLocalNotificationsPlugin plugin;

    setUp(() {
      service = NotificationService();
      plugin = _MockFlutterLocalNotificationsPlugin();
    });

    tearDown(() {
      service.dispose();
    });

    test('forwards the tap payload to the plugin show() call', () async {
      when(
        () => plugin.show(
          id: any(named: 'id'),
          title: any(named: 'title'),
          body: any(named: 'body'),
          notificationDetails: any(named: 'notificationDetails'),
          payload: any(named: 'payload'),
        ),
      ).thenAnswer((_) async {});

      service.debugConfigurePlugin(plugin);

      final payload = jsonEncode(
        localNotificationTapPayload(const {
          'type': 'comment',
          'eventId': 'comment_event',
          'referencedEventId': 'video_event',
          'senderPubkey': 'actor_hex',
        }),
      );

      await service.sendLocal(
        title: 'New comment',
        body: 'alice commented',
        payload: payload,
      );

      // The exact payload reaches the plugin's show(payload:) — the seam this
      // change adds. The round-trip test above proves the payload then parses
      // back to a routable tap event.
      final captured = verify(
        () => plugin.show(
          id: any(named: 'id'),
          title: 'New comment',
          body: 'alice commented',
          notificationDetails: any(named: 'notificationDetails'),
          payload: captureAny(named: 'payload'),
        ),
      ).captured;
      expect(captured.single, equals(payload));
    });

    test(
      'omits the payload (null) when sendLocal is called without one',
      () async {
        when(
          () => plugin.show(
            id: any(named: 'id'),
            title: any(named: 'title'),
            body: any(named: 'body'),
            notificationDetails: any(named: 'notificationDetails'),
            payload: any(named: 'payload'),
          ),
        ).thenAnswer((_) async {});

        service.debugConfigurePlugin(plugin);

        await service.sendLocal(title: 'Upload complete', body: 'done');

        final captured = verify(
          () => plugin.show(
            id: any(named: 'id'),
            title: any(named: 'title'),
            body: any(named: 'body'),
            notificationDetails: any(named: 'notificationDetails'),
            payload: captureAny(named: 'payload'),
          ),
        ).captured;
        expect(captured.single, isNull);
      },
    );
  });

  group('takeLaunchNotificationTap', () {
    late NotificationService service;
    late _MockFlutterLocalNotificationsPlugin plugin;

    setUp(() {
      service = NotificationService();
      plugin = _MockFlutterLocalNotificationsPlugin();
    });

    tearDown(() {
      service.dispose();
    });

    test(
      'routes a local notification that launched the app (cold start)',
      () async {
        when(() => plugin.getNotificationAppLaunchDetails()).thenAnswer(
          (_) async => NotificationAppLaunchDetails(
            true,
            notificationResponse: NotificationResponse(
              notificationResponseType:
                  NotificationResponseType.selectedNotification,
              payload: jsonEncode(
                localNotificationTapPayload(const {
                  'type': 'follow',
                  'eventId': 'contact_event',
                  'senderPubkey': 'follower_hex',
                }),
              ),
            ),
          ),
        );

        service.debugConfigurePlugin(plugin);

        final tap = await service.takeLaunchNotificationTap();

        expect(tap, isNotNull);
        expect(tap!.notificationType, equals('follow'));
        expect(tap.senderPubkey, equals('follower_hex'));
        expect(tap.eventId, equals('contact_event'));
        expect(tap.referencedEventId, isNull);
      },
    );

    test(
      'returns null when the app was not launched by a notification',
      () async {
        when(() => plugin.getNotificationAppLaunchDetails()).thenAnswer(
          (_) async => const NotificationAppLaunchDetails(false),
        );

        service.debugConfigurePlugin(plugin);

        expect(await service.takeLaunchNotificationTap(), isNull);
      },
    );

    test('returns null when there are no launch details', () async {
      when(
        () => plugin.getNotificationAppLaunchDetails(),
      ).thenAnswer((_) async => null);

      service.debugConfigurePlugin(plugin);

      expect(await service.takeLaunchNotificationTap(), isNull);
    });
  });

  group('NotificationTapEvent', () {
    test('uses value equality for event comparisons', () {
      const first = NotificationTapEvent(
        referencedEventId: 'abc123',
        referencedAddress: '34236:owner:vine',
        notificationType: 'reply',
      );
      const second = NotificationTapEvent(
        referencedEventId: 'abc123',
        referencedAddress: '34236:owner:vine',
        notificationType: 'reply',
      );
      const third = NotificationTapEvent(
        referencedEventId: 'xyz789',
        notificationType: 'reply',
      );
      const differsByAddress = NotificationTapEvent(
        referencedEventId: 'abc123',
        referencedAddress: '34236:owner:other-vine',
        notificationType: 'reply',
      );

      expect(first, equals(second));
      expect(first.hashCode, equals(second.hashCode));
      expect(first, isNot(equals(third)));
      expect(first, isNot(equals(differsByAddress)));
    });
  });
}
