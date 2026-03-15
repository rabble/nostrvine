// ABOUTME: Navigation-focused tests for notifications to ensure video targets resolve correctly

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/providers/relay_notifications_provider.dart';
import 'package:openvine/screens/notifications_screen.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:openvine/widgets/notification_list_item.dart';

class _MockRelayNotifications extends RelayNotifications {
  final List<NotificationModel> _notifications;

  _MockRelayNotifications(this._notifications);

  @override
  Future<NotificationFeedState> build() async => NotificationFeedState(
    notifications: _notifications,
    isInitialLoad: false,
    lastUpdated: DateTime.now(),
  );

  @override
  Future<void> markAsRead(String notificationId) async {}

  @override
  Future<void> markAllAsRead() async {}
}

class _MockVideoEventService extends Mock implements VideoEventService {}

class _MockNostrClient extends Mock implements NostrClient {}

void main() {
  Widget screen(
    RelayNotifications Function() notifierFactory, {
    required VideoEventService videoService,
    required NostrClient nostrClient,
  }) {
    return ProviderScope(
      overrides: [
        relayNotificationsProvider.overrideWith(notifierFactory),
        videoEventServiceProvider.overrideWithValue(videoService),
        nostrServiceProvider.overrideWithValue(nostrClient),
      ],
      child: const MaterialApp(
        home: Scaffold(body: NotificationsScreen()),
      ),
    );
  }

  VideoEvent video(String id) => VideoEvent(
    id: id,
    pubkey: 'pubkey_$id',
    createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
    timestamp: DateTime.now(),
    content: 'content',
    title: 'title',
    videoUrl: 'https://example.com/$id.mp4',
    thumbnailUrl: 'https://example.com/$id.jpg',
  );

  Event commentEvent({required String rootVideoId}) => Event(
    'd' * 64,
    1111,
    [
      ['e', rootVideoId, '', 'root'],
      ['e', 'parent_comment', '', 'reply'],
    ],
    'comment body',
    createdAt: 123456,
  );

  group('notifications navigation resolution', () {
    testWidgets('comment target id resolves to parent video and opens video view', (
      tester,
    ) async {
      final mockVideoService = _MockVideoEventService();
      final mockNostrClient = _MockNostrClient();

      final resolvedVideo = video('video_root_1');
      when(() => mockVideoService.getVideoById('comment_event_1')).thenReturn(null);
      when(() => mockVideoService.getVideoById('video_root_1')).thenReturn(resolvedVideo);
      when(() => mockVideoService.shouldHideVideo(resolvedVideo)).thenReturn(true);
      when(() => mockNostrClient.fetchEventById('comment_event_1'))
          .thenAnswer((_) async => commentEvent(rootVideoId: 'video_root_1'));

      final notifier = _MockRelayNotifications([
        NotificationModel(
          id: 'notif-comment',
          type: NotificationType.comment,
          actorPubkey: 'a' * 64,
          actorName: 'Commenter',
          message: 'replied to your comment',
          timestamp: DateTime.now(),
          targetEventId: 'comment_event_1',
        ),
      ]);

      await tester.pumpWidget(
        screen(
          () => notifier,
          videoService: mockVideoService,
          nostrClient: mockNostrClient,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(NotificationListItem).first);
      await tester.pumpAndSettle();

      verify(() => mockVideoService.getVideoById('video_root_1')).called(1);
      expect(find.text('Video not found'), findsNothing);
    });

    testWidgets('missing target still shows fallback snackbar', (tester) async {
      final mockVideoService = _MockVideoEventService();
      final mockNostrClient = _MockNostrClient();

      when(() => mockVideoService.getVideoById(any())).thenReturn(null);
      when(() => mockNostrClient.fetchEventById('missing_event'))
          .thenAnswer((_) async => null);

      final notifier = _MockRelayNotifications([
        NotificationModel(
          id: 'notif-missing',
          type: NotificationType.comment,
          actorPubkey: 'b' * 64,
          actorName: 'Commenter',
          message: 'commented',
          timestamp: DateTime.now(),
          targetEventId: 'missing_event',
        ),
      ]);

      await tester.pumpWidget(
        screen(
          () => notifier,
          videoService: mockVideoService,
          nostrClient: mockNostrClient,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(NotificationListItem).first);
      await tester.pumpAndSettle();

      expect(find.text('Video not found'), findsOneWidget);
    });
  });
}
