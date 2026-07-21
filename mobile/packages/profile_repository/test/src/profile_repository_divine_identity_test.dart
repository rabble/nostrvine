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
  group('ProfileRepository.resolveDivineIdentity', () {
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

    group('verdicts', () {
      test('returns the genuine verdict on a 200', () async {
        when(() => mockHttpClient.get(byPubkeyUri)).thenAnswer(
          (_) async => Response('{"ok":true,"found":true,"name":"alice"}', 200),
        );

        expect(await repository.resolveDivineIdentity(pubkey), isTrue);
      });

      test('returns false for an empty pubkey without querying', () async {
        expect(await repository.resolveDivineIdentity('   '), isFalse);
        verifyNever(() => mockHttpClient.get(any()));
      });

      test('returns null (undetermined) on a non-200', () async {
        when(
          () => mockHttpClient.get(byPubkeyUri),
        ).thenAnswer((_) async => Response('{"ok":false}', 503));

        expect(await repository.resolveDivineIdentity(pubkey), isNull);
      });

      test('returns null (undetermined) when the request throws', () async {
        when(
          () => mockHttpClient.get(byPubkeyUri),
        ).thenThrow(Exception('network down'));

        expect(await repository.resolveDivineIdentity(pubkey), isNull);
      });

      test('returns null (undetermined) on a non-object 200 body', () async {
        when(
          () => mockHttpClient.get(byPubkeyUri),
        ).thenAnswer((_) async => Response('[]', 200));

        expect(await repository.resolveDivineIdentity(pubkey), isNull);
      });
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

        final first = await repository.resolveDivineIdentity(pubkey);
        final second = await repository.resolveDivineIdentity(pubkey);

        expect(first, isNull);
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

      final first = await repository.resolveDivineIdentity(pubkey);
      final second = await repository.resolveDivineIdentity(pubkey);

      expect(first, isNull);
      expect(second, isTrue);
      verify(() => mockHttpClient.get(byPubkeyUri)).called(2);
    });

    test(
      'caches within the TTL so a repeat lookup hits the network once',
      () async {
        when(() => mockHttpClient.get(byPubkeyUri)).thenAnswer(
          (_) async => Response('{"ok":true,"found":true,"name":"alice"}', 200),
        );

        final first = await repository.resolveDivineIdentity(pubkey);
        final second = await repository.resolveDivineIdentity(pubkey);

        expect(first, isTrue);
        expect(second, isTrue);
        verify(() => mockHttpClient.get(byPubkeyUri)).called(1);
      },
    );

    test('evicts the oldest entry once the cache is full', () async {
      when(() => mockHttpClient.get(any())).thenAnswer(
        (_) async => Response('{"ok":true,"found":false}', 200),
      );

      String pubkeyForIndex(int i) => i.toRadixString(16).padLeft(64, '0');
      for (var i = 0; i <= 500; i++) {
        await repository.resolveDivineIdentity(pubkeyForIndex(i));
      }

      final evictedUri = Uri.parse(
        'https://names.divine.video/api/username/by-pubkey/'
        '${pubkeyForIndex(0)}',
      );
      await repository.resolveDivineIdentity(pubkeyForIndex(0));

      verify(() => mockHttpClient.get(evictedUri)).called(2);
    });

    test('normalizes the pubkey to lowercase before querying', () async {
      when(() => mockHttpClient.get(byPubkeyUri)).thenAnswer(
        (_) async => Response('{"ok":true,"found":true,"name":"alice"}', 200),
      );

      final result = await repository.resolveDivineIdentity(
        pubkey.toUpperCase(),
      );

      expect(result, isTrue);
      verify(() => mockHttpClient.get(byPubkeyUri)).called(1);
    });
  });
}
