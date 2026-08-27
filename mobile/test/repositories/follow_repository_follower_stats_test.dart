// ABOUTME: Tests for FollowRepository follower-count sourcing: REST counts
// ABOUTME: are authoritative (#8197); hysteresis applies only to relay
// ABOUTME: fallback, stabilizing partial counts across app restarts.

import 'package:db_client/db_client.dart' hide Filter;
import 'package:flutter_test/flutter_test.dart';
import 'package:follow_repository/follow_repository.dart';
import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';

class _MockNostrClient extends Mock implements NostrClient {}

class _MockFunnelcakeApiClient extends Mock implements FunnelcakeApiClient {}

class _MockProfileStatsDao extends Mock implements ProfileStatsDao {}

const _testPubkey =
    'abc123def4560000000000000000000000000000000000000000000000000001';

void _registerFallbackValues() {
  registerFallbackValue(<Filter>[]);
}

/// Builds a kind-3 contact list event for [_testPubkey] with [pTagCount]
/// `p` tags, used to drive the relay-fallback following count.
Event _contactListEvent(int pTagCount) {
  return Event(
    _testPubkey,
    EventKind.contactList,
    List.generate(
      pTagCount,
      (i) => ['p', i.toRadixString(16).padLeft(64, '0')],
    ),
    '',
    createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
  );
}

/// Creates a [FollowRepository] wired to mock dependencies.
///
/// [restFollowers] / [restFollowing] control what the REST API returns when
/// [restAvailable] is true. When [contactListEvent] is provided, the relay
/// fallback path can resolve a following count from it.
/// Pass [persistedRow] to seed the mock DAO with persisted stats.
FollowRepository _createRepository({
  required _MockFunnelcakeApiClient apiClient,
  required _MockProfileStatsDao dao,
  int restFollowers = 0,
  int restFollowing = 0,
  bool restAvailable = true,
  Event? contactListEvent,
  ProfileStatRow? persistedRow,
}) {
  final nostrClient = _MockNostrClient();

  // These cases fetch another profile. Keep the signed-in account distinct so
  // repository-owned persistence remains part of the scenario under test.
  when(() => nostrClient.publicKey).thenReturn('current-user');

  // Relay fallback: emit the contact list event when provided.
  when(() => nostrClient.subscribe(any())).thenAnswer(
    (_) => contactListEvent == null
        ? const Stream<Event>.empty()
        : Stream.value(contactListEvent),
  );

  // Mock REST API response.
  when(() => apiClient.isAvailable).thenReturn(restAvailable);
  when(() => apiClient.getSocialCounts(_testPubkey)).thenAnswer(
    (_) async => SocialCounts(
      pubkey: _testPubkey,
      followerCount: restFollowers,
      followingCount: restFollowing,
    ),
  );

  // Mock DAO reads.
  when(
    () => dao.getStatsRaw(_testPubkey),
  ).thenAnswer((_) async => persistedRow);

  // Mock DAO writes (no-op).
  when(
    () => dao.upsertStats(
      pubkey: any(named: 'pubkey'),
      followerCount: any(named: 'followerCount'),
      followingCount: any(named: 'followingCount'),
    ),
  ).thenAnswer((_) async {});

  return FollowRepository(
    nostrClient: nostrClient,
    funnelcakeApiClient: apiClient,
    profileStatsDao: dao,
    indexerRelayUrls: const [], // no real WebSocket connections
    queryContactList:
        ({
          required eventStream,
          required pubkey,
          fallbackTimeoutSeconds = 10,
        }) async {
          await for (final event in eventStream) {
            if (event.kind == EventKind.contactList && event.pubkey == pubkey) {
              return event;
            }
          }
          return null;
        },
  );
}

/// Helper to create a [ProfileStatRow] for seeding persisted stats.
ProfileStatRow _persistedRow({
  required int followers,
  required int following,
  DateTime? cachedAt,
  DateTime? followerCountsUpdatedAt,
}) {
  return ProfileStatRow(
    pubkey: _testPubkey,
    followerCount: followers,
    followingCount: following,
    cachedAt: cachedAt ?? DateTime.now(),
    followerCountsUpdatedAt: followerCountsUpdatedAt,
  );
}

void main() {
  _registerFallbackValues();

  group(FollowRepository, () {
    group('getFollowerStats - persistent cache', () {
      test('persists counts to Drift after first fetch', () async {
        final apiClient = _MockFunnelcakeApiClient();
        final dao = _MockProfileStatsDao();
        final repository = _createRepository(
          apiClient: apiClient,
          dao: dao,
          restFollowers: 50,
          restFollowing: 20,
        );

        final stats = await repository.getFollowerStats(_testPubkey);

        expect(stats.followers, equals(50));
        expect(stats.following, equals(20));

        // Verify it was persisted via the DAO.
        verify(
          () => dao.upsertStats(
            pubkey: _testPubkey,
            followerCount: 50,
            followingCount: 20,
          ),
        ).called(1);
      });

      test('returns persisted data on network failure', () async {
        final apiClient = _MockFunnelcakeApiClient();
        final dao = _MockProfileStatsDao();
        final repository = _createRepository(
          apiClient: apiClient,
          dao: dao,
          restFollowers: 50,
          restFollowing: 20,
          persistedRow: _persistedRow(followers: 42, following: 15),
        );

        // Make REST fail.
        when(
          () => apiClient.getSocialCounts(_testPubkey),
        ).thenThrow(Exception('network down'));

        final stats = await repository.getFollowerStats(_testPubkey);

        expect(stats.followers, equals(42));
        expect(stats.following, equals(15));
      });
    });

    group('getFollowerStats - REST authoritative (#8197)', () {
      test('accepts higher count immediately', () async {
        final apiClient = _MockFunnelcakeApiClient();
        final dao = _MockProfileStatsDao();
        final repository = _createRepository(
          apiClient: apiClient,
          dao: dao,
          restFollowers: 80,
          restFollowing: 30,
          persistedRow: _persistedRow(followers: 50, following: 20),
        );

        final stats = await repository.getFollowerStats(_testPubkey);

        expect(stats.followers, equals(80));
        expect(stats.following, equals(30));
      });

      test(
        'returns lower REST counts verbatim — no hysteresis on REST',
        () async {
          final apiClient = _MockFunnelcakeApiClient();
          final dao = _MockProfileStatsDao();
          // Persisted: 100 followers. Fresh REST: 85 — a drop that the old
          // hysteresis would have suppressed as "relay variance". REST is
          // deterministic, so the drop is real and must display.
          final repository = _createRepository(
            apiClient: apiClient,
            dao: dao,
            restFollowers: 85,
            restFollowing: 18,
            persistedRow: _persistedRow(followers: 100, following: 20),
          );

          final stats = await repository.getFollowerStats(_testPubkey);

          expect(stats.followers, equals(85));
          expect(stats.following, equals(18));
        },
      );

      test('does not query relays when REST answers', () async {
        final apiClient = _MockFunnelcakeApiClient();
        final dao = _MockProfileStatsDao();
        final repository = _createRepository(
          apiClient: apiClient,
          dao: dao,
          restFollowers: 50,
          restFollowing: 20,
          contactListEvent: _contactListEvent(80),
        );

        final stats = await repository.getFollowerStats(_testPubkey);

        // REST wins verbatim; the kind-3 event (80 p-tags) is never fetched.
        expect(stats.followers, equals(50));
        expect(stats.following, equals(20));
      });

      test('accepts counts when no persisted data exists', () async {
        final apiClient = _MockFunnelcakeApiClient();
        final dao = _MockProfileStatsDao();
        final repository = _createRepository(
          apiClient: apiClient,
          dao: dao,
          restFollowers: 42,
          restFollowing: 10,
        );

        final stats = await repository.getFollowerStats(_testPubkey);

        expect(stats.followers, equals(42));
        expect(stats.following, equals(10));
      });

      test('persists fresh REST counts that differ from baseline', () async {
        final apiClient = _MockFunnelcakeApiClient();
        final dao = _MockProfileStatsDao();
        final repository = _createRepository(
          apiClient: apiClient,
          dao: dao,
          restFollowers: 90,
          restFollowing: 20,
          persistedRow: _persistedRow(followers: 100, following: 20),
        );

        await repository.getFollowerStats(_testPubkey);

        verify(
          () => dao.upsertStats(
            pubkey: _testPubkey,
            followerCount: 90,
            followingCount: 20,
          ),
        ).called(1);
      });

      test('skips persisting when REST matches the baseline', () async {
        final apiClient = _MockFunnelcakeApiClient();
        final dao = _MockProfileStatsDao();
        final repository = _createRepository(
          apiClient: apiClient,
          dao: dao,
          restFollowers: 100,
          restFollowing: 20,
          persistedRow: _persistedRow(followers: 100, following: 20),
        );

        await repository.getFollowerStats(_testPubkey);

        verifyNever(
          () => dao.upsertStats(
            pubkey: any(named: 'pubkey'),
            followerCount: any(named: 'followerCount'),
            followingCount: any(named: 'followingCount'),
          ),
        );
      });
    });

    group('getFollowerStats - relay-fallback hysteresis', () {
      test(
        'holds the following count across an overnight gap (#6902)',
        () async {
          final apiClient = _MockFunnelcakeApiClient();
          final dao = _MockProfileStatsDao();
          // REST is unavailable, so the relay fallback answers. Last seen at
          // 98 the night before; the relay answers 86 in the morning — a
          // partial view, within the hysteresis threshold, so the persisted
          // baseline holds. The baseline's freshness must be judged by
          // followerCountsUpdatedAt, not the unrelated (stale) cachedAt.
          final lastNight = DateTime.now().subtract(const Duration(hours: 10));
          final unrelated = DateTime.now().subtract(const Duration(hours: 30));
          final repository = _createRepository(
            apiClient: apiClient,
            dao: dao,
            restAvailable: false,
            contactListEvent: _contactListEvent(86),
            persistedRow: _persistedRow(
              followers: 0,
              following: 98,
              cachedAt: unrelated,
              followerCountsUpdatedAt: lastNight,
            ),
          );

          final stats = await repository.getFollowerStats(_testPubkey);

          expect(stats.following, equals(98));
        },
      );

      test('boundary: relay count exactly at threshold is held', () async {
        final apiClient = _MockFunnelcakeApiClient();
        final dao = _MockProfileStatsDao();
        // Persisted following: 100. Threshold = ceil(100 * 0.8) = 80.
        // Relay answers exactly 80 → still treated as relay variance.
        final repository = _createRepository(
          apiClient: apiClient,
          dao: dao,
          restAvailable: false,
          contactListEvent: _contactListEvent(80),
          persistedRow: _persistedRow(followers: 0, following: 100),
        );

        final stats = await repository.getFollowerStats(_testPubkey);

        expect(stats.following, equals(100));
      });

      test('boundary: relay count one below threshold is accepted', () async {
        final apiClient = _MockFunnelcakeApiClient();
        final dao = _MockProfileStatsDao();
        // Persisted following: 100. Threshold = ceil(100 * 0.8) = 80.
        // Relay answers 79 → genuine drop, accept it.
        final repository = _createRepository(
          apiClient: apiClient,
          dao: dao,
          restAvailable: false,
          contactListEvent: _contactListEvent(79),
          persistedRow: _persistedRow(followers: 0, following: 100),
        );

        final stats = await repository.getFollowerStats(_testPubkey);

        expect(stats.following, equals(79));
      });
    });

    group('getFollowerStats - in-memory cache', () {
      test(
        'second call returns in-memory cached data without network call',
        () async {
          final apiClient = _MockFunnelcakeApiClient();
          final dao = _MockProfileStatsDao();
          final repository = _createRepository(
            apiClient: apiClient,
            dao: dao,
            restFollowers: 50,
            restFollowing: 20,
          );

          // First call — hits network.
          await repository.getFollowerStats(_testPubkey);
          verify(() => apiClient.getSocialCounts(_testPubkey)).called(1);

          // Second call — should use in-memory cache.
          final stats = await repository.getFollowerStats(_testPubkey);
          expect(stats.followers, equals(50));
          // No additional network call.
          verifyNever(() => apiClient.getSocialCounts(_testPubkey));
        },
      );
    });
  });
}
