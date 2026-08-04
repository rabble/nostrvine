// ABOUTME: Pins the ProfileReader read/write split — the compile-time
// ABOUTME: boundary that keeps signing off the ungated profile provider.

import 'package:db_client/db_client.dart' hide Filter, ProfileStats;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:profile_repository/profile_repository.dart';

class _MockNostrClient extends Mock implements NostrClient {}

class _MockUserProfilesDao extends Mock implements UserProfilesDao {}

class _MockHttpClient extends Mock implements Client {}

const _pubkey =
    'a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2';

/// A standalone [ProfileReader] that implements the interface **without**
/// extending [ProfileRepository].
///
/// This is the guard: adding any member to [ProfileReader] stops this class
/// from compiling, so the whole suite goes red. That is deliberate — the
/// interface is a security boundary (see `profile_reader.dart`), and widening
/// it must be a conscious act, not a drive-by. If you are here because this
/// failed to compile, confirm the new member is signer-free before adding it
/// below.
class _ExhaustiveReader implements ProfileReader {
  @override
  Future<UserProfile?> getCachedProfile({required String pubkey}) async => null;

  @override
  Stream<UserProfile?> watchProfile({required String pubkey}) =>
      const Stream.empty();

  @override
  Stream<ProfileStats?> watchProfileStats({required String pubkey}) =>
      const Stream.empty();

  @override
  Future<UserProfile?> fetchFreshProfile({
    required String pubkey,
    bool requireRawKind0 = false,
    List<Duration> rawKind0RetryDelays = const [],
  }) async => null;

  @override
  Future<Map<String, UserProfile>> fetchBatchProfiles({
    required List<String> pubkeys,
  }) async => {};

  @override
  Future<List<List<String>>?> cachedIdentityTags(String pubkey) async => null;

  @override
  Future<List<List<String>>> freshIdentityTags({
    required String pubkey,
    required List<List<String>> kind0Tags,
  }) async => const [];
}

void main() {
  group(ProfileReader, () {
    late _MockUserProfilesDao userProfilesDao;
    late ProfileRepository repository;

    setUp(() {
      userProfilesDao = _MockUserProfilesDao();
      repository = ProfileRepository(
        nostrClient: _MockNostrClient(),
        userProfilesDao: userProfilesDao,
        httpClient: _MockHttpClient(),
      );
    });

    test('is implemented by $ProfileRepository', () {
      expect(repository, isA<ProfileReader>());
    });

    test('reads the Drift cache through the interface handle', () async {
      final cached = UserProfile(
        pubkey: _pubkey,
        name: 'real-name',
        rawData: const {},
        createdAt: DateTime.utc(2026),
        eventId: 'event-id',
      );
      when(
        () => userProfilesDao.getProfile(_pubkey),
      ).thenAnswer((_) async => cached);

      // Deliberately typed as the interface: this is the handle the
      // identity-known provider hands to display code.
      final ProfileReader reader = repository;

      expect(await reader.getCachedProfile(pubkey: _pubkey), cached);
    });

    test('an implementation needs no signer and no relay client', () {
      // _ExhaustiveReader satisfies the contract with neither. If this stops
      // compiling, a signing member reached the interface.
      expect(_ExhaustiveReader(), isA<ProfileReader>());
    });
  });
}
