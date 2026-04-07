// ABOUTME: Tests for FollowRepository persistent follower count cache and
// ABOUTME: hysteresis logic that stabilizes counts across app restarts.

import 'package:db_client/db_client.dart' hide Filter;
import 'package:flutter_test/flutter_test.dart';
import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:openvine/repositories/follow_repository.dart';

class _MockNostrClient extends Mock implements NostrClient {}

class _MockFunnelcakeApiClient extends Mock implements FunnelcakeApiClient {}

class _MockProfileStatsDao extends Mock implements ProfileStatsDao {}

const _testPubkey = 'abc123def456';

void _registerFallbackValues() {
  registerFallbackValue(<Filter>[]);
}

/// Creates a [FollowRepository] wired to mock dependencies.
///
/// [restFollowers] / [restFollowing] control what the REST API returns.
/// Pass [indexerRelayUrls] as empty to avoid real WebSocket connections.
/// Pass [persistedRow] to seed the mock DAO with persisted stats.
FollowRepository _createRepository({
  required _MockFunnelcakeApiClient apiClient,
  required _MockProfileStatsDao dao,
  int restFollowers = 0,
  int restFollowing = 0,
  ProfileStatRow? persistedRow,
}) {
  final nostrClient = _MockNostrClient();

  // Mock NostrClient.subscribe to return an empty stream (no WS data).
  when(() => nostrClient.subscribe(any())).thenAnswer(
    (_) => const Stream<Event>.empty(),
  );

  // Mock REST API response.
  when(() => apiClient.isAvailable).thenReturn(true);
  when(() => apiClient.getSocialCounts(_testPubkey)).thenAnswer(
    (_) async => SocialCounts(
      pubkey: _testPubkey,
      followerCount: restFollowers,
      followingCount: restFollowing,
    ),
  );

  // Mock DAO reads.
  when(() => dao.getStatsRaw(_testPubkey)).thenAnswer(
    (_) async => persistedRow,
  );

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
  );
}

/// Helper to create a [ProfileStatRow] for seeding persisted stats.
ProfileStatRow _persistedRow({
  required int followers,
  required int following,
  DateTime? cachedAt,
}) {
  return ProfileStatRow(
    pubkey: _testPubkey,
    followerCount: followers,
    followingCount: following,
    cachedAt: cachedAt ?? DateTime.now(),
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

    group('getFollowerStats - hysteresis', () {
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
        'keeps persisted count when fresh is lower but within threshold',
        () async {
          final apiClient = _MockFunnelcakeApiClient();
          final dao = _MockProfileStatsDao();
          // Persisted: 100 followers. Fresh: 85 (15% drop, within 20% threshold).
          final repository = _createRepository(
            apiClient: apiClient,
            dao: dao,
            restFollowers: 85,
            restFollowing: 18,
            persistedRow: _persistedRow(followers: 100, following: 20),
          );

          final stats = await repository.getFollowerStats(_testPubkey);

          // Hysteresis keeps the persisted count.
          expect(stats.followers, equals(100));
          expect(stats.following, equals(20));
        },
      );

      test('accepts lower count when drop exceeds threshold', () async {
        final apiClient = _MockFunnelcakeApiClient();
        final dao = _MockProfileStatsDao();
        // Persisted: 100 followers. Fresh: 70 (30% drop, exceeds 20% threshold).
        final repository = _createRepository(
          apiClient: apiClient,
          dao: dao,
          restFollowers: 70,
          restFollowing: 10,
          persistedRow: _persistedRow(followers: 100, following: 20),
        );

        final stats = await repository.getFollowerStats(_testPubkey);

        // Drop below threshold (80) → accept fresh count.
        expect(stats.followers, equals(70));
        expect(stats.following, equals(10));
      });

      test('accepts lower count when persisted data is stale', () async {
        final apiClient = _MockFunnelcakeApiClient();
        final dao = _MockProfileStatsDao();
        // Persisted 2 hours ago — stale.
        final staleTimestamp = DateTime.now().subtract(
          const Duration(hours: 2),
        );
        final repository = _createRepository(
          apiClient: apiClient,
          dao: dao,
          restFollowers: 85,
          restFollowing: 18,
          persistedRow: _persistedRow(
            followers: 100,
            following: 20,
            cachedAt: staleTimestamp,
          ),
        );

        final stats = await repository.getFollowerStats(_testPubkey);

        // Stale → accept fresh count even though it's within threshold.
        expect(stats.followers, equals(85));
        expect(stats.following, equals(18));
      });

      test(
        'does not apply hysteresis when no persisted data exists',
        () async {
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
        },
      );

      test('boundary: fresh count exactly at threshold is kept', () async {
        final apiClient = _MockFunnelcakeApiClient();
        final dao = _MockProfileStatsDao();
        // Persisted: 100. Threshold = ceil(100 * 0.8) = 80.
        // Fresh: 80 → exactly at threshold → keep persisted.
        final repository = _createRepository(
          apiClient: apiClient,
          dao: dao,
          restFollowers: 80,
          restFollowing: 20,
          persistedRow: _persistedRow(followers: 100, following: 25),
        );

        final stats = await repository.getFollowerStats(_testPubkey);

        expect(stats.followers, equals(100));
        expect(stats.following, equals(25));
      });

      test('boundary: fresh count one below threshold is accepted', () async {
        final apiClient = _MockFunnelcakeApiClient();
        final dao = _MockProfileStatsDao();
        // Persisted: 100. Threshold = ceil(100 * 0.8) = 80.
        // Fresh: 79 → below threshold → accept fresh.
        final repository = _createRepository(
          apiClient: apiClient,
          dao: dao,
          restFollowers: 79,
          restFollowing: 20,
          persistedRow: _persistedRow(followers: 100, following: 25),
        );

        final stats = await repository.getFollowerStats(_testPubkey);

        expect(stats.followers, equals(79));
      });

      test(
        'does not re-persist when hysteresis keeps old value',
        () async {
          final apiClient = _MockFunnelcakeApiClient();
          final dao = _MockProfileStatsDao();
          // Persisted: 100 followers, recent timestamp.
          final repository = _createRepository(
            apiClient: apiClient,
            dao: dao,
            restFollowers: 90,
            restFollowing: 20,
            persistedRow: _persistedRow(followers: 100, following: 20),
          );

          await repository.getFollowerStats(_testPubkey);

          // Hysteresis kept 100/20 which matches persisted.
          // upsertStats should NOT have been called since value didn't change.
          verifyNever(
            () => dao.upsertStats(
              pubkey: any(named: 'pubkey'),
              followerCount: any(named: 'followerCount'),
              followingCount: any(named: 'followingCount'),
            ),
          );
        },
      );
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
