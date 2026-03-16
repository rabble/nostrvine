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

    test('resolves root video id from comment event e-tags', () async {
      when(() => videoEventService.getVideoById('comment_1')).thenReturn(null);
      when(() => nostrClient.fetchEventById('comment_1')).thenAnswer(
        (_) async => Event(
          'b' * 64,
          1111,
          const [
            ['e', 'root_video_1', '', 'root'],
            ['e', 'parent_comment_1', '', 'reply'],
          ],
          'comment',
        ),
      );

      final resolved = await resolver.resolveVideoEventIdFromNotificationTarget(
        'comment_1',
      );

      expect(resolved, equals('root_video_1'));
    });

    test('returns null when no resolvable video tags exist', () async {
      when(() => videoEventService.getVideoById('comment_2')).thenReturn(null);
      when(() => nostrClient.fetchEventById('comment_2')).thenAnswer(
        (_) async => Event(
          'c' * 64,
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
