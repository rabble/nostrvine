// ABOUTME: Tests for in-app notification avatar-stack tap routing.
// ABOUTME: Pins grouped like/repost list routing and profile fallback behavior.

import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/video_engagement/video_engagement_bloc.dart'
    show VideoEngagementType;
import 'package:openvine/notifications/routing/avatar_stack_tap_target.dart';

void main() {
  group('resolveAvatarStackTapTarget', () {
    const firstActor = ActorInfo(pubkey: 'actor_1', displayName: 'Alice');
    const secondActor = ActorInfo(pubkey: 'actor_2', displayName: 'Bob');

    VideoNotification videoNotification(
      NotificationKind kind, {
      int totalCount = 3,
      List<ActorInfo> actors = const [firstActor, secondActor],
    }) {
      return VideoNotification(
        id: 'notification_${kind.name}',
        type: kind,
        videoEventId: 'video_event_${kind.name}',
        videoAddressableId: '34236:author:${kind.name}',
        actors: actors,
        totalCount: totalCount,
        timestamp: DateTime(2026),
      );
    }

    test('grouped like opens the likers list', () {
      expect(
        resolveAvatarStackTapTarget(videoNotification(NotificationKind.like)),
        const OpenEngagementListTarget(
          eventId: 'video_event_like',
          addressableId: '34236:author:like',
          type: VideoEngagementType.likers,
        ),
      );
    });

    test('grouped repost opens the reposters list', () {
      expect(
        resolveAvatarStackTapTarget(videoNotification(NotificationKind.repost)),
        const OpenEngagementListTarget(
          eventId: 'video_event_repost',
          addressableId: '34236:author:repost',
          type: VideoEngagementType.reposters,
        ),
      );
    });

    test('single like keeps opening the actor profile', () {
      expect(
        resolveAvatarStackTapTarget(
          videoNotification(
            NotificationKind.like,
            totalCount: 1,
            actors: const [firstActor],
          ),
        ),
        const OpenActorProfileTarget('actor_1'),
      );
    });

    test('single repost keeps opening the actor profile', () {
      expect(
        resolveAvatarStackTapTarget(
          videoNotification(
            NotificationKind.repost,
            totalCount: 1,
            actors: const [firstActor],
          ),
        ),
        const OpenActorProfileTarget('actor_1'),
      );
    });

    for (final kind in const [
      NotificationKind.likeComment,
      NotificationKind.comment,
      NotificationKind.mention,
      NotificationKind.newPost,
      NotificationKind.listAdd,
    ]) {
      test('$kind keeps opening the first visible actor profile', () {
        expect(
          resolveAvatarStackTapTarget(videoNotification(kind)),
          const OpenActorProfileTarget('actor_1'),
        );
      });
    }

    // Kind never participates in the ActorNotification branch — it always
    // resolves to the actor's profile — so one case pins the whole branch.
    test('actor notification opens the actor profile', () {
      expect(
        resolveAvatarStackTapTarget(
          ActorNotification(
            id: 'actor_follow',
            type: NotificationKind.follow,
            actor: firstActor,
            timestamp: DateTime(2026),
          ),
        ),
        const OpenActorProfileTarget('actor_1'),
      );
    });
  });
}
