import 'package:comments_repository/comments_repository.dart';
import 'package:test/test.dart';

void main() {
  group('Comment', () {
    group('relativeTime', () {
      test('returns "now" for less than 1 minute', () {
        final comment = Comment(
          id: 'id',
          content: 'content',
          authorPubkey: 'author',
          createdAt: DateTime.now(),
          rootEventId: 'root',
          rootAuthorPubkey: 'rootAuthor',
        );

        expect(comment.relativeTime, equals('now'));
      });

      test('returns minutes ago', () {
        final comment = Comment(
          id: 'id',
          content: 'content',
          authorPubkey: 'author',
          createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
          rootEventId: 'root',
          rootAuthorPubkey: 'rootAuthor',
        );

        expect(comment.relativeTime, equals('5m ago'));
      });

      test('returns hours ago', () {
        final comment = Comment(
          id: 'id',
          content: 'content',
          authorPubkey: 'author',
          createdAt: DateTime.now().subtract(const Duration(hours: 3)),
          rootEventId: 'root',
          rootAuthorPubkey: 'rootAuthor',
        );

        expect(comment.relativeTime, equals('3h ago'));
      });

      test('returns days ago', () {
        final comment = Comment(
          id: 'id',
          content: 'content',
          authorPubkey: 'author',
          createdAt: DateTime.now().subtract(const Duration(days: 2)),
          rootEventId: 'root',
          rootAuthorPubkey: 'rootAuthor',
        );

        expect(comment.relativeTime, equals('2d ago'));
      });

      test('returns weeks ago for 7-59 days', () {
        final comment = Comment(
          id: 'id',
          content: 'content',
          authorPubkey: 'author',
          createdAt: DateTime.now().subtract(const Duration(days: 14)),
          rootEventId: 'root',
          rootAuthorPubkey: 'rootAuthor',
        );

        expect(comment.relativeTime, equals('2w ago'));
      });

      test('returns months ago for 60-364 days', () {
        final comment = Comment(
          id: 'id',
          content: 'content',
          authorPubkey: 'author',
          createdAt: DateTime.now().subtract(const Duration(days: 90)),
          rootEventId: 'root',
          rootAuthorPubkey: 'rootAuthor',
        );

        expect(comment.relativeTime, equals('3mo ago'));
      });

      test('returns years ago for 365+ days', () {
        final comment = Comment(
          id: 'id',
          content: 'content',
          authorPubkey: 'author',
          createdAt: DateTime.now().subtract(const Duration(days: 730)),
          rootEventId: 'root',
          rootAuthorPubkey: 'rootAuthor',
        );

        expect(comment.relativeTime, equals('2y ago'));
      });
    });

    group('copyWith', () {
      late Comment original;

      setUp(() {
        original = Comment(
          id: 'id',
          content: 'content',
          authorPubkey: 'author',
          createdAt: DateTime(2024),
          rootEventId: 'root',
          rootAuthorPubkey: 'rootAuthor',
          replyToEventId: 'replyTo',
          replyToAuthorPubkey: 'replyAuthor',
        );
      });

      test('creates copy with updated id', () {
        final copy = original.copyWith(id: 'newId');

        expect(copy.id, equals('newId'));
        expect(copy.content, equals('content'));
      });

      test('creates copy with updated content', () {
        final copy = original.copyWith(content: 'new content');

        expect(copy.id, equals('id'));
        expect(copy.content, equals('new content'));
      });

      test('creates copy with updated authorPubkey', () {
        final copy = original.copyWith(authorPubkey: 'newAuthor');

        expect(copy.authorPubkey, equals('newAuthor'));
        expect(copy.content, equals('content'));
      });

      test('creates copy with updated createdAt', () {
        final newDate = DateTime(2025);
        final copy = original.copyWith(createdAt: newDate);

        expect(copy.createdAt, equals(newDate));
      });

      test('creates copy with updated rootEventId', () {
        final copy = original.copyWith(rootEventId: 'newRoot');

        expect(copy.rootEventId, equals('newRoot'));
      });

      test('creates copy with updated rootAuthorPubkey', () {
        final copy = original.copyWith(rootAuthorPubkey: 'newRootAuthor');

        expect(copy.rootAuthorPubkey, equals('newRootAuthor'));
      });

      test('creates copy with updated replyToEventId', () {
        final copy = original.copyWith(replyToEventId: 'newReplyTo');

        expect(copy.replyToEventId, equals('newReplyTo'));
      });

      test('creates copy with updated replyToAuthorPubkey', () {
        final copy = original.copyWith(replyToAuthorPubkey: 'newReplyAuthor');

        expect(copy.replyToAuthorPubkey, equals('newReplyAuthor'));
      });

      test('preserves all fields when no parameters provided', () {
        final copy = original.copyWith();

        expect(copy, equals(original));
      });
    });

    group('equality', () {
      test('two comments with same values are equal', () {
        final comment1 = Comment(
          id: 'id',
          content: 'content',
          authorPubkey: 'author',
          createdAt: DateTime(2024),
          rootEventId: 'root',
          rootAuthorPubkey: 'rootAuthor',
        );

        final comment2 = Comment(
          id: 'id',
          content: 'content',
          authorPubkey: 'author',
          createdAt: DateTime(2024),
          rootEventId: 'root',
          rootAuthorPubkey: 'rootAuthor',
        );

        expect(comment1, equals(comment2));
      });

      test('two comments with different values are not equal', () {
        final comment1 = Comment(
          id: 'id1',
          content: 'content',
          authorPubkey: 'author',
          createdAt: DateTime(2024),
          rootEventId: 'root',
          rootAuthorPubkey: 'rootAuthor',
        );

        final comment2 = Comment(
          id: 'id2',
          content: 'content',
          authorPubkey: 'author',
          createdAt: DateTime(2024),
          rootEventId: 'root',
          rootAuthorPubkey: 'rootAuthor',
        );

        expect(comment1, isNot(equals(comment2)));
      });

      test('props includes all fields', () {
        final comment = Comment(
          id: 'id',
          content: 'content',
          authorPubkey: 'author',
          createdAt: DateTime(2024),
          rootEventId: 'root',
          rootAuthorPubkey: 'rootAuthor',
          replyToEventId: 'replyTo',
          replyToAuthorPubkey: 'replyAuthor',
        );

        expect(
          comment.props,
          equals([
            'id',
            'content',
            'author',
            DateTime(2024),
            'root',
            'rootAuthor',
            'replyTo',
            'replyAuthor',
          ]),
        );
      });
    });
  });
}
