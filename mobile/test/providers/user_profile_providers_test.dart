// ABOUTME: Tests for user profile Riverpod providers.
// ABOUTME: Stats self-seed from cache and decouple from nostrReady (#5863).

import 'dart:async';

import 'package:db_client/db_client.dart' hide ProfileStats;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:openvine/providers/curation_providers.dart';
import 'package:openvine/providers/database_provider.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/providers/repository_providers.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:profile_repository/profile_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockProfileRepository extends Mock implements ProfileRepository {}

class _MockNostrClient extends Mock implements NostrClient {}

class _MockAppDatabase extends Mock implements AppDatabase {}

class _MockUserProfilesDao extends Mock implements UserProfilesDao {}

class _MockProfileStatsDao extends Mock implements ProfileStatsDao {}

class _TestNostrSession extends NostrSession {
  _TestNostrSession(this._readiness);

  final NostrSessionReadiness _readiness;

  @override
  NostrSessionReadiness build() => _readiness;
}

void main() {
  const pubkey =
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

  group('userProfileStatsReactiveProvider', () {
    late _MockProfileRepository profileRepository;
    late StreamController<ProfileStats?> statsController;
    late ProviderContainer container;

    setUp(() {
      profileRepository = _MockProfileRepository();
      statsController = StreamController<ProfileStats?>();
      container = ProviderContainer(
        overrides: [
          // #5863: counts now source from the identity-known-gated stats repo.
          profileStatsRepositoryProvider.overrideWithValue(profileRepository),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(statsController.close);

      when(
        () => profileRepository.watchProfileStats(pubkey: pubkey),
      ).thenAnswer((_) => statsController.stream);
      when(
        () => profileRepository.fetchFreshProfile(pubkey: pubkey),
      ).thenAnswer((_) async => null);
    });

    test('fetches a fresh profile as soon as stats are watched', () async {
      final emitted = <AsyncValue<ProfileStats?>>[];
      final sub = container.listen(
        userProfileStatsReactiveProvider(pubkey),
        (_, next) => emitted.add(next),
        fireImmediately: true,
      );
      addTearDown(sub.close);

      await Future<void>.delayed(Duration.zero);

      verify(
        () => profileRepository.fetchFreshProfile(pubkey: pubkey),
      ).called(1);

      statsController.add(null);
      await Future<void>.delayed(Duration.zero);

      const stats = ProfileStats(
        pubkey: pubkey,
        followers: 12,
        following: 34,
        totalLikes: 56,
        totalViews: 78,
      );
      statsController.add(stats);
      await Future<void>.delayed(Duration.zero);

      expect(emitted.last.value, stats);
    });

    test(
      'does not refetch active counts when stats repo stays stable',
      () async {
        var fetchCount = 0;
        final nostrClient = _MockNostrClient();
        when(
          () => profileRepository.fetchFreshProfile(pubkey: pubkey),
        ).thenAnswer((_) async {
          fetchCount++;
          return null;
        });

        final streamContainer = ProviderContainer(
          overrides: [
            nostrSessionProvider.overrideWith(
              () => _TestNostrSession(
                const NostrSessionReadiness.identityKnown(pubkey: pubkey),
              ),
            ),
            profileStatsRepositoryProvider.overrideWith((ref) {
              final identityPubkey = ref.watch(
                nostrSessionProvider.select((readiness) {
                  if (readiness.phase == NostrSessionPhase.identityKnown ||
                      readiness.phase == NostrSessionPhase.nostrReady) {
                    return readiness.pubkey;
                  }
                  return null;
                }),
              );
              return identityPubkey == null ? null : profileRepository;
            }),
          ],
        );
        addTearDown(streamContainer.dispose);

        final sub = streamContainer.listen(
          userProfileStatsReactiveProvider(pubkey),
          (_, _) {},
          fireImmediately: true,
        );
        addTearDown(sub.close);

        await Future<void>.delayed(Duration.zero);
        expect(fetchCount, 1);

        streamContainer
            .read(nostrSessionProvider.notifier)
            .update(
              NostrSessionReadiness.nostrReady(
                pubkey: pubkey,
                client: nostrClient,
              ),
            );
        await Future<void>.delayed(Duration.zero);

        expect(fetchCount, 1);
      },
    );
  });

  group('profileStatsRepository gating (#5863)', () {
    ProviderContainer containerWith(NostrSessionReadiness readiness) {
      final container = ProviderContainer(
        overrides: [
          nostrSessionProvider.overrideWith(() => _TestNostrSession(readiness)),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('is null when signed out', () {
      final container = containerWith(
        const NostrSessionReadiness.signedOut(),
      );
      expect(container.read(profileStatsRepositoryProvider), isNull);
    });

    test(
      'the relay-backed profileRepository stays null at identity-known, which '
      'is exactly the window the stats repo unblocks',
      () {
        final container = containerWith(
          const NostrSessionReadiness.identityKnown(pubkey: pubkey),
        );
        // The nostrReady gate is not satisfied at identity-known, so the
        // relay-backed repo (and its counts) are still null here — the bug the
        // identity-known-gated stats repo fixes by rendering counts earlier.
        expect(container.read(profileRepositoryProvider), isNull);
      },
    );

    test(
      'preserves the stats repository instance from identity-known to '
      'nostrReady for the same pubkey',
      () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final nostrClient = _MockNostrClient();
        final database = _MockAppDatabase();
        final userProfilesDao = _MockUserProfilesDao();
        final profileStatsDao = _MockProfileStatsDao();
        final funnelcakeClient = FunnelcakeApiClient(
          baseUrl: 'https://api.divine.video',
        );

        when(() => database.userProfilesDao).thenReturn(userProfilesDao);
        when(() => database.profileStatsDao).thenReturn(profileStatsDao);

        final container = ProviderContainer(
          overrides: [
            nostrSessionProvider.overrideWith(
              () => _TestNostrSession(
                const NostrSessionReadiness.identityKnown(pubkey: pubkey),
              ),
            ),
            nostrServiceProvider.overrideWithValue(nostrClient),
            databaseProvider.overrideWithValue(database),
            sharedPreferencesProvider.overrideWithValue(prefs),
            funnelcakeApiClientProvider.overrideWithValue(funnelcakeClient),
          ],
        );
        addTearDown(container.dispose);

        final identityKnownRepo = container.read(
          profileStatsRepositoryProvider,
        );
        expect(identityKnownRepo, isNotNull);

        container
            .read(nostrSessionProvider.notifier)
            .update(
              NostrSessionReadiness.nostrReady(
                pubkey: pubkey,
                client: nostrClient,
              ),
            );

        final nostrReadyRepo = container.read(profileStatsRepositoryProvider);
        expect(identical(identityKnownRepo, nostrReadyRepo), isTrue);
      },
    );
  });
}
