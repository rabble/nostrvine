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
    ]) {
      test('is true for $kind', () {
        expect(notificationKindOpensComments(kind), isTrue);
      });
    }

    test('is true for mention only with a comment target', () {
      expect(notificationKindOpensComments(NotificationKind.mention), isFalse);
      expect(
        notificationKindOpensComments(
          NotificationKind.mention,
          hasCommentTarget: true,
        ),
        isTrue,
      );
    });

    for (final kind in const [
      NotificationKind.like,
      NotificationKind.repost,
      NotificationKind.follow,
      NotificationKind.system,
      NotificationKind.listAdd,
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

    test('maps the camelCase newPost type', () {
      // Matches divine-push-service's NotificationType::display_name()
      // exactly — the string is a wire contract, so a casing drift here
      // silently degrades the tap target.
      expect(notificationKindFromPushType('newPost'), NotificationKind.newPost);
    });

    test('maps the inbox list_add type', () {
      expect(
        notificationKindFromPushType('list_add'),
        NotificationKind.listAdd,
      );
    });

    test('routes a newPost tap to the video, not the profile', () {
      expect(
        resolveNotificationTapTarget(
          kind: NotificationKind.newPost,
          hasVideoTarget: true,
          actorPubkey: 'creator_pubkey_hex',
        ),
        const OpenVideoTarget(autoOpenComments: false),
      );
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

  group('listTargetFromCoordinate', () {
    test('parses kind 30005 list coordinates', () {
      expect(
        listTargetFromCoordinate('30005:pubkey_alice:literature'),
        const OpenListTarget(pubkey: 'pubkey_alice', listId: 'literature'),
      );
    });

    test('keeps colons in the list d-tag', () {
      expect(
        listTargetFromCoordinate('30005:pubkey_alice:lit:erature'),
        const OpenListTarget(pubkey: 'pubkey_alice', listId: 'lit:erature'),
      );
    });

    test('rejects malformed and non-list coordinates', () {
      expect(listTargetFromCoordinate(null), isNull);
      expect(listTargetFromCoordinate(''), isNull);
      expect(listTargetFromCoordinate('34236:pubkey:dtag'), isNull);
      expect(listTargetFromCoordinate('30005::dtag'), isNull);
      expect(listTargetFromCoordinate('30005:pubkey:'), isNull);
      expect(listTargetFromCoordinate('not-a-coordinate'), isNull);
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

    test('listAdd with a valid list coordinate opens the list', () {
      expect(
        resolveNotificationTapTarget(
          kind: NotificationKind.listAdd,
          hasVideoTarget: true,
          listCoordinate: '30005:pubkey_alice:literature',
        ),
        const OpenListTarget(pubkey: 'pubkey_alice', listId: 'literature'),
      );
    });

    test(
      'listAdd without a valid list coordinate falls back to video target',
      () {
        expect(
          resolveNotificationTapTarget(
            kind: NotificationKind.listAdd,
            hasVideoTarget: true,
            listCoordinate: '34236:pubkey_alice:video',
          ),
          const OpenVideoTarget(autoOpenComments: false),
        );
      },
    );

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

    test('comment / likeComment / reply with a video target auto-open '
        'comments', () {
      for (final kind in const [
        NotificationKind.comment,
        NotificationKind.likeComment,
        NotificationKind.reply,
      ]) {
        expect(
          resolveNotificationTapTarget(kind: kind, hasVideoTarget: true),
          const OpenVideoTarget(autoOpenComments: true),
          reason: '$kind should auto-open comments',
        );
      }
    });

    test('video mention opens video without auto-opening comments', () {
      expect(
        resolveNotificationTapTarget(
          kind: NotificationKind.mention,
          hasVideoTarget: true,
        ),
        const OpenVideoTarget(autoOpenComments: false),
      );
    });

    test('comment mention opens video with comments', () {
      expect(
        resolveNotificationTapTarget(
          kind: NotificationKind.mention,
          hasVideoTarget: true,
          hasCommentTarget: true,
        ),
        const OpenVideoTarget(autoOpenComments: true),
      );
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
