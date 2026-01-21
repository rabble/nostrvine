import 'package:reposts_repository/reposts_repository.dart';
import 'package:test/test.dart';

void main() {
  group('Exceptions', () {
    test('RepostsRepositoryException has correct message', () {
      const exception = RepostsRepositoryException('Test message');
      expect(exception.message, equals('Test message'));
      expect(exception.toString(), contains('Test message'));
    });

    test('RepostFailedException has correct format', () {
      const exception = RepostFailedException('Failed to publish');
      expect(exception.message, equals('Failed to publish'));
      expect(
        exception.toString(),
        equals('RepostFailedException: Failed to publish'),
      );
    });

    test('UnrepostFailedException has correct format', () {
      const exception = UnrepostFailedException('Failed to delete');
      expect(exception.message, equals('Failed to delete'));
      expect(
        exception.toString(),
        equals('UnrepostFailedException: Failed to delete'),
      );
    });

    test('NotAuthenticatedException has default message', () {
      const exception = NotAuthenticatedException();
      expect(exception.message, equals('User not authenticated'));
      expect(
        exception.toString(),
        equals('NotAuthenticatedException: User not authenticated'),
      );
    });

    test('AlreadyRepostedException includes addressable ID', () {
      const exception = AlreadyRepostedException('34236:author:dtag');
      expect(exception.message, contains('34236:author:dtag'));
      expect(exception.message, contains('already reposted'));
      expect(
        exception.toString(),
        equals('AlreadyRepostedException: ${exception.message}'),
      );
    });

    test('NotRepostedException includes addressable ID', () {
      const exception = NotRepostedException('34236:author:dtag');
      expect(exception.message, contains('34236:author:dtag'));
      expect(exception.message, contains('not reposted'));
      expect(
        exception.toString(),
        equals('NotRepostedException: ${exception.message}'),
      );
    });

    test('SyncFailedException has correct format', () {
      const exception = SyncFailedException('Network error');
      expect(exception.message, equals('Network error'));
      expect(
        exception.toString(),
        equals('SyncFailedException: Network error'),
      );
    });

    test('FetchRepostsFailedException has correct format', () {
      const exception = FetchRepostsFailedException('Query failed');
      expect(exception.message, equals('Query failed'));
      expect(
        exception.toString(),
        equals('FetchRepostsFailedException: Query failed'),
      );
    });

    test('MissingDTagException has default message', () {
      const exception = MissingDTagException();
      expect(exception.message, contains('d-tag'));
      expect(exception.toString(), contains('MissingDTagException'));
    });
  });
}
