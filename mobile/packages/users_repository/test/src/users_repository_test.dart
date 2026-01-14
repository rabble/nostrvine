import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:test/test.dart';
import 'package:users_repository/users_repository.dart';

class _MockNostrClient extends Mock implements NostrClient {}

void main() {
  group('UsersRepository', () {
    late _MockNostrClient mockNostrClient;
    late UsersRepository repository;

    const testPubkey =
        'abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890';

    setUp(() {
      mockNostrClient = _MockNostrClient();
      repository = UsersRepository(nostrClient: mockNostrClient);
    });

    test('can be instantiated', () {
      expect(repository, isNotNull);
    });

    group('getUser', () {
      test('throws UserNotFoundException when profile not found', () async {
        when(() => mockNostrClient.fetchProfile(testPubkey)).thenAnswer(
          (_) async => null,
        );

        expect(
          () => repository.getUser(testPubkey),
          throwsA(
            isA<UserNotFoundException>().having(
              (e) => e.pubkey,
              'pubkey',
              testPubkey,
            ),
          ),
        );

        verify(() => mockNostrClient.fetchProfile(testPubkey)).called(1);
      });

      test('returns User with correct fields', () async {
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

        when(() => mockNostrClient.fetchProfile(testPubkey)).thenAnswer(
          (_) async => event,
        );

        final user = await repository.getUser(testPubkey);

        expect(user.pubkey, equals(testPubkey));
        expect(user.name, equals('testname'));
        expect(user.displayName, equals('Test User'));
        expect(user.nip05, equals('test@example.com'));

        verify(() => mockNostrClient.fetchProfile(testPubkey)).called(1);
      });

      test('handles missing optional fields', () async {
        final event = Event.fromJson({
          'id': 'test-event-id',
          'pubkey': testPubkey,
          'created_at': 1704067200,
          'kind': EventKind.metadata,
          'tags': <List<String>>[],
          'content': '{}',
          'sig': '',
        });

        when(() => mockNostrClient.fetchProfile(testPubkey)).thenAnswer(
          (_) async => event,
        );

        final user = await repository.getUser(testPubkey);

        expect(user.pubkey, equals(testPubkey));
        expect(user.name, isNull);
        expect(user.displayName, isNull);
        expect(user.nip05, isNull);
      });
    });
  });

  group('UserNotFoundException', () {
    test('toString returns descriptive message', () {
      const exception = UserNotFoundException('test-pubkey');

      expect(
        exception.toString(),
        equals('UserNotFoundException: User with pubkey test-pubkey not found'),
      );
    });
  });
}
