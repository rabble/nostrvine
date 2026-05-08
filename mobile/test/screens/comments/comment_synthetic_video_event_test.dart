import 'package:comments_repository/comments_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/screens/comments/comment_synthetic_video_event.dart';

void main() {
  group('CommentSyntheticVideoEventX', () {
    test('preserves addressable root tags for video reply navigation', () {
      const rootEventId =
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
      const rootAuthorPubkey =
          'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
      const rootAddressableId = '34236:$rootAuthorPubkey:parent-video';

      final comment = Comment(
        id: 'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc',
        content: 'video reply',
        authorPubkey:
            'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd',
        createdAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
        rootEventId: rootEventId,
        rootAuthorPubkey: rootAuthorPubkey,
        rootAddressableId: rootAddressableId,
        videoUrl: 'https://media.divine.video/reply-video',
      );

      final video = comment.toSyntheticVideoEvent();

      expect(video.rawTags['A'], rootAddressableId);
      expect(video.rawTags['a'], rootAddressableId);
      expect(video.replyRootAddressableId, rootAddressableId);
      expect(video.replyRootRouteId, rootAddressableId);
    });
  });
}
