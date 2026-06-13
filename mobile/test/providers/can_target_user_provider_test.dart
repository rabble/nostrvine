// ABOUTME: Tests canTargetUserProvider — affordance gating per the
// ABOUTME: content-policy interaction invariant (absence, never explanation).

import 'package:content_blocklist_repository/content_blocklist_repository.dart';
import 'package:content_policy/content_policy.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/providers/moderation_providers.dart';

class _MockContentBlocklistRepository extends Mock
    implements ContentBlocklistRepository {}

void main() {
  const me = '0000000000000000000000000000000000000000000000000000000000000001';
  const blocker =
      '0000000000000000000000000000000000000000000000000000000000000002';
  const muter =
      '0000000000000000000000000000000000000000000000000000000000000003';
  const stranger =
      '0000000000000000000000000000000000000000000000000000000000000004';

  late _MockContentBlocklistRepository mockBlocklist;

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
    when(() => mockBlocklist.currentState).thenReturn(stateWith());
  });

  ProviderContainer createContainer() {
    final container = ProviderContainer(
      overrides: [
        contentBlocklistRepositoryProvider.overrideWithValue(mockBlocklist),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('canTargetUserProvider', () {
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

    test('re-evaluates when the blocklist version changes', () {
      final container = createContainer();
      expect(container.read(canTargetUserProvider(blocker)), isTrue);

      when(
        () => mockBlocklist.currentState,
      ).thenReturn(stateWith(blockingUs: {blocker}));
      container.read(blocklistVersionProvider.notifier).increment();

      expect(container.read(canTargetUserProvider(blocker)), isFalse);
    });
  });
}
