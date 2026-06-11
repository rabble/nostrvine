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
  const videoCoordinate = '34236:owner_hex:my-vine-id';

  group('pushNotificationTapTarget', () {
    test('follow opens the actor profile (carries no referencedEventId)', () {
      final result = app.pushNotificationTapTarget(
        referencedAddress: null,
        referencedEventId: null,
        eventId: 'contact_list_event',
        notificationType: 'follow',
        senderPubkey: actor,
      );

      expect(result.target, const OpenProfileTarget(actor));
    });

    test('like opens the referenced video without comments', () {
      final result = app.pushNotificationTapTarget(
        referencedAddress: null,
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
        referencedAddress: null,
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
        referencedAddress: null,
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
        referencedAddress: null,
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
        referencedAddress: null,
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
        referencedAddress: null,
        referencedEventId: videoEvent,
        eventId: sourceEvent,
        notificationType: 'like',
        senderPubkey: actor,
      );

      expect(result.targetEventId, equals(videoEvent));
    });

    test('nothing routable and no pubkey opens the inbox', () {
      final result = app.pushNotificationTapTarget(
        referencedAddress: null,
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
        referencedAddress: null,
        referencedEventId: videoEvent,
        eventId: null,
        // Capitalized — not the lowercase wire value the service sends.
        notificationType: 'Like',
        senderPubkey: actor,
      );

      expect(result.target, const OpenVideoTarget(autoOpenComments: false));
    });

    test('prefers the authoritative addressable coordinate as the video '
        'target', () {
      final result = app.pushNotificationTapTarget(
        referencedAddress: videoCoordinate,
        referencedEventId: videoEvent,
        eventId: sourceEvent,
        notificationType: 'like',
        senderPubkey: actor,
      );

      expect(result.target, const OpenVideoTarget(autoOpenComments: false));
      expect(result.videoCoordinate, equals(videoCoordinate));
    });

    test('a video coordinate alone is a video target (no event id)', () {
      final result = app.pushNotificationTapTarget(
        referencedAddress: videoCoordinate,
        referencedEventId: null,
        eventId: null,
        notificationType: 'like',
        senderPubkey: actor,
      );

      expect(result.target, const OpenVideoTarget(autoOpenComments: false));
      expect(result.videoCoordinate, equals(videoCoordinate));
    });

    test('ignores a non-video addressable coordinate and falls back', () {
      // A coordinate whose kind is not a NIP-71 video kind cannot be resolved
      // as a raw video route, so it must not be treated as a video target.
      final result = app.pushNotificationTapTarget(
        referencedAddress: '30023:owner_hex:blog-slug',
        referencedEventId: null,
        eventId: null,
        notificationType: 'comment',
        senderPubkey: actor,
      );

      expect(result.target, const OpenProfileTarget(actor));
      expect(result.videoCoordinate, isNull);
    });

    test('falls back to referencedEventId when no coordinate is present', () {
      final result = app.pushNotificationTapTarget(
        referencedAddress: null,
        referencedEventId: videoEvent,
        eventId: sourceEvent,
        notificationType: 'like',
        senderPubkey: actor,
      );

      expect(result.target, const OpenVideoTarget(autoOpenComments: false));
      expect(result.videoCoordinate, isNull);
      expect(result.targetEventId, equals(videoEvent));
    });

    test('ignores a malformed referencedAddress', () {
      final result = app.pushNotificationTapTarget(
        referencedAddress: 'not-a-coordinate',
        referencedEventId: null,
        eventId: null,
        notificationType: 'like',
        senderPubkey: actor,
      );

      expect(result.target, const OpenProfileTarget(actor));
      expect(result.videoCoordinate, isNull);
    });
  });

  group('videoAddressableTarget', () {
    test('returns the coordinate for a NIP-71 video kind', () {
      expect(
        videoAddressableTarget('34236:owner_hex:my-vine-id'),
        equals('34236:owner_hex:my-vine-id'),
      );
    });

    test('preserves a colon-containing d-tag', () {
      expect(
        videoAddressableTarget('34236:owner_hex:weird:d:tag'),
        equals('34236:owner_hex:weird:d:tag'),
      );
    });

    test('returns null for a non-video kind', () {
      expect(videoAddressableTarget('30023:owner_hex:blog-slug'), isNull);
    });

    test('returns null for a malformed coordinate', () {
      expect(videoAddressableTarget('34236:only-two-parts'), isNull);
      expect(videoAddressableTarget('not-a-coordinate'), isNull);
    });

    test('returns null for empty or null input', () {
      expect(videoAddressableTarget(''), isNull);
      expect(videoAddressableTarget(null), isNull);
    });
  });
}
