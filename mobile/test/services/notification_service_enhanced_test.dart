// ABOUTME: Tests for NotificationServiceEnhanced social notification handling
// ABOUTME: Verifies race condition fixes and concurrent notification deduplication

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:models/models.dart';
import 'package:openvine/services/notification_service_enhanced.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:openvine/services/user_profile_service.dart';
import 'package:openvine/services/video_event_service.dart';

@GenerateMocks([NostrClient, UserProfileService, VideoEventService])
import 'notification_service_enhanced_test.mocks.dart';

void main() {
  group('NotificationServiceEnhanced Race Condition Tests', () {
    late NotificationServiceEnhanced service;
    late MockNostrClient mockNostrService;
    late MockUserProfileService mockProfileService;
    late MockVideoEventService mockVideoService;

    setUp(() {
      service = NotificationServiceEnhanced();
      mockNostrService = MockNostrClient();
      mockProfileService = MockUserProfileService();
      mockVideoService = MockVideoEventService();

      // Setup mock responses
      when(mockNostrService.hasKeys).thenReturn(true);
      when(mockNostrService.publicKey).thenReturn('test-pubkey-123');
      when(
        mockNostrService.subscribe(argThat(anything)),
      ).thenAnswer((_) => Stream.empty());
    });

    tearDown(() {
      service.dispose();
    });

    test(
      'concurrent addNotificationForTesting calls with same ID should only add once',
      () async {
        // Initialize the service
        await service.initialize(
          nostrService: mockNostrService,
          profileService: mockProfileService,
          videoService: mockVideoService,
        );

        // Create identical notifications (same ID)
        final notification1 = NotificationModel(
          id: 'duplicate-test-id',
          type: NotificationType.like,
          actorPubkey: 'actor-pubkey',
          actorName: 'Test User',
          message: 'Test User liked your video',
          timestamp: DateTime.now(),
        );

        final notification2 = NotificationModel(
          id: 'duplicate-test-id', // Same ID - should be deduplicated
          type: NotificationType.like,
          actorPubkey: 'actor-pubkey',
          actorName: 'Test User',
          message: 'Test User liked your video',
          timestamp: DateTime.now(),
        );

        // Simulate race condition: add both concurrently
        // This tests that the fix (mutex lock) prevents duplicates
        await Future.wait([
          service.addNotificationForTesting(notification1),
          service.addNotificationForTesting(notification2),
        ]);

        // Should only have ONE notification, not two
        expect(
          service.notifications.length,
          equals(1),
          reason: 'Race condition: duplicate notification was added',
        );
        expect(service.notifications.first.id, equals('duplicate-test-id'));
      },
    );

    test(
      'concurrent addNotificationForTesting calls with different IDs should add both',
      () async {
        await service.initialize(
          nostrService: mockNostrService,
          profileService: mockProfileService,
          videoService: mockVideoService,
        );

        final notification1 = NotificationModel(
          id: 'notification-1',
          type: NotificationType.like,
          actorPubkey: 'actor-1',
          actorName: 'User 1',
          message: 'User 1 liked your video',
          timestamp: DateTime.now(),
        );

        final notification2 = NotificationModel(
          id: 'notification-2',
          type: NotificationType.comment,
          actorPubkey: 'actor-2',
          actorName: 'User 2',
          message: 'User 2 commented on your video',
          timestamp: DateTime.now(),
        );

        // Add both concurrently
        await Future.wait([
          service.addNotificationForTesting(notification1),
          service.addNotificationForTesting(notification2),
        ]);

        // Should have BOTH notifications
        expect(service.notifications.length, equals(2));
        expect(
          service.notifications.map((n) => n.id).toSet(),
          equals({'notification-1', 'notification-2'}),
        );
      },
    );

    test('rapid sequential adds with same ID should only add once', () async {
      await service.initialize(
        nostrService: mockNostrService,
        profileService: mockProfileService,
        videoService: mockVideoService,
      );

      final notification = NotificationModel(
        id: 'rapid-test-id',
        type: NotificationType.like,
        actorPubkey: 'actor-pubkey',
        actorName: 'Test User',
        message: 'Test User liked your video',
        timestamp: DateTime.now(),
      );

      // Add same notification 10 times rapidly
      await Future.wait(
        List.generate(
          10,
          (_) => service.addNotificationForTesting(notification),
        ),
      );

      // Should only have ONE notification
      expect(service.notifications.length, equals(1));
    });

    test('stress test: 100 concurrent adds with mixed IDs', () async {
      await service.initialize(
        nostrService: mockNostrService,
        profileService: mockProfileService,
        videoService: mockVideoService,
      );

      // Create 10 unique notification IDs, but add each one 10 times
      final futures = <Future<void>>[];
      for (var i = 0; i < 10; i++) {
        for (var j = 0; j < 10; j++) {
          final notification = NotificationModel(
            id: 'notification-$i', // Same ID for all j iterations
            type: NotificationType.like,
            actorPubkey: 'actor-$i',
            actorName: 'User $i',
            message: 'User $i liked your video',
            timestamp: DateTime.now(),
          );
          futures.add(service.addNotificationForTesting(notification));
        }
      }

      await Future.wait(futures);

      // Should only have 10 unique notifications (not 100)
      expect(
        service.notifications.length,
        equals(10),
        reason: 'Stress test: duplicates were not properly filtered',
      );

      // Verify all 10 unique IDs are present
      final ids = service.notifications.map((n) => n.id).toSet();
      expect(ids.length, equals(10));
      for (var i = 0; i < 10; i++) {
        expect(ids.contains('notification-$i'), isTrue);
      }
    });
  });

  group('NotificationServiceEnhanced Chronological Order Tests', () {
    late NotificationServiceEnhanced service;
    late MockNostrClient mockNostrService;
    late MockUserProfileService mockProfileService;
    late MockVideoEventService mockVideoService;

    setUp(() {
      service = NotificationServiceEnhanced();
      mockNostrService = MockNostrClient();
      mockProfileService = MockUserProfileService();
      mockVideoService = MockVideoEventService();

      when(mockNostrService.hasKeys).thenReturn(true);
      when(mockNostrService.publicKey).thenReturn('test-pubkey-123');
      when(
        mockNostrService.subscribe(argThat(anything)),
      ).thenAnswer((_) => Stream.empty());
    });

    tearDown(() {
      service.dispose();
    });

    test(
      'notifications are sorted by timestamp (newest first) regardless of insertion order',
      () async {
        await service.initialize(
          nostrService: mockNostrService,
          profileService: mockProfileService,
          videoService: mockVideoService,
        );

        // Add notifications OUT OF ORDER (older first, then newer)
        final olderNotification = NotificationModel(
          id: 'older-notification',
          type: NotificationType.like,
          actorPubkey: 'actor-1',
          actorName: 'User 1',
          message: 'User 1 liked your video',
          timestamp: DateTime(2024, 1, 1, 10, 0), // Older
        );

        final newerNotification = NotificationModel(
          id: 'newer-notification',
          type: NotificationType.like,
          actorPubkey: 'actor-2',
          actorName: 'User 2',
          message: 'User 2 liked your video',
          timestamp: DateTime(2024, 1, 2, 10, 0), // Newer
        );

        // Add older first, then newer (simulating out-of-order Nostr events)
        await service.addNotificationForTesting(olderNotification);
        await service.addNotificationForTesting(newerNotification);

        // Should be sorted newest first
        expect(service.notifications.length, equals(2));
        expect(
          service.notifications.first.id,
          equals('newer-notification'),
          reason: 'Newest notification should be first',
        );
        expect(
          service.notifications.last.id,
          equals('older-notification'),
          reason: 'Older notification should be last',
        );
      },
    );

    test(
      'getNotificationsByType returns filtered results in chronological order',
      () async {
        await service.initialize(
          nostrService: mockNostrService,
          profileService: mockProfileService,
          videoService: mockVideoService,
        );

        // Add mixed notification types out of order
        final oldLike = NotificationModel(
          id: 'old-like',
          type: NotificationType.like,
          actorPubkey: 'actor-1',
          actorName: 'User 1',
          message: 'User 1 liked your video',
          timestamp: DateTime(2024, 1, 1),
        );

        final newComment = NotificationModel(
          id: 'new-comment',
          type: NotificationType.comment,
          actorPubkey: 'actor-2',
          actorName: 'User 2',
          message: 'User 2 commented',
          timestamp: DateTime(2024, 1, 3),
        );

        final newLike = NotificationModel(
          id: 'new-like',
          type: NotificationType.like,
          actorPubkey: 'actor-3',
          actorName: 'User 3',
          message: 'User 3 liked your video',
          timestamp: DateTime(2024, 1, 2),
        );

        // Add in scrambled order
        await service.addNotificationForTesting(oldLike);
        await service.addNotificationForTesting(newComment);
        await service.addNotificationForTesting(newLike);

        // Get only likes - should be sorted newest first
        final likes = service.getNotificationsByType(NotificationType.like);

        expect(likes.length, equals(2));
        expect(
          likes.first.id,
          equals('new-like'),
          reason: 'Filtered likes should be sorted newest first',
        );
        expect(likes.last.id, equals('old-like'));
      },
    );

    test('notifications with same timestamp are stable-sorted by ID', () async {
      await service.initialize(
        nostrService: mockNostrService,
        profileService: mockProfileService,
        videoService: mockVideoService,
      );

      final sameTime = DateTime(2024, 1, 1, 12, 0);

      // Add notifications with identical timestamps but different IDs
      final notificationB = NotificationModel(
        id: 'bbb-notification',
        type: NotificationType.like,
        actorPubkey: 'actor-b',
        actorName: 'User B',
        message: 'User B liked your video',
        timestamp: sameTime,
      );

      final notificationA = NotificationModel(
        id: 'aaa-notification',
        type: NotificationType.like,
        actorPubkey: 'actor-a',
        actorName: 'User A',
        message: 'User A liked your video',
        timestamp: sameTime,
      );

      await service.addNotificationForTesting(notificationB);
      await service.addNotificationForTesting(notificationA);

      // With same timestamp, should be stable-sorted by ID (ascending)
      expect(service.notifications.length, equals(2));
      expect(
        service.notifications.first.id,
        equals('aaa-notification'),
        reason: 'Same timestamp: should be sorted by ID for stability',
      );
      expect(service.notifications.last.id, equals('bbb-notification'));
    });
  });
}
