// ABOUTME: Tests for VideoReplyContext model.
// ABOUTME: Verifies equality, props, and optional fields.

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/video_reply_context.dart';

// Full 64-character test IDs
const _rootEventId =
    'a1b2c3d4e5f6789012345678901234567890abcdef123456789012345678901234';
const _rootAuthorPubkey =
    'b2c3d4e5f6789012345678901234567890abcdef123456789012345678901234a';
const _parentCommentId =
    'c3d4e5f6789012345678901234567890abcdef123456789012345678901234ab';
const _parentAuthorPubkey =
    'd4e5f6789012345678901234567890abcdef123456789012345678901234abc';

void main() {
  group(VideoReplyContext, () {
    test('creates with required fields only', () {
      const context = VideoReplyContext(
        rootEventId: _rootEventId,
        rootEventKind: 34236,
        rootAuthorPubkey: _rootAuthorPubkey,
      );

      expect(context.rootEventId, equals(_rootEventId));
      expect(context.rootEventKind, equals(34236));
      expect(context.rootAuthorPubkey, equals(_rootAuthorPubkey));
      expect(context.rootAddressableId, isNull);
      expect(context.parentCommentId, isNull);
      expect(context.parentAuthorPubkey, isNull);
    });

    test('creates with all fields', () {
      const context = VideoReplyContext(
        rootEventId: _rootEventId,
        rootEventKind: 34236,
        rootAuthorPubkey: _rootAuthorPubkey,
        rootAddressableId: 'test-d-tag',
        parentCommentId: _parentCommentId,
        parentAuthorPubkey: _parentAuthorPubkey,
      );

      expect(context.rootEventId, equals(_rootEventId));
      expect(context.rootEventKind, equals(34236));
      expect(context.rootAuthorPubkey, equals(_rootAuthorPubkey));
      expect(context.rootAddressableId, equals('test-d-tag'));
      expect(context.parentCommentId, equals(_parentCommentId));
      expect(context.parentAuthorPubkey, equals(_parentAuthorPubkey));
    });

    test('equality with same values', () {
      const context1 = VideoReplyContext(
        rootEventId: _rootEventId,
        rootEventKind: 34236,
        rootAuthorPubkey: _rootAuthorPubkey,
      );
      const context2 = VideoReplyContext(
        rootEventId: _rootEventId,
        rootEventKind: 34236,
        rootAuthorPubkey: _rootAuthorPubkey,
      );

      expect(context1, equals(context2));
    });

    test('inequality with different rootEventId', () {
      const context1 = VideoReplyContext(
        rootEventId: _rootEventId,
        rootEventKind: 34236,
        rootAuthorPubkey: _rootAuthorPubkey,
      );
      const context2 = VideoReplyContext(
        rootEventId: _parentCommentId,
        rootEventKind: 34236,
        rootAuthorPubkey: _rootAuthorPubkey,
      );

      expect(context1, isNot(equals(context2)));
    });

    test('inequality with different rootEventKind', () {
      const context1 = VideoReplyContext(
        rootEventId: _rootEventId,
        rootEventKind: 34236,
        rootAuthorPubkey: _rootAuthorPubkey,
      );
      const context2 = VideoReplyContext(
        rootEventId: _rootEventId,
        rootEventKind: 1111,
        rootAuthorPubkey: _rootAuthorPubkey,
      );

      expect(context1, isNot(equals(context2)));
    });

    test('inequality with different optional fields', () {
      const context1 = VideoReplyContext(
        rootEventId: _rootEventId,
        rootEventKind: 34236,
        rootAuthorPubkey: _rootAuthorPubkey,
        parentCommentId: _parentCommentId,
      );
      const context2 = VideoReplyContext(
        rootEventId: _rootEventId,
        rootEventKind: 34236,
        rootAuthorPubkey: _rootAuthorPubkey,
      );

      expect(context1, isNot(equals(context2)));
    });

    test('props includes all fields', () {
      const context = VideoReplyContext(
        rootEventId: _rootEventId,
        rootEventKind: 34236,
        rootAuthorPubkey: _rootAuthorPubkey,
        rootAddressableId: 'test-d-tag',
        parentCommentId: _parentCommentId,
        parentAuthorPubkey: _parentAuthorPubkey,
      );

      expect(
        context.props,
        equals([
          _rootEventId,
          34236,
          _rootAuthorPubkey,
          'test-d-tag',
          _parentCommentId,
          _parentAuthorPubkey,
        ]),
      );
    });
  });
}
