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

    test('returns false when the request throws', () async {
      when(
        () => mockHttpClient.get(byPubkeyUri),
      ).thenThrow(Exception('network down'));

      final result = await repository.hasDivineIdentity(pubkey);

      expect(result, isFalse);
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
