import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:test/test.dart';
import 'package:users_repository/users_repository.dart';

void main() {
  group('User', () {
    const testPubkey =
        'abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890';

    test('can be instantiated with required pubkey', () {
      const user = User(pubkey: testPubkey);

      expect(user.pubkey, equals(testPubkey));
      expect(user.name, isNull);
      expect(user.displayName, isNull);
      expect(user.nip05, isNull);
    });

    test('can be instantiated with all fields', () {
      const user = User(
        pubkey: testPubkey,
        name: 'testname',
        displayName: 'Test User',
        nip05: 'test@example.com',
      );

      expect(user.pubkey, equals(testPubkey));
      expect(user.name, equals('testname'));
      expect(user.displayName, equals('Test User'));
      expect(user.nip05, equals('test@example.com'));
    });

    group('bestDisplayName', () {
      test('returns displayName when set', () {
        const user = User(
          pubkey: testPubkey,
          name: 'testname',
          displayName: 'Test User',
        );

        expect(user.bestDisplayName, equals('Test User'));
      });

      test('returns name when displayName is null', () {
        const user = User(
          pubkey: testPubkey,
          name: 'testname',
        );

        expect(user.bestDisplayName, equals('testname'));
      });

      test('returns name when displayName is empty', () {
        const user = User(
          pubkey: testPubkey,
          name: 'testname',
          displayName: '',
        );

        expect(user.bestDisplayName, equals('testname'));
      });

      test('returns truncatedPubkey when both are null', () {
        const user = User(pubkey: testPubkey);

        expect(user.bestDisplayName, equals('abcdef12...'));
      });

      test('returns truncatedPubkey when both are empty', () {
        const user = User(
          pubkey: testPubkey,
          name: '',
          displayName: '',
        );

        expect(user.bestDisplayName, equals('abcdef12...'));
      });
    });

    group('truncatedPubkey', () {
      test('returns first 8 chars + "..."', () {
        const user = User(pubkey: testPubkey);

        expect(user.truncatedPubkey, equals('abcdef12...'));
      });
    });

    group('hasNip05', () {
      test('returns true when nip05 is set', () {
        const user = User(
          pubkey: testPubkey,
          nip05: 'test@example.com',
        );

        expect(user.hasNip05, isTrue);
      });

      test('returns false when nip05 is null', () {
        const user = User(pubkey: testPubkey);

        expect(user.hasNip05, isFalse);
      });

      test('returns false when nip05 is empty', () {
        const user = User(
          pubkey: testPubkey,
          nip05: '',
        );

        expect(user.hasNip05, isFalse);
      });
    });

    group('fromNostrEvent', () {
      test('parses profile event correctly', () {
        const profileContent =
            '{"name":"testname",'
            '"display_name":"Test User","nip05":"test@example.com"}';
        final event = Event.fromJson({
          'id': 'test-event-id',
          'pubkey': testPubkey,
          'created_at': 1704067200,
          'kind': EventKind.metadata,
          'tags': <List<String>>[],
          'content': profileContent,
          'sig': '',
        });

        final user = User.fromNostrEvent(event);

        expect(user.pubkey, equals(testPubkey));
        expect(user.name, equals('testname'));
        expect(user.displayName, equals('Test User'));
        expect(user.nip05, equals('test@example.com'));
      });

      test('parses displayName field (camelCase variant)', () {
        final event = Event.fromJson({
          'id': 'test-event-id',
          'pubkey': testPubkey,
          'created_at': 1704067200,
          'kind': EventKind.metadata,
          'tags': <List<String>>[],
          'content': '{"displayName":"Test User"}',
          'sig': '',
        });

        final user = User.fromNostrEvent(event);

        expect(user.displayName, equals('Test User'));
      });

      test('handles missing optional fields', () {
        final event = Event.fromJson({
          'id': 'test-event-id',
          'pubkey': testPubkey,
          'created_at': 1704067200,
          'kind': EventKind.metadata,
          'tags': <List<String>>[],
          'content': '{}',
          'sig': '',
        });

        final user = User.fromNostrEvent(event);

        expect(user.pubkey, equals(testPubkey));
        expect(user.name, isNull);
        expect(user.displayName, isNull);
        expect(user.nip05, isNull);
      });

      test('handles invalid JSON content gracefully', () {
        final event = Event.fromJson({
          'id': 'test-event-id',
          'pubkey': testPubkey,
          'created_at': 1704067200,
          'kind': EventKind.metadata,
          'tags': <List<String>>[],
          'content': 'invalid json',
          'sig': '',
        });

        final user = User.fromNostrEvent(event);

        expect(user.pubkey, equals(testPubkey));
        expect(user.name, isNull);
        expect(user.displayName, isNull);
        expect(user.nip05, isNull);
      });
    });

    group('equality', () {
      test('users with same pubkey are equal', () {
        const user1 = User(pubkey: testPubkey, name: 'Name 1');
        const user2 = User(pubkey: testPubkey, name: 'Name 2');

        expect(user1, equals(user2));
      });

      test('users with different pubkeys are not equal', () {
        const otherPubkey =
            '1234567890abcdef1234567890abcdef'
            '1234567890abcdef1234567890abcdef';
        const user1 = User(pubkey: testPubkey);
        const user2 = User(pubkey: otherPubkey);

        expect(user1, isNot(equals(user2)));
      });

      test('hashCode is based on pubkey', () {
        const user1 = User(pubkey: testPubkey, name: 'Name 1');
        const user2 = User(pubkey: testPubkey, name: 'Name 2');

        expect(user1.hashCode, equals(user2.hashCode));
      });
    });

    test('toString returns readable representation', () {
      const user = User(
        pubkey: testPubkey,
        displayName: 'Test User',
      );

      expect(
        user.toString(),
        equals('User(pubkey: abcdef12..., name: Test User)'),
      );
    });
  });
}
