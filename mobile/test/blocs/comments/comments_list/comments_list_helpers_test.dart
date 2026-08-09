// ABOUTME: Tests the comments-list helper predicates, including the pending
// ABOUTME: video-reply placeholder id convention (#5862).

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/blocs/comments/comments_list/comments_list_helpers.dart';

void main() {
  group('pending video-reply ids', () {
    test('round-trips the draft id', () {
      final id = pendingVideoReplyId('publish_1234');
      expect(draftIdFromPendingVideoReplyId(id), equals('publish_1234'));
    });

    test('keeps the shared placeholder prefix', () {
      // Load-more cursor selection and the relay-echo swap in CommentsListBloc
      // both key off this prefix; dropping it would silently break both.
      expect(
        pendingVideoReplyId('d1'),
        startsWith(commentPlaceholderIdPrefix),
      );
    });

    test('does not claim a text placeholder', () {
      const textPlaceholder = '${commentPlaceholderIdPrefix}1700000000000000';
      expect(isPendingVideoReplyId(textPlaceholder), isFalse);
      expect(draftIdFromPendingVideoReplyId(textPlaceholder), isNull);
    });

    test('does not claim a real event id', () {
      final eventId = 'a' * 64;
      expect(isPendingVideoReplyId(eventId), isFalse);
      expect(draftIdFromPendingVideoReplyId(eventId), isNull);
    });
  });
}
