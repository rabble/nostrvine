import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:reposts_repository/reposts_repository.dart';
import 'package:test/test.dart';

class MockNostrClient extends Mock implements NostrClient {}

void main() {
  group('RepostsRepository', () {
    late MockNostrClient mockNostrClient;

    setUp(() {
      mockNostrClient = MockNostrClient();
      when(() => mockNostrClient.publicKey).thenReturn('test_pubkey');
    });

    test('can be instantiated', () {
      final repository = RepostsRepository(
        nostrClient: mockNostrClient,
        eventCreator:
            ({
              required int kind,
              required String content,
              required List<List<String>> tags,
            }) async => null,
      );
      expect(repository, isNotNull);
    });

    test('isRepostedSync returns false for non-reposted video', () {
      final repository = RepostsRepository(
        nostrClient: mockNostrClient,
        eventCreator:
            ({
              required int kind,
              required String content,
              required List<List<String>> tags,
            }) async => null,
      );
      expect(repository.isRepostedSync('34236:pubkey:dtag'), isFalse);
    });

    group('buildAddressableId', () {
      test('builds correct addressable ID format', () {
        final addressableId = buildAddressableId(
          authorPubkey: 'abc123',
          dTag: 'my-video',
        );
        expect(addressableId, equals('34236:abc123:my-video'));
      });
    });
  });
}
