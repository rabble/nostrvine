// ABOUTME: Unit tests for SafetySettingsCubit — initial snapshot, the three
// ABOUTME: toggle cascades, labeler add/remove, unblock, and the blocklist
// ABOUTME: stream subscription that drives reactive blocked-user refreshes.

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:content_blocklist_repository/content_blocklist_repository.dart';
import 'package:content_policy/content_policy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follow_repository/follow_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/safety_settings/safety_settings_cubit.dart';
import 'package:openvine/blocs/safety_settings/safety_settings_state.dart';
import 'package:openvine/services/age_verification_service.dart';
import 'package:openvine/services/content_filter_service.dart';
import 'package:openvine/services/divine_host_filter_service.dart';
import 'package:openvine/services/moderation_label_service.dart';
import 'package:openvine/services/video_event_service.dart';

class _MockAgeVerificationService extends Mock
    implements AgeVerificationService {}

class _MockContentFilterService extends Mock implements ContentFilterService {}

class _MockVideoEventService extends Mock implements VideoEventService {}

class _MockDivineHostFilterService extends Mock
    implements DivineHostFilterService {}

class _MockModerationLabelService extends Mock
    implements ModerationLabelService {}

class _MockFollowRepository extends Mock implements FollowRepository {}

class _MockContentBlocklistRepository extends Mock
    implements ContentBlocklistRepository {}

void main() {
  group(SafetySettingsCubit, () {
    late _MockAgeVerificationService ageService;
    late _MockContentFilterService filterService;
    late _MockVideoEventService videoEventService;
    late _MockDivineHostFilterService divineHostFilterService;
    late _MockModerationLabelService moderationLabelService;
    late _MockFollowRepository followRepository;
    late _MockContentBlocklistRepository blocklistRepository;
    late StreamController<ContentPolicyState> blocklistStream;

    setUp(() {
      ageService = _MockAgeVerificationService();
      filterService = _MockContentFilterService();
      videoEventService = _MockVideoEventService();
      divineHostFilterService = _MockDivineHostFilterService();
      moderationLabelService = _MockModerationLabelService();
      followRepository = _MockFollowRepository();
      blocklistRepository = _MockContentBlocklistRepository();
      blocklistStream = StreamController<ContentPolicyState>.broadcast();

      when(ageService.initialize).thenAnswer((_) async {});
      when(() => ageService.isAdultContentVerified).thenReturn(false);
      when(
        () => ageService.setAdultContentVerified(any()),
      ).thenAnswer((_) async {});

      when(filterService.unlockAdultCategories).thenAnswer((_) async {});
      when(filterService.lockAdultCategories).thenAnswer((_) async {});
      when(
        videoEventService.filterAdultContentFromExistingVideos,
      ).thenReturn(0);

      when(
        () => divineHostFilterService.showDivineHostedOnly,
      ).thenReturn(true);
      when(
        () => divineHostFilterService.setShowDivineHostedOnly(any()),
      ).thenAnswer((_) async {});

      when(
        () => moderationLabelService.isFollowingModerationEnabled,
      ).thenReturn(false);
      when(
        () => moderationLabelService.ensureLoaded(),
      ).thenAnswer((_) async {});
      when(() => moderationLabelService.customLabelers).thenReturn(<String>{});
      when(
        () => moderationLabelService.setFollowingModerationEnabled(
          any(),
          followedPubkeys: any(named: 'followedPubkeys'),
        ),
      ).thenAnswer((_) async {});
      when(
        () => moderationLabelService.addLabeler(any()),
      ).thenAnswer((_) async {});
      when(
        () => moderationLabelService.removeLabeler(any()),
      ).thenAnswer((_) async {});

      when(() => followRepository.followingPubkeys).thenReturn(const []);

      when(
        () => blocklistRepository.runtimeBlockedUsers,
      ).thenReturn(<String>{});
      when(
        () => blocklistRepository.stateStream,
      ).thenAnswer((_) => blocklistStream.stream);
      when(
        () => blocklistRepository.unblockUser(any()),
      ).thenAnswer((_) async {});
    });

    tearDown(() async {
      await blocklistStream.close();
    });

    SafetySettingsCubit buildCubit({bool isAdultContentLocked = false}) =>
        SafetySettingsCubit(
          ageVerificationService: ageService,
          contentFilterService: filterService,
          videoEventService: videoEventService,
          divineHostFilterService: divineHostFilterService,
          moderationLabelService: moderationLabelService,
          followRepository: followRepository,
          contentBlocklistRepository: blocklistRepository,
          isAdultContentLocked: isAdultContentLocked,
        );

    blocTest<SafetySettingsCubit, SafetySettingsState>(
      'load() surfaces isAdultContentLocked for a protected minor',
      build: () => buildCubit(isAdultContentLocked: true),
      act: (cubit) => cubit.load(),
      expect: () => [
        isA<SafetySettingsState>().having(
          (s) => s.status,
          'status',
          SafetySettingsStatus.loading,
        ),
        isA<SafetySettingsState>()
            .having((s) => s.status, 'status', SafetySettingsStatus.ready)
            .having((s) => s.isAdultContentLocked, 'locked', true),
      ],
    );

    blocTest<SafetySettingsCubit, SafetySettingsState>(
      'setAgeVerified is a no-op when adult content is locked',
      build: () => buildCubit(isAdultContentLocked: true),
      act: (cubit) => cubit.setAgeVerified(true),
      verify: (_) {
        verifyNever(() => ageService.setAdultContentVerified(true));
      },
    );

    blocTest<SafetySettingsCubit, SafetySettingsState>(
      'load snapshots all settings and emits ready',
      setUp: () {
        when(() => ageService.isAdultContentVerified).thenReturn(true);
        when(
          () => moderationLabelService.isFollowingModerationEnabled,
        ).thenReturn(true);
        when(
          () => divineHostFilterService.showDivineHostedOnly,
        ).thenReturn(false);
        when(
          () => moderationLabelService.customLabelers,
        ).thenReturn({'labeler_a'});
        when(
          () => blocklistRepository.runtimeBlockedUsers,
        ).thenReturn({'blocked_a', 'blocked_b'});
      },
      build: buildCubit,
      act: (cubit) => cubit.load(),
      expect: () => [
        const SafetySettingsState(),
        isA<SafetySettingsState>()
            .having((s) => s.status, 'status', SafetySettingsStatus.ready)
            .having((s) => s.isAgeVerified, 'isAgeVerified', true)
            .having(
              (s) => s.isPeopleIFollowEnabled,
              'isPeopleIFollowEnabled',
              true,
            )
            .having(
              (s) => s.showDivineHostedOnly,
              'showDivineHostedOnly',
              false,
            )
            .having(
              (s) => s.customLabelers,
              'customLabelers',
              {'labeler_a'},
            )
            .having(
              (s) => s.blockedUsers,
              'blockedUsers',
              {'blocked_a', 'blocked_b'},
            ),
      ],
      verify: (_) {
        verify(ageService.initialize).called(1);
        verify(() => moderationLabelService.ensureLoaded()).called(1);
        verifyNever(() => moderationLabelService.initialize());
      },
    );

    blocTest<SafetySettingsCubit, SafetySettingsState>(
      'setAgeVerified(true) unlocks adult categories and emits',
      seed: () => const SafetySettingsState(status: SafetySettingsStatus.ready),
      build: buildCubit,
      act: (cubit) => cubit.setAgeVerified(true),
      expect: () => [
        isA<SafetySettingsState>().having(
          (s) => s.isAgeVerified,
          'isAgeVerified',
          true,
        ),
      ],
      verify: (_) {
        verify(() => ageService.setAdultContentVerified(true)).called(1);
        verify(filterService.unlockAdultCategories).called(1);
        verifyNever(filterService.lockAdultCategories);
        verifyNever(videoEventService.filterAdultContentFromExistingVideos);
      },
    );

    blocTest<SafetySettingsCubit, SafetySettingsState>(
      'setAgeVerified(false) locks adult categories and filters existing feed',
      seed: () => const SafetySettingsState(
        status: SafetySettingsStatus.ready,
        isAgeVerified: true,
      ),
      build: buildCubit,
      act: (cubit) => cubit.setAgeVerified(false),
      expect: () => [
        isA<SafetySettingsState>().having(
          (s) => s.isAgeVerified,
          'isAgeVerified',
          false,
        ),
      ],
      verify: (_) {
        verify(() => ageService.setAdultContentVerified(false)).called(1);
        verify(filterService.lockAdultCategories).called(1);
        verify(
          videoEventService.filterAdultContentFromExistingVideos,
        ).called(1);
        verifyNever(filterService.unlockAdultCategories);
      },
    );

    blocTest<SafetySettingsCubit, SafetySettingsState>(
      'setShowDivineHostedOnly persists and emits',
      seed: () => const SafetySettingsState(status: SafetySettingsStatus.ready),
      build: buildCubit,
      act: (cubit) => cubit.setShowDivineHostedOnly(false),
      expect: () => [
        isA<SafetySettingsState>().having(
          (s) => s.showDivineHostedOnly,
          'showDivineHostedOnly',
          false,
        ),
      ],
      verify: (_) {
        verify(
          () => divineHostFilterService.setShowDivineHostedOnly(false),
        ).called(1);
      },
    );

    blocTest<SafetySettingsCubit, SafetySettingsState>(
      'setPeopleIFollowEnabled passes the current followed-pubkeys list',
      seed: () => const SafetySettingsState(status: SafetySettingsStatus.ready),
      setUp: () {
        when(
          () => followRepository.followingPubkeys,
        ).thenReturn(['follow_a', 'follow_b']);
      },
      build: buildCubit,
      act: (cubit) => cubit.setPeopleIFollowEnabled(true),
      expect: () => [
        isA<SafetySettingsState>().having(
          (s) => s.isPeopleIFollowEnabled,
          'isPeopleIFollowEnabled',
          true,
        ),
      ],
      verify: (_) {
        verify(
          () => moderationLabelService.setFollowingModerationEnabled(
            true,
            followedPubkeys: ['follow_a', 'follow_b'],
          ),
        ).called(1);
      },
    );

    blocTest<SafetySettingsCubit, SafetySettingsState>(
      'addLabeler trims input, converts npub to hex, and re-reads labelers',
      seed: () => const SafetySettingsState(status: SafetySettingsStatus.ready),
      setUp: () {
        // A raw hex pubkey passes through npubToHexOrNull → trimmed input.
        when(
          () => moderationLabelService.customLabelers,
        ).thenReturn({'new_hex_pubkey'});
      },
      build: buildCubit,
      act: (cubit) => cubit.addLabeler('  new_hex_pubkey  '),
      expect: () => [
        isA<SafetySettingsState>().having(
          (s) => s.customLabelers,
          'customLabelers',
          {'new_hex_pubkey'},
        ),
      ],
      verify: (_) {
        verify(
          () => moderationLabelService.addLabeler('new_hex_pubkey'),
        ).called(1);
      },
    );

    blocTest<SafetySettingsCubit, SafetySettingsState>(
      'addLabeler ignores empty input without calling the service',
      seed: () => const SafetySettingsState(status: SafetySettingsStatus.ready),
      build: buildCubit,
      act: (cubit) => cubit.addLabeler('   '),
      expect: () => const <SafetySettingsState>[],
      verify: (_) {
        verifyNever(() => moderationLabelService.addLabeler(any()));
      },
    );

    blocTest<SafetySettingsCubit, SafetySettingsState>(
      'removeLabeler delegates and re-reads labelers',
      seed: () => const SafetySettingsState(
        status: SafetySettingsStatus.ready,
        customLabelers: {'a', 'b'},
      ),
      setUp: () {
        when(() => moderationLabelService.customLabelers).thenReturn({'a'});
      },
      build: buildCubit,
      act: (cubit) => cubit.removeLabeler('b'),
      expect: () => [
        isA<SafetySettingsState>().having(
          (s) => s.customLabelers,
          'customLabelers',
          {'a'},
        ),
      ],
      verify: (_) {
        verify(() => moderationLabelService.removeLabeler('b')).called(1);
      },
    );

    blocTest<SafetySettingsCubit, SafetySettingsState>(
      'unblockUser delegates and re-reads blocked users',
      seed: () => const SafetySettingsState(
        status: SafetySettingsStatus.ready,
        blockedUsers: {'a', 'b'},
      ),
      setUp: () {
        when(
          () => blocklistRepository.runtimeBlockedUsers,
        ).thenReturn({'a'});
      },
      build: buildCubit,
      act: (cubit) => cubit.unblockUser('b'),
      expect: () => [
        isA<SafetySettingsState>().having(
          (s) => s.blockedUsers,
          'blockedUsers',
          {'a'},
        ),
      ],
      verify: (_) {
        verify(() => blocklistRepository.unblockUser('b')).called(1);
      },
    );

    blocTest<SafetySettingsCubit, SafetySettingsState>(
      'blocklist stateStream tick refreshes blockedUsers',
      build: buildCubit,
      act: (cubit) async {
        await cubit.load();
        when(
          () => blocklistRepository.runtimeBlockedUsers,
        ).thenReturn({'newly_blocked'});
        blocklistStream.add(ContentPolicyState.empty());
        await Future<void>.delayed(Duration.zero);
      },
      // Sequence: initial state → loading → ready → stream tick refresh.
      expect: () => [
        const SafetySettingsState(),
        isA<SafetySettingsState>().having(
          (s) => s.status,
          'status',
          SafetySettingsStatus.ready,
        ),
        isA<SafetySettingsState>().having(
          (s) => s.blockedUsers,
          'blockedUsers',
          {'newly_blocked'},
        ),
      ],
    );
  });
}
