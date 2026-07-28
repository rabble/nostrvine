// ABOUTME: Tests for user profile Riverpod providers.
// ABOUTME: Stats self-seed from cache and decouple from nostrReady (#5863).

import 'dart:async';

import 'package:db_client/db_client.dart' hide ProfileStats;
import 'package:flutter/foundation.dart';
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

class _MockPendingProfileSavesDao extends Mock
    implements PendingProfileSavesDao {}

class _MockIdentityEventsDao extends Mock implements IdentityEventsDao {}

class _MockVanishedProfilesDao extends Mock implements VanishedProfilesDao {}

class _TestNostrSession extends NostrSession {
  _TestNostrSession(this._readiness);

  final NostrSessionReadiness _readiness;

  @override
  NostrSessionReadiness build() => _readiness;
}

void main() {
  const pubkey =
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

  group('userProfileReactiveProvider', () {
    late _MockProfileRepository profileRepository;
    late ProviderContainer container;

    setUp(() {
      profileRepository = _MockProfileRepository();
      container = ProviderContainer(
        overrides: [
          profileRepositoryProvider.overrideWithValue(profileRepository),
        ],
      );
      addTearDown(container.dispose);
    });

    test(
      'does not touch a disposed Ref after immediate invalidation',
      () async {
        when(
          () => profileRepository.getCachedProfile(pubkey: pubkey),
        ).thenAnswer((_) async => null);
        when(
          () => profileRepository.fetchFreshProfile(pubkey: pubkey),
        ).thenAnswer((_) async => null);
        when(
          () => profileRepository.watchProfile(pubkey: pubkey),
        ).thenAnswer((_) => const Stream<UserProfile?>.empty());

        final uncaughtErrors = await _captureUncaughtErrors(() async {
          final sub = container.listen(
            userProfileReactiveProvider(pubkey),
            (_, _) {},
            fireImmediately: true,
          );

          container.invalidate(userProfileReactiveProvider(pubkey));
          sub.close();
          await Future<void>.delayed(Duration.zero);
        });

        expect(uncaughtErrors, isEmpty);
      },
    );

    test('emits cached stream value before live updates', () async {
      final liveController = StreamController<UserProfile?>();
      addTearDown(liveController.close);
      final cachedProfile = _profile(pubkey, name: 'cached');
      final liveProfile = _profile(pubkey, name: 'live');

      when(
        () => profileRepository.getCachedProfile(pubkey: pubkey),
      ).thenAnswer((_) async => cachedProfile);
      when(
        () => profileRepository.watchProfile(pubkey: pubkey),
      ).thenAnswer((_) => liveController.stream);

      final emitted = <AsyncValue<UserProfile?>>[];
      final sub = container.listen(
        userProfileReactiveProvider(pubkey),
        (_, next) => emitted.add(next),
        fireImmediately: true,
      );
      addTearDown(sub.close);

      await untilCalled(
        () => profileRepository.watchProfile(pubkey: pubkey),
      );
      await Future<void>.delayed(Duration.zero);
      liveController.add(cachedProfile);
      await Future<void>.delayed(Duration.zero);
      liveController.add(liveProfile);
      await Future<void>.delayed(Duration.zero);

      expect(emitted.where((value) => value.hasValue).map((v) => v.value), [
        cachedProfile,
        liveProfile,
      ]);
      verifyNever(() => profileRepository.fetchFreshProfile(pubkey: pubkey));
    });

    test('fetches fresh profile once when cache is empty', () async {
      final liveController = StreamController<UserProfile?>();
      addTearDown(liveController.close);

      when(
        () => profileRepository.getCachedProfile(pubkey: pubkey),
      ).thenAnswer((_) async => null);
      when(
        () => profileRepository.fetchFreshProfile(pubkey: pubkey),
      ).thenAnswer((_) async => null);
      when(
        () => profileRepository.watchProfile(pubkey: pubkey),
      ).thenAnswer((_) => liveController.stream);

      final sub = container.listen(
        userProfileReactiveProvider(pubkey),
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(sub.close);

      await Future<void>.delayed(Duration.zero);

      verify(
        () => profileRepository.fetchFreshProfile(pubkey: pubkey),
      ).called(1);
    });

    test('cancels the underlying profile stream when disposed', () async {
      var wasCancelled = false;
      final liveController = StreamController<UserProfile?>(
        onCancel: () {
          wasCancelled = true;
        },
      );
      addTearDown(liveController.close);

      when(
        () => profileRepository.getCachedProfile(pubkey: pubkey),
      ).thenAnswer((_) async => _profile(pubkey));
      when(
        () => profileRepository.watchProfile(pubkey: pubkey),
      ).thenAnswer((_) => liveController.stream);

      final sub = container.listen(
        userProfileReactiveProvider(pubkey),
        (_, _) {},
        fireImmediately: true,
      );

      await Future<void>.delayed(Duration.zero);
      sub.close();
      container.invalidate(userProfileReactiveProvider(pubkey));
      await Future<void>.delayed(Duration.zero);

      expect(wasCancelled, isTrue);
    });

    test('completes safely when profile repository is unavailable', () async {
      final emptyContainer = ProviderContainer(
        overrides: [
          profileRepositoryProvider.overrideWithValue(null),
        ],
      );
      addTearDown(emptyContainer.dispose);

      final emitted = <AsyncValue<UserProfile?>>[];
      final sub = emptyContainer.listen(
        userProfileReactiveProvider(pubkey),
        (_, next) => emitted.add(next),
        fireImmediately: true,
      );
      addTearDown(sub.close);

      await Future<void>.delayed(Duration.zero);

      expect(emitted, isNotEmpty);
      expect(emitted.last, isA<AsyncLoading<UserProfile?>>());
    });
  });

  group('userProfileStatsReactiveProvider lifecycle', () {
    test(
      'does not touch a disposed Ref after immediate invalidation',
      () async {
        final profileRepository = _MockProfileRepository();
        final container = ProviderContainer(
          overrides: [
            profileStatsRepositoryProvider.overrideWithValue(profileRepository),
          ],
        );
        addTearDown(container.dispose);

        when(
          () => profileRepository.fetchFreshProfile(pubkey: pubkey),
        ).thenAnswer((_) async => null);
        when(
          () => profileRepository.watchProfileStats(pubkey: pubkey),
        ).thenAnswer((_) => const Stream<ProfileStats?>.empty());

        final uncaughtErrors = await _captureUncaughtErrors(() async {
          final sub = container.listen(
            userProfileStatsReactiveProvider(pubkey),
            (_, _) {},
            fireImmediately: true,
          );

          container.invalidate(userProfileStatsReactiveProvider(pubkey));
          sub.close();
          await Future<void>.delayed(Duration.zero);
        });

        expect(uncaughtErrors, isEmpty);
      },
    );
  });

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
      sub.close();
      container.invalidate(userProfileStatsReactiveProvider(pubkey));
      await Future<void>.delayed(Duration.zero);
      await statsController.close();
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
        sub.close();
        streamContainer.invalidate(userProfileStatsReactiveProvider(pubkey));
        await Future<void>.delayed(Duration.zero);
        await statsController.close();
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
        final pendingProfileSavesDao = _MockPendingProfileSavesDao();
        final funnelcakeClient = FunnelcakeApiClient(
          baseUrl: 'https://api.divine.video',
        );

        when(() => database.userProfilesDao).thenReturn(userProfilesDao);
        when(() => database.profileStatsDao).thenReturn(profileStatsDao);
        when(
          () => database.pendingProfileSavesDao,
        ).thenReturn(pendingProfileSavesDao);
        when(
          () => database.identityEventsDao,
        ).thenReturn(_MockIdentityEventsDao());
        final vanishedProfilesDao = _MockVanishedProfilesDao();
        // The repository hydrates its vanish set on construction, so this has
        // to resolve or the provider throws before it returns an instance.
        when(vanishedProfilesDao.getAllPubkeys).thenAnswer(
          (_) async => <String>[],
        );
        when(
          () => database.vanishedProfilesDao,
        ).thenReturn(vanishedProfilesDao);

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

UserProfile _profile(String pubkey, {String name = 'profile'}) {
  final eventId = switch (name) {
    'cached' =>
      'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
    'live' =>
      'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc',
    _ => 'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd',
  };

  return UserProfile(
    pubkey: pubkey,
    name: name,
    rawData: {'name': name},
    createdAt: DateTime.utc(2026),
    eventId: eventId,
  );
}

Future<List<Object>> _captureUncaughtErrors(
  Future<void> Function() body,
) async {
  final errors = <Object>[];
  final previousFlutterError = FlutterError.onError;
  FlutterError.onError = (details) {
    errors.add(details.exception);
  };

  try {
    await runZonedGuarded(body, (error, _) {
      errors.add(error);
    });
  } finally {
    FlutterError.onError = previousFlutterError;
  }

  return errors;
}
