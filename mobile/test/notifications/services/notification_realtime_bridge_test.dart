// ABOUTME: Unit tests for NotificationRealtimeBridge — forwarding,
// ABOUTME: dispose cancellation, error tolerance, and modelToRelay mapping
// ABOUTME: invariants that preserve cross-path dedupe and raw body text.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:notification_repository/notification_repository.dart';
import 'package:openvine/notifications/services/notification_realtime_bridge.dart';

class _MockNotificationRepository extends Mock
    implements NotificationRepository {}

void main() {
  setUpAll(() {
    registerFallbackValue(
      RelayNotification(
        id: 'fallback_id',
        sourcePubkey: 'fallback_pub',
        sourceEventId: 'fallback_evt',
        sourceKind: 0,
        notificationType: 'system',
        createdAt: DateTime(2024),
        read: false,
      ),
    );
  });

  group(NotificationRealtimeBridge, () {
    late _MockNotificationRepository repository;
    late StreamController<NotificationModel> controller;

    setUp(() {
      repository = _MockNotificationRepository();
      controller = StreamController<NotificationModel>.broadcast();
      when(
        () => repository.acceptRealtime(any()),
      ).thenAnswer((_) async {});
    });

    tearDown(() async {
      if (!controller.isClosed) await controller.close();
    });

    NotificationRealtimeBridge buildBridge() => NotificationRealtimeBridge(
      repository: repository,
      stream: controller.stream,
    );

    NotificationModel makeModel({
      String id = 'evt_1',
      String actorPubkey = 'pubkey_alice',
      NotificationType type = NotificationType.like,
      String message = 'Alice liked your video',
      Map<String, dynamic>? metadata,
      String? targetEventId,
      String? targetVideoThumbnail,
    }) {
      return NotificationModel(
        id: id,
        type: type,
        actorPubkey: actorPubkey,
        message: message,
        timestamp: DateTime(2025),
        targetEventId: targetEventId,
        targetVideoThumbnail: targetVideoThumbnail,
        metadata: metadata,
      );
    }

    test('forwards a NotificationModel to acceptRealtime', () async {
      final bridge = buildBridge();
      addTearDown(bridge.dispose);

      controller.add(
        makeModel(
          targetEventId: 'video_evt_1',
          targetVideoThumbnail: 'https://example.com/thumb.jpg',
        ),
      );
      await Future<void>.delayed(Duration.zero);

      final captured =
          verify(
                () => repository.acceptRealtime(captureAny()),
              ).captured.single
              as RelayNotification;
      expect(captured.id, equals('evt_1'));
      expect(captured.sourcePubkey, equals('pubkey_alice'));
      expect(captured.notificationType, equals('reaction'));
      expect(captured.sourceKind, equals(7));
      expect(captured.referencedEventId, equals('video_evt_1'));
      expect(captured.isReferencedVideo, isTrue);
    });

    test('cancels the subscription on dispose', () async {
      final bridge = buildBridge();

      controller.add(makeModel(id: 'before_dispose'));
      await Future<void>.delayed(Duration.zero);

      await bridge.dispose();

      controller.add(makeModel(id: 'after_dispose'));
      await Future<void>.delayed(Duration.zero);

      verify(() => repository.acceptRealtime(any())).called(1);
    });

    test('swallows repository errors so the stream stays alive', () async {
      when(() => repository.acceptRealtime(any())).thenThrow(
        StateError('repo blew up'),
      );

      final bridge = buildBridge();
      addTearDown(bridge.dispose);

      controller.add(makeModel(id: 'first'));
      await Future<void>.delayed(Duration.zero);

      // Subsequent emissions still flow through — the listener wasn't
      // dropped by the prior throw.
      when(() => repository.acceptRealtime(any())).thenAnswer((_) async {});
      controller.add(makeModel(id: 'second'));
      await Future<void>.delayed(Duration.zero);

      verify(() => repository.acceptRealtime(any())).called(2);
    });

    test('swallows stream onError without crashing', () async {
      final bridge = buildBridge();
      addTearDown(bridge.dispose);

      controller.addError(StateError('stream blew up'));
      await Future<void>.delayed(Duration.zero);

      controller.add(makeModel(id: 'after_error'));
      await Future<void>.delayed(Duration.zero);

      verify(() => repository.acceptRealtime(any())).called(1);
    });

    group('modelToRelay', () {
      test(
        'preserves the raw comment body from metadata, not the synthesized '
        'message',
        () {
          final relay = NotificationRealtimeBridge.modelToRelay(
            NotificationModel(
              id: 'evt_comment',
              type: NotificationType.comment,
              actorPubkey: 'pubkey_alice',
              message: 'Alice commented on your video',
              timestamp: DateTime(2025),
              targetEventId: 'video_evt_1',
              metadata: const {'comment': 'nice clip!'},
            ),
          );

          expect(relay.content, equals('nice clip!'));
          expect(relay.notificationType, equals('comment'));
          expect(relay.sourceKind, equals(1111));
        },
      );

      test(
        'preserves the raw mention text from metadata, not the synthesized '
        'message',
        () {
          final relay = NotificationRealtimeBridge.modelToRelay(
            NotificationModel(
              id: 'evt_mention',
              type: NotificationType.mention,
              actorPubkey: 'pubkey_alice',
              message: 'Alice mentioned you',
              timestamp: DateTime(2025),
              metadata: const {'text': 'hey @you check this out'},
            ),
          );

          expect(relay.content, equals('hey @you check this out'));
          expect(relay.notificationType, equals('mention'));
          expect(relay.sourceKind, equals(1));
        },
      );

      test(
        'falls back to metadata[content] when type-specific key is absent',
        () {
          final relay = NotificationRealtimeBridge.modelToRelay(
            NotificationModel(
              id: 'evt_comment_fallback',
              type: NotificationType.comment,
              actorPubkey: 'pubkey_alice',
              message: 'Alice commented on your video',
              timestamp: DateTime(2025),
              metadata: const {'content': 'fallback body'},
            ),
          );

          expect(relay.content, equals('fallback body'));
        },
      );

      test('leaves content null for like / repost / follow / system', () {
        for (final type in const [
          NotificationType.like,
          NotificationType.repost,
          NotificationType.follow,
          NotificationType.system,
        ]) {
          final relay = NotificationRealtimeBridge.modelToRelay(
            NotificationModel(
              id: 'evt_$type',
              type: type,
              actorPubkey: 'pubkey_alice',
              message: 'presentation copy',
              timestamp: DateTime(2025),
              metadata: const {
                'comment': 'should be ignored for non-comment',
                'text': 'should be ignored for non-mention',
                'content': 'should be ignored for non-text types',
              },
            ),
          );

          expect(
            relay.content,
            isNull,
            reason:
                '$type has no raw body — content must stay null so the '
                'repository falls back to the presentation message.',
          );
        }
      });

      test('preserves sourceEventId for cross-path dedupe', () {
        final relay = NotificationRealtimeBridge.modelToRelay(
          NotificationModel(
            id: 'nostr-evt-xyz',
            type: NotificationType.like,
            actorPubkey: 'pubkey_alice',
            message: 'Alice liked your video',
            timestamp: DateTime(2025),
            metadata: const {'sourceEventId': 'nostr-evt-xyz'},
          ),
        );

        expect(relay.id, equals('nostr-evt-xyz'));
        expect(relay.sourceEventId, equals('nostr-evt-xyz'));
      });
    });
  });
}
