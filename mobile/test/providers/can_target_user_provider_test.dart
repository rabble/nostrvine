// ABOUTME: Tests canTargetUserProvider — affordance gating per the
// ABOUTME: content-policy interaction invariant (absence, never explanation).

import 'package:content_blocklist_repository/content_blocklist_repository.dart';
import 'package:content_policy/content_policy.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:openvine/features/feature_flags/services/feature_flag_service.dart';
import 'package:openvine/providers/moderation_providers.dart';

class _MockContentBlocklistRepository extends Mock
    implements ContentBlocklistRepository {}

class _MockFeatureFlagService extends Mock implements FeatureFlagService {}

void main() {
  const me = '0000000000000000000000000000000000000000000000000000000000000001';
  const blocker =
      '0000000000000000000000000000000000000000000000000000000000000002';
  const muter =
      '0000000000000000000000000000000000000000000000000000000000000003';
  const stranger =
      '0000000000000000000000000000000000000000000000000000000000000004';

  setUpAll(() {
    registerFallbackValue(FeatureFlag.contentPolicyV2);
  });

  late _MockContentBlocklistRepository mockBlocklist;
  late _MockFeatureFlagService mockFlags;

  ContentPolicyState stateWith({
    Set<String> blockingUs = const {},
    Set<String> mutingUs = const {},
  }) {
    return ContentPolicyState(
      currentUserPubkey: me,
      mutedPubkeys: const {},
      blockedPubkeys: const {},
      pubkeysBlockingUs: blockingUs,
      pubkeysMutingUs: mutingUs,
    );
  }

  setUp(() {
    mockBlocklist = _MockContentBlocklistRepository();
    mockFlags = _MockFeatureFlagService();

    when(() => mockBlocklist.hasBlockedUs(any())).thenReturn(false);
    when(() => mockBlocklist.currentState).thenReturn(stateWith());
    when(() => mockFlags.isEnabled(any())).thenReturn(false);
  });

  ProviderContainer createContainer() {
    final container = ProviderContainer(
      overrides: [
        contentBlocklistRepositoryProvider.overrideWithValue(mockBlocklist),
        featureFlagServiceProvider.overrideWithValue(mockFlags),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('canTargetUserProvider', () {
    group('flag off (legacy behavior)', () {
      test('allows targeting a stranger', () {
        final container = createContainer();
        expect(container.read(canTargetUserProvider(stranger)), isTrue);
      });

      test('hides affordances for a user whose block list names us', () {
        when(() => mockBlocklist.hasBlockedUs(blocker)).thenReturn(true);
        final container = createContainer();
        expect(container.read(canTargetUserProvider(blocker)), isFalse);
      });

      test('does not gate on mute lists (pre-engine behavior preserved)', () {
        when(
          () => mockBlocklist.currentState,
        ).thenReturn(stateWith(mutingUs: {muter}));
        final container = createContainer();
        expect(container.read(canTargetUserProvider(muter)), isTrue);
      });
    });

    group('flag on (content-policy engine)', () {
      setUp(() {
        when(
          () => mockFlags.isEnabled(FeatureFlag.contentPolicyV2),
        ).thenReturn(true);
      });

      test('allows targeting a stranger', () {
        final container = createContainer();
        expect(container.read(canTargetUserProvider(stranger)), isTrue);
      });

      test('hides affordances for a user whose block list names us', () {
        when(
          () => mockBlocklist.currentState,
        ).thenReturn(stateWith(blockingUs: {blocker}));
        final container = createContainer();
        expect(container.read(canTargetUserProvider(blocker)), isFalse);
      });

      test('hides affordances for a user whose mute list names us', () {
        when(
          () => mockBlocklist.currentState,
        ).thenReturn(stateWith(mutingUs: {muter}));
        final container = createContainer();
        expect(container.read(canTargetUserProvider(muter)), isFalse);
      });
    });

    test('re-evaluates when the blocklist version changes', () {
      final container = createContainer();
      expect(container.read(canTargetUserProvider(blocker)), isTrue);

      when(() => mockBlocklist.hasBlockedUs(blocker)).thenReturn(true);
      container.read(blocklistVersionProvider.notifier).increment();

      expect(container.read(canTargetUserProvider(blocker)), isFalse);
    });
  });
}
