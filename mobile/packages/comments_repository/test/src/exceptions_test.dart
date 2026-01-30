import 'package:comments_repository/comments_repository.dart';
import 'package:test/test.dart';

void main() {
  group('CommentsRepositoryException', () {
    group('LoadCommentsFailedException', () {
      test('can be created without message', () {
        const exception = LoadCommentsFailedException();

        expect(exception.message, isNull);
      });

      test('can be created with message', () {
        const exception = LoadCommentsFailedException('test message');

        expect(exception.message, equals('test message'));
      });

      test('toString returns runtimeType when message is null', () {
        const exception = LoadCommentsFailedException();

        expect(exception.toString(), equals('LoadCommentsFailedException'));
      });

      test('toString returns formatted message when message is provided', () {
        const exception = LoadCommentsFailedException('test error');

        expect(
          exception.toString(),
          equals('LoadCommentsFailedException: test error'),
        );
      });
    });

    group('PostCommentFailedException', () {
      test('can be created without message', () {
        const exception = PostCommentFailedException();

        expect(exception.message, isNull);
      });

      test('can be created with message', () {
        const exception = PostCommentFailedException('test message');

        expect(exception.message, equals('test message'));
      });

      test('toString returns formatted message', () {
        const exception = PostCommentFailedException('publish failed');

        expect(
          exception.toString(),
          equals('PostCommentFailedException: publish failed'),
        );
      });
    });

    group('CountCommentsFailedException', () {
      test('can be created without message', () {
        const exception = CountCommentsFailedException();

        expect(exception.message, isNull);
      });

      test('can be created with message', () {
        const exception = CountCommentsFailedException('count error');

        expect(exception.message, equals('count error'));
      });

      test('toString returns formatted message', () {
        const exception = CountCommentsFailedException('count failed');

        expect(
          exception.toString(),
          equals('CountCommentsFailedException: count failed'),
        );
      });
    });

    group('InvalidCommentContentException', () {
      test('can be created without message', () {
        const exception = InvalidCommentContentException();

        expect(exception.message, isNull);
      });

      test('can be created with message', () {
        const exception = InvalidCommentContentException('empty content');

        expect(exception.message, equals('empty content'));
      });

      test('toString returns formatted message', () {
        const exception = InvalidCommentContentException('content is empty');

        expect(
          exception.toString(),
          equals('InvalidCommentContentException: content is empty'),
        );
      });
    });

    group('DeleteCommentFailedException', () {
      test('can be created without message', () {
        const exception = DeleteCommentFailedException();

        expect(exception.message, isNull);
      });

      test('can be created with message', () {
        const exception = DeleteCommentFailedException('delete error');

        expect(exception.message, equals('delete error'));
      });

      test('toString returns formatted message', () {
        const exception = DeleteCommentFailedException('delete failed');

        expect(
          exception.toString(),
          equals('DeleteCommentFailedException: delete failed'),
        );
      });
    });
  });
}
