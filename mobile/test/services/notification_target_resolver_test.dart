import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:openvine/services/notification_target_resolver.dart';
import 'package:openvine/services/video_event_service.dart';

class _MockVideoEventService extends Mock implements VideoEventService {}

class _MockNostrClient extends Mock implements NostrClient {}

void main() {
  group('NotificationTargetResolver', () {
    late _MockVideoEventService videoEventService;
    late _MockNostrClient nostrClient;
    late NotificationTargetResolver resolver;

    setUp(() {
      videoEventService = _MockVideoEventService();
      nostrClient = _MockNostrClient();
      resolver = NotificationTargetResolver(
        videoEventService: videoEventService,
        nostrService: nostrClient,
      );
    });

    test('returns same id when target is already a video id', () async {
      when(() => videoEventService.getVideoById('video_1')).thenReturn(null);
      when(
        () => nostrClient.fetchEventById('video_1'),
      ).thenAnswer((_) async => Event('a' * 64, 22, const [], 'video'));

      final resolved = await resolver.resolveVideoEventIdFromNotificationTarget(
        'video_1',
      );

      expect(resolved, equals('video_1'));
    });

    test('recognizes kind 21 (normalVideo) as a direct video', () async {
      when(() => videoEventService.getVideoById('video_21')).thenReturn(null);
      when(
        () => nostrClient.fetchEventById('video_21'),
      ).thenAnswer((_) async => Event('a' * 64, 21, const [], 'video'));

      final resolved = await resolver.resolveVideoEventIdFromNotificationTarget(
        'video_21',
      );

      expect(resolved, equals('video_21'));
    });

    test(
      'resolves root video from NIP-22 uppercase E tag on nested reply',
      () async {
        const rootVideoId = 'root_video_nip22';
        const parentCommentId = 'parent_comment_nip22';
        const parentAuthorPubkey = 'parent_author_pubkey_hex';
        const videoAuthorPubkey = 'video_author_pubkey_hex';

        when(
          () => videoEventService.getVideoById('comment_nested'),
        ).thenReturn(null);
        when(() => nostrClient.fetchEventById('comment_nested')).thenAnswer(
          (_) async => Event(
            'b' * 64,
            1111,
            const [
              // NIP-22: uppercase = root scope (video)
              ['E', rootVideoId, '', videoAuthorPubkey],
              ['K', '34236'],
              ['P', videoAuthorPubkey],
              // NIP-22: lowercase = parent item (comment being replied to)
              ['e', parentCommentId, '', parentAuthorPubkey],
              ['k', '1111'],
              ['p', parentAuthorPubkey],
            ],
            'reply to comment',
          ),
        );

        final resolved = await resolver
            .resolveVideoEventIdFromNotificationTarget(
              'comment_nested',
            );

        expect(resolved, equals(rootVideoId));
      },
    );

    test(
      'resolves root video from NIP-22 uppercase E tag on top-level comment',
      () async {
        const rootVideoId = 'root_video_toplevel';
        const videoAuthorPubkey = 'video_author_pubkey_hex';

        when(
          () => videoEventService.getVideoById('comment_top'),
        ).thenReturn(null);
        when(() => nostrClient.fetchEventById('comment_top')).thenAnswer(
          (_) async => Event(
            'c' * 64,
            1111,
            const [
              // NIP-22: uppercase = root scope (video)
              ['E', rootVideoId, '', videoAuthorPubkey],
              ['K', '34236'],
              ['P', videoAuthorPubkey],
              // NIP-22: lowercase = parent (same as root for top-level)
              ['e', rootVideoId, '', videoAuthorPubkey],
              ['k', '34236'],
              ['p', videoAuthorPubkey],
            ],
            'top-level comment',
          ),
        );

        final resolved = await resolver
            .resolveVideoEventIdFromNotificationTarget(
              'comment_top',
            );

        expect(resolved, equals(rootVideoId));
      },
    );

    test(
      'resolves from only uppercase E tag when no lowercase e tags exist',
      () async {
        const rootVideoId = 'root_video_only_E';

        when(
          () => videoEventService.getVideoById('comment_minimal'),
        ).thenReturn(null);
        when(() => nostrClient.fetchEventById('comment_minimal')).thenAnswer(
          (_) async => Event(
            'd' * 64,
            1111,
            const [
              ['E', rootVideoId, '', 'author_pub'],
              ['K', '34236'],
              ['P', 'author_pub'],
            ],
            'minimal comment',
          ),
        );

        final resolved = await resolver
            .resolveVideoEventIdFromNotificationTarget(
              'comment_minimal',
            );

        expect(resolved, equals(rootVideoId));
      },
    );

    test(
      'falls back to NIP-10 e-tag root marker when no uppercase E tag exists',
      () async {
        when(
          () => videoEventService.getVideoById('comment_1'),
        ).thenReturn(null);
        when(() => nostrClient.fetchEventById('comment_1')).thenAnswer(
          (_) async => Event(
            'e' * 64,
            1111,
            const [
              ['e', 'root_video_1', '', 'root'],
              ['e', 'parent_comment_1', '', 'reply'],
            ],
            'comment',
          ),
        );

        final resolved = await resolver
            .resolveVideoEventIdFromNotificationTarget(
              'comment_1',
            );

        expect(resolved, equals('root_video_1'));
      },
    );

    test('returns null when no resolvable video tags exist', () async {
      when(
        () => videoEventService.getVideoById('comment_2'),
      ).thenReturn(null);
      when(() => nostrClient.fetchEventById('comment_2')).thenAnswer(
        (_) async => Event(
          'f' * 64,
          1111,
          const [
            ['p', 'author_pubkey'],
            ['t', 'comment'],
          ],
          'comment',
        ),
      );

      final resolved = await resolver.resolveVideoEventIdFromNotificationTarget(
        'comment_2',
      );

      expect(resolved, isNull);
    });
  });
}
