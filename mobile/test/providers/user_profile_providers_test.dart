// ABOUTME: Tests for user profile Riverpod providers.
// ABOUTME: Stats self-seed from cache and decouple from nostrReady (#5863).

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/providers/repository_providers.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:profile_repository/profile_repository.dart';

class _MockProfileRepository extends Mock implements ProfileRepository {}

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
  });
}
