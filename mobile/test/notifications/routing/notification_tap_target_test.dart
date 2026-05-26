// ABOUTME: Tests for the shared notification tap routing decision.
// ABOUTME: Pins the one contract used by in-app, push, and local tap paths.

import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart' show NotificationKind;
import 'package:openvine/notifications/routing/notification_tap_target.dart';

void main() {
  group('notificationKindOpensComments', () {
    for (final kind in const [
      NotificationKind.comment,
      NotificationKind.reply,
      NotificationKind.likeComment,
      NotificationKind.mention,
    ]) {
      test('is true for $kind', () {
        expect(notificationKindOpensComments(kind), isTrue);
      });
    }

    for (final kind in const [
      NotificationKind.like,
      NotificationKind.repost,
      NotificationKind.follow,
      NotificationKind.system,
    ]) {
      test('is false for $kind', () {
        expect(notificationKindOpensComments(kind), isFalse);
      });
    }

    test('is false for null kind', () {
      expect(notificationKindOpensComments(null), isFalse);
    });
  });

  group('notificationKindFromPushType', () {
    test('maps the lowercase 5-value push vocabulary', () {
      expect(notificationKindFromPushType('like'), NotificationKind.like);
      expect(notificationKindFromPushType('comment'), NotificationKind.comment);
      expect(notificationKindFromPushType('follow'), NotificationKind.follow);
      expect(notificationKindFromPushType('mention'), NotificationKind.mention);
      expect(notificationKindFromPushType('repost'), NotificationKind.repost);
    });

    test('returns null for values the push service never sends', () {
      // The backend emits lowercase only and has no reply/likeComment/system.
      expect(notificationKindFromPushType('Like'), isNull);
      expect(notificationKindFromPushType('reply'), isNull);
      expect(notificationKindFromPushType('likeComment'), isNull);
      expect(notificationKindFromPushType('system'), isNull);
      expect(notificationKindFromPushType('zap'), isNull);
      expect(notificationKindFromPushType(null), isNull);
      expect(notificationKindFromPushType(''), isNull);
    });
  });

  group('resolveNotificationTapTarget', () {
    const pubkey = 'actor_pubkey_hex';

    test('follow with actor pubkey opens the profile', () {
      expect(
        resolveNotificationTapTarget(
          kind: NotificationKind.follow,
          hasVideoTarget: false,
          actorPubkey: pubkey,
        ),
        const OpenProfileTarget(pubkey),
      );
    });

    test('follow without actor pubkey falls back to the inbox', () {
      expect(
        resolveNotificationTapTarget(
          kind: NotificationKind.follow,
          hasVideoTarget: false,
        ),
        const OpenInboxTarget(),
      );
    });

    test('system always opens the inbox', () {
      expect(
        resolveNotificationTapTarget(
          kind: NotificationKind.system,
          hasVideoTarget: true,
          actorPubkey: pubkey,
        ),
        const OpenInboxTarget(),
      );
    });

    test(
      'like / repost with a video target open the video without comments',
      () {
        for (final kind in const [
          NotificationKind.like,
          NotificationKind.repost,
        ]) {
          expect(
            resolveNotificationTapTarget(kind: kind, hasVideoTarget: true),
            const OpenVideoTarget(autoOpenComments: false),
            reason: '$kind should not auto-open comments',
          );
        }
      },
    );

    test('comment / likeComment / mention with a video target auto-open '
        'comments', () {
      for (final kind in const [
        NotificationKind.comment,
        NotificationKind.likeComment,
        NotificationKind.reply,
        NotificationKind.mention,
      ]) {
        expect(
          resolveNotificationTapTarget(kind: kind, hasVideoTarget: true),
          const OpenVideoTarget(autoOpenComments: true),
          reason: '$kind should auto-open comments',
        );
      }
    });

    test(
      'comment-type kind without a video target falls back to the profile',
      () {
        expect(
          resolveNotificationTapTarget(
            kind: NotificationKind.mention,
            hasVideoTarget: false,
            actorPubkey: pubkey,
          ),
          const OpenProfileTarget(pubkey),
        );
      },
    );

    test('no video target and no actor pubkey opens the inbox', () {
      expect(
        resolveNotificationTapTarget(
          kind: NotificationKind.mention,
          hasVideoTarget: false,
        ),
        const OpenInboxTarget(),
      );
    });

    test(
      'unknown kind with a video target opens the video without comments',
      () {
        expect(
          resolveNotificationTapTarget(kind: null, hasVideoTarget: true),
          const OpenVideoTarget(autoOpenComments: false),
        );
      },
    );

    test('identical inputs produce equal targets regardless of source '
        '(anti-drift)', () {
      // In-app and push both feed the same (kind, hasVideoTarget, pubkey)
      // into this function; value-equality proves they cannot diverge.
      final fromInApp = resolveNotificationTapTarget(
        kind: NotificationKind.comment,
        hasVideoTarget: true,
        actorPubkey: pubkey,
      );
      final fromPush = resolveNotificationTapTarget(
        kind: NotificationKind.comment,
        hasVideoTarget: true,
        actorPubkey: pubkey,
      );
      expect(fromInApp, fromPush);
      expect(fromInApp, const OpenVideoTarget(autoOpenComments: true));
    });
  });
}
