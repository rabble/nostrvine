import 'package:db_client/db_client.dart' hide Filter, ProfileStats;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:profile_repository/profile_repository.dart';

class _MockNostrClient extends Mock implements NostrClient {}

class _MockUserProfilesDao extends Mock implements UserProfilesDao {}

class _MockHttpClient extends Mock implements Client {}

void main() {
  group('ProfileRepository.hasDivineIdentity', () {
    late _MockNostrClient mockNostrClient;
    late _MockUserProfilesDao mockUserProfilesDao;
    late _MockHttpClient mockHttpClient;
    late ProfileRepository repository;

    const pubkey =
        'a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2';
    final byPubkeyUri = Uri.parse(
      'https://names.divine.video/api/username/by-pubkey/$pubkey',
    );

    setUpAll(() {
      registerFallbackValue(Uri.parse('https://example.com'));
    });

    setUp(() {
      mockNostrClient = _MockNostrClient();
      mockUserProfilesDao = _MockUserProfilesDao();
      mockHttpClient = _MockHttpClient();
      repository = ProfileRepository(
        nostrClient: mockNostrClient,
        userProfilesDao: mockUserProfilesDao,
        httpClient: mockHttpClient,
      );
    });

    test('returns true when the name server reports found', () async {
      when(() => mockHttpClient.get(byPubkeyUri)).thenAnswer(
        (_) async => Response('{"ok":true,"found":true,"name":"alice"}', 200),
      );

      final result = await repository.hasDivineIdentity(pubkey);

      expect(result, isTrue);
    });

    test('returns false when the name server reports not found', () async {
      when(() => mockHttpClient.get(byPubkeyUri)).thenAnswer(
        (_) async => Response('{"ok":true,"found":false}', 200),
      );

      final result = await repository.hasDivineIdentity(pubkey);

      expect(result, isFalse);
    });

    test('returns false on a non-200 response', () async {
      when(
        () => mockHttpClient.get(byPubkeyUri),
      ).thenAnswer((_) async => Response('{"ok":false}', 500));

      final result = await repository.hasDivineIdentity(pubkey);

      expect(result, isFalse);
    });

    test(
      'returns false when a 200 body is valid JSON but not an object',
      () async {
        // `[]` decodes fine, so a naive cast to Map throws a TypeError —
        // an Error, not an Exception — which would escape the catch and
        // propagate to callers instead of the documented false.
        when(
          () => mockHttpClient.get(byPubkeyUri),
        ).thenAnswer((_) async => Response('[]', 200));

        final result = await repository.hasDivineIdentity(pubkey);

        expect(result, isFalse);
      },
    );

    test('returns false when a 200 body is not valid JSON', () async {
      when(
        () => mockHttpClient.get(byPubkeyUri),
      ).thenAnswer((_) async => Response('<html>gateway error</html>', 200));

      final result = await repository.hasDivineIdentity(pubkey);

      expect(result, isFalse);
    });

    test('returns false when the request throws', () async {
      when(
        () => mockHttpClient.get(byPubkeyUri),
      ).thenThrow(Exception('network down'));

      final result = await repository.hasDivineIdentity(pubkey);

      expect(result, isFalse);
    });

    test(
      'does not cache a non-200 response, so the next call retries',
      () async {
        final responses = [
          Response('{"ok":false}', 500),
          Response('{"ok":true,"found":true,"name":"alice"}', 200),
        ];
        when(
          () => mockHttpClient.get(byPubkeyUri),
        ).thenAnswer((_) async => responses.removeAt(0));

        final first = await repository.hasDivineIdentity(pubkey);
        final second = await repository.hasDivineIdentity(pubkey);

        expect(first, isFalse);
        expect(second, isTrue);
        verify(() => mockHttpClient.get(byPubkeyUri)).called(2);
      },
    );

    test('does not cache a thrown lookup, so the next call retries', () async {
      var calls = 0;
      when(() => mockHttpClient.get(byPubkeyUri)).thenAnswer((_) async {
        calls++;
        if (calls == 1) throw Exception('network down');
        return Response('{"ok":true,"found":true,"name":"alice"}', 200);
      });

      final first = await repository.hasDivineIdentity(pubkey);
      final second = await repository.hasDivineIdentity(pubkey);

      expect(first, isFalse);
      expect(second, isTrue);
      verify(() => mockHttpClient.get(byPubkeyUri)).called(2);
    });

    test(
      'caches within the TTL so a repeat lookup hits the network once',
      () async {
        when(() => mockHttpClient.get(byPubkeyUri)).thenAnswer(
          (_) async => Response('{"ok":true,"found":true,"name":"alice"}', 200),
        );

        final first = await repository.hasDivineIdentity(pubkey);
        final second = await repository.hasDivineIdentity(pubkey);

        expect(first, isTrue);
        expect(second, isTrue);
        verify(() => mockHttpClient.get(byPubkeyUri)).called(1);
      },
    );

    test('evicts the oldest entry once the cache is full', () async {
      when(() => mockHttpClient.get(any())).thenAnswer(
        (_) async => Response('{"ok":true,"found":false}', 200),
      );

      // Fill past the 500-entry cap (indices 0..500 = 501 distinct pubkeys)
      // so the oldest entry (index 0) is evicted.
      String pubkeyForIndex(int i) => i.toRadixString(16).padLeft(64, '0');
      for (var i = 0; i <= 500; i++) {
        await repository.hasDivineIdentity(pubkeyForIndex(i));
      }

      final evictedUri = Uri.parse(
        'https://names.divine.video/api/username/by-pubkey/'
        '${pubkeyForIndex(0)}',
      );
      // Index 0 was evicted, so looking it up again hits the network a
      // second time rather than returning a cached value.
      await repository.hasDivineIdentity(pubkeyForIndex(0));

      verify(() => mockHttpClient.get(evictedUri)).called(2);
    });

    test('normalizes the pubkey to lowercase before querying', () async {
      when(() => mockHttpClient.get(byPubkeyUri)).thenAnswer(
        (_) async => Response('{"ok":true,"found":true,"name":"alice"}', 200),
      );

      final result = await repository.hasDivineIdentity(pubkey.toUpperCase());

      expect(result, isTrue);
      verify(() => mockHttpClient.get(byPubkeyUri)).called(1);
    });
  });
}
