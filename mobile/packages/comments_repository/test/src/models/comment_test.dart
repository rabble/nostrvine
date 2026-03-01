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
          videoUrl: 'https://example.com/video.mp4',
          thumbnailUrl: 'https://example.com/thumb.jpg',
          videoDimensions: '720x1280',
          videoDuration: 15,
          videoBlurhash: 'LEHV6nWB2yk8',
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
            'https://example.com/video.mp4',
            'https://example.com/thumb.jpg',
            '720x1280',
            15,
            'LEHV6nWB2yk8',
          ]),
        );
      });

      test(
        'two comments with same video fields are equal',
        () {
          final comment1 = Comment(
            id: 'id',
            content: 'content',
            authorPubkey: 'author',
            createdAt: DateTime(2024),
            rootEventId: 'root',
            rootAuthorPubkey: 'rootAuthor',
            videoUrl: 'https://example.com/video.mp4',
          );

          final comment2 = Comment(
            id: 'id',
            content: 'content',
            authorPubkey: 'author',
            createdAt: DateTime(2024),
            rootEventId: 'root',
            rootAuthorPubkey: 'rootAuthor',
            videoUrl: 'https://example.com/video.mp4',
          );

          expect(comment1, equals(comment2));
        },
      );

      test(
        'two comments with different video fields are not equal',
        () {
          final comment1 = Comment(
            id: 'id',
            content: 'content',
            authorPubkey: 'author',
            createdAt: DateTime(2024),
            rootEventId: 'root',
            rootAuthorPubkey: 'rootAuthor',
            videoUrl: 'https://example.com/video1.mp4',
          );

          final comment2 = Comment(
            id: 'id',
            content: 'content',
            authorPubkey: 'author',
            createdAt: DateTime(2024),
            rootEventId: 'root',
            rootAuthorPubkey: 'rootAuthor',
            videoUrl: 'https://example.com/video2.mp4',
          );

          expect(comment1, isNot(equals(comment2)));
        },
      );
    });

    group('hasVideo', () {
      test('returns true when videoUrl is set', () {
        final comment = Comment(
          id: 'id',
          content: 'content',
          authorPubkey: 'author',
          createdAt: DateTime(2024),
          rootEventId: 'root',
          rootAuthorPubkey: 'rootAuthor',
          videoUrl: 'https://example.com/video.mp4',
        );

        expect(comment.hasVideo, isTrue);
      });

      test('returns false when videoUrl is null', () {
        final comment = Comment(
          id: 'id',
          content: 'content',
          authorPubkey: 'author',
          createdAt: DateTime(2024),
          rootEventId: 'root',
          rootAuthorPubkey: 'rootAuthor',
        );

        expect(comment.hasVideo, isFalse);
      });

      test('returns false when videoUrl is empty', () {
        final comment = Comment(
          id: 'id',
          content: 'content',
          authorPubkey: 'author',
          createdAt: DateTime(2024),
          rootEventId: 'root',
          rootAuthorPubkey: 'rootAuthor',
          videoUrl: '',
        );

        expect(comment.hasVideo, isFalse);
      });
    });

    group('video copyWith', () {
      late Comment original;

      setUp(() {
        original = Comment(
          id: 'id',
          content: 'content',
          authorPubkey: 'author',
          createdAt: DateTime(2024),
          rootEventId: 'root',
          rootAuthorPubkey: 'rootAuthor',
          videoUrl: 'https://example.com/video.mp4',
          thumbnailUrl: 'https://example.com/thumb.jpg',
          videoDimensions: '720x1280',
          videoDuration: 15,
          videoBlurhash: 'LEHV6nWB2yk8',
        );
      });

      test('creates copy with updated videoUrl', () {
        final copy = original.copyWith(
          videoUrl: 'https://example.com/new.mp4',
        );

        expect(
          copy.videoUrl,
          equals('https://example.com/new.mp4'),
        );
        expect(copy.thumbnailUrl, equals(original.thumbnailUrl));
      });

      test('creates copy with updated thumbnailUrl', () {
        final copy = original.copyWith(
          thumbnailUrl: 'https://example.com/new-thumb.jpg',
        );

        expect(
          copy.thumbnailUrl,
          equals('https://example.com/new-thumb.jpg'),
        );
        expect(copy.videoUrl, equals(original.videoUrl));
      });

      test('creates copy with updated videoDimensions', () {
        final copy = original.copyWith(
          videoDimensions: '1080x1920',
        );

        expect(copy.videoDimensions, equals('1080x1920'));
      });

      test('creates copy with updated videoDuration', () {
        final copy = original.copyWith(videoDuration: 30);

        expect(copy.videoDuration, equals(30));
      });

      test('creates copy with updated videoBlurhash', () {
        final copy = original.copyWith(
          videoBlurhash: 'newHash',
        );

        expect(copy.videoBlurhash, equals('newHash'));
      });

      test('preserves video fields when no parameters provided', () {
        final copy = original.copyWith();

        expect(copy, equals(original));
        expect(copy.videoUrl, equals(original.videoUrl));
        expect(
          copy.thumbnailUrl,
          equals(original.thumbnailUrl),
        );
        expect(
          copy.videoDimensions,
          equals(original.videoDimensions),
        );
        expect(
          copy.videoDuration,
          equals(original.videoDuration),
        );
        expect(
          copy.videoBlurhash,
          equals(original.videoBlurhash),
        );
      });
    });
  });
}
