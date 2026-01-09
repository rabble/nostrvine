// Not required for test files
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:profile_repository/profile_repository.dart';
import 'package:test/test.dart';

class _MockNostrClient extends Mock implements NostrClient {}

void main() {
  group('ProfileRepository', () {
    late NostrClient nostrClient;

    setUp(() {
      nostrClient = _MockNostrClient();
    });

    test('can be instantiated', () {
      expect(ProfileRepository(nostrClient: nostrClient), isNotNull);
    });
  });
}
