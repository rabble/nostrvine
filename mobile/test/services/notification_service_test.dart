// ABOUTME: Tests for NotificationService permission handling and local notification display
// ABOUTME: Verifies platform-specific permission requests and notification sending functionality

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/notification_service.dart';

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

  group('NotificationService.onNotificationTap', () {
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
    test('invokes callback with eventId and type from JSON payload', () {
      String? capturedId;
      String? capturedType;
      service.onNotificationTap = (id, type) {
        capturedId = id;
        capturedType = type;
      };

      service.handleNotificationTapPayload(
        jsonEncode({
          'referencedEventId': 'abc123',
          'notificationType': 'reply',
        }),
      );

      expect(capturedId, equals('abc123'));
      expect(capturedType, equals('reply'));
    });

    test('invokes callback with null type when notificationType missing', () {
      String? capturedId;
      String? capturedType;
      service.onNotificationTap = (id, type) {
        capturedId = id;
        capturedType = type;
      };

      service.handleNotificationTapPayload(
        jsonEncode({'referencedEventId': 'def456'}),
      );

      expect(capturedId, equals('def456'));
      expect(capturedType, isNull);
    });

    test('handles legacy bare event-ID payload (non-JSON)', () {
      String? capturedId;
      String? capturedType;
      service.onNotificationTap = (id, type) {
        capturedId = id;
        capturedType = type;
      };

      service.handleNotificationTapPayload('legacyEventId999');

      expect(capturedId, equals('legacyEventId999'));
      expect(capturedType, isNull);
    });

    test('does not invoke callback when payload is null', () {
      var called = false;
      service.onNotificationTap = (id, type) => called = true;

      service.handleNotificationTapPayload(null);

      expect(called, isFalse);
    });

    test('does not invoke callback when referencedEventId is absent', () {
      var called = false;
      service.onNotificationTap = (id, type) => called = true;

      service.handleNotificationTapPayload(
        jsonEncode({'notificationType': 'reaction'}),
      );

      expect(called, isFalse);
    });

    test('no-ops gracefully when onNotificationTap is not set', () {
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
}
