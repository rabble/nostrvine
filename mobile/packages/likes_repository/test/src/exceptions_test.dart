import 'package:likes_repository/likes_repository.dart';
import 'package:test/test.dart';

void main() {
  group('LikesRepositoryException', () {
    test('has correct message', () {
      const exception = LikesRepositoryException('base message');
      expect(exception.message, equals('base message'));
    });

    test('toString returns expected format', () {
      const exception = LikesRepositoryException('base message');
      expect(
        exception.toString(),
        equals('LikesRepositoryException: base message'),
      );
    });
  });

  group('LikeFailedException', () {
    test('has correct message', () {
      const exception = LikeFailedException('test message');
      expect(exception.message, equals('test message'));
    });

    test('toString contains class name', () {
      const exception = LikeFailedException('test message');
      expect(exception.toString(), contains('LikeFailedException'));
    });
  });

  group('UnlikeFailedException', () {
    test('has correct message', () {
      const exception = UnlikeFailedException('test message');
      expect(exception.message, equals('test message'));
    });

    test('toString contains class name', () {
      const exception = UnlikeFailedException('test message');
      expect(exception.toString(), contains('UnlikeFailedException'));
    });
  });

  group('NotAuthenticatedException', () {
    test('has default message', () {
      const exception = NotAuthenticatedException();
      expect(exception.message, equals('User not authenticated'));
    });

    test('toString contains class name', () {
      const exception = NotAuthenticatedException();
      expect(exception.toString(), contains('NotAuthenticatedException'));
    });
  });

  group('AlreadyLikedException', () {
    test('includes event ID in message', () {
      const exception = AlreadyLikedException('event123');
      expect(exception.message, contains('event123'));
    });

    test('toString contains class name', () {
      const exception = AlreadyLikedException('event123');
      expect(exception.toString(), contains('AlreadyLikedException'));
    });
  });

  group('NotLikedException', () {
    test('includes event ID in message', () {
      const exception = NotLikedException('event123');
      expect(exception.message, contains('event123'));
    });

    test('toString contains class name', () {
      const exception = NotLikedException('event123');
      expect(exception.toString(), contains('NotLikedException'));
    });
  });

  group('SyncFailedException', () {
    test('has correct message', () {
      const exception = SyncFailedException('sync error');
      expect(exception.message, equals('sync error'));
    });

    test('toString contains class name', () {
      const exception = SyncFailedException('sync error');
      expect(exception.toString(), contains('SyncFailedException'));
    });
  });

  group('FetchLikesFailedException', () {
    test('has correct message', () {
      const exception = FetchLikesFailedException('fetch error');
      expect(exception.message, equals('fetch error'));
    });

    test('toString contains class name', () {
      const exception = FetchLikesFailedException('fetch error');
      expect(exception.toString(), contains('FetchLikesFailedException'));
    });
  });
}
