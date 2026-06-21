// ABOUTME: Tests for user profile Riverpod providers.
// ABOUTME: Verifies profile stats self-seed when the local cache is empty.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/providers/repository_providers.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:profile_repository/profile_repository.dart';

class _MockProfileRepository extends Mock implements ProfileRepository {}

void main() {
  group('userProfileStatsReactiveProvider', () {
    const pubkey =
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

    late _MockProfileRepository profileRepository;
    late StreamController<ProfileStats?> statsController;
    late ProviderContainer container;

    setUp(() {
      profileRepository = _MockProfileRepository();
      statsController = StreamController<ProfileStats?>();
      container = ProviderContainer(
        overrides: [
          profileRepositoryProvider.overrideWithValue(profileRepository),
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
}
