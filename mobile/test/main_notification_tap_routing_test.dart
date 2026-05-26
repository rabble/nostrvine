// ABOUTME: Regression tests for push/local notification tap routing.
// ABOUTME: Proves follow/mention are no longer dropped and that the push path
// ABOUTME: shares the same routing contract as in-app notification rows.

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/main.dart' as app;
import 'package:openvine/notifications/routing/notification_tap_target.dart';

void main() {
  const actor = 'follower_pubkey_hex';
  const videoEvent = 'video_event_id';
  const commentEvent = 'comment_event_id';
  const sourceEvent = 'source_event_id';

  group('pushNotificationTapTarget', () {
    test('follow opens the actor profile (carries no referencedEventId)', () {
      final result = app.pushNotificationTapTarget(
        referencedEventId: null,
        eventId: 'contact_list_event',
        notificationType: 'follow',
        senderPubkey: actor,
      );

      expect(result.target, const OpenProfileTarget(actor));
    });

    test('like opens the referenced video without comments', () {
      final result = app.pushNotificationTapTarget(
        referencedEventId: videoEvent,
        eventId: sourceEvent,
        notificationType: 'like',
        senderPubkey: actor,
      );

      expect(result.target, const OpenVideoTarget(autoOpenComments: false));
      expect(result.targetEventId, equals(videoEvent));
    });

    test('comment opens the referenced video with comments', () {
      final result = app.pushNotificationTapTarget(
        referencedEventId: commentEvent,
        eventId: sourceEvent,
        notificationType: 'comment',
        senderPubkey: actor,
      );

      expect(result.target, const OpenVideoTarget(autoOpenComments: true));
      expect(result.targetEventId, equals(commentEvent));
    });

    test('repost opens the referenced video without comments', () {
      final result = app.pushNotificationTapTarget(
        referencedEventId: videoEvent,
        eventId: sourceEvent,
        notificationType: 'repost',
        senderPubkey: actor,
      );

      expect(result.target, const OpenVideoTarget(autoOpenComments: false));
    });

    test('mention uses eventId as the video target (no referencedEventId) '
        'and opens comments', () {
      final result = app.pushNotificationTapTarget(
        referencedEventId: null,
        eventId: sourceEvent,
        notificationType: 'mention',
        senderPubkey: actor,
      );

      expect(result.target, const OpenVideoTarget(autoOpenComments: true));
      expect(result.targetEventId, equals(sourceEvent));
    });

    test('mention without a video target falls back to the actor profile', () {
      final result = app.pushNotificationTapTarget(
        referencedEventId: null,
        eventId: null,
        notificationType: 'mention',
        senderPubkey: actor,
      );

      expect(result.target, const OpenProfileTarget(actor));
      expect(result.targetEventId, isNull);
    });

    test('prefers referencedEventId over eventId as the video target', () {
      final result = app.pushNotificationTapTarget(
        referencedEventId: videoEvent,
        eventId: sourceEvent,
        notificationType: 'like',
        senderPubkey: actor,
      );

      expect(result.targetEventId, equals(videoEvent));
    });

    test('nothing routable and no pubkey opens the inbox', () {
      final result = app.pushNotificationTapTarget(
        referencedEventId: null,
        eventId: null,
        notificationType: 'follow',
        senderPubkey: null,
      );

      expect(result.target, const OpenInboxTarget());
    });

    test('unknown type with a video target opens the video without '
        'comments', () {
      final result = app.pushNotificationTapTarget(
        referencedEventId: videoEvent,
        eventId: null,
        // Capitalized — not the lowercase wire value the service sends.
        notificationType: 'Like',
        senderPubkey: actor,
      );

      expect(result.target, const OpenVideoTarget(autoOpenComments: false));
    });
  });
}
