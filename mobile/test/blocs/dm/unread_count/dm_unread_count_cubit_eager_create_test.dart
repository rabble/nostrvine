// ABOUTME: Widget-level test for the badge cubit's eager-create contract
// ABOUTME: (#6115). The sync widget's ref.listen callbacks context.read the
// ABOUTME: cubit from inside Riverpod notifications; a lazy create started
// ABOUTME: there re-enters itself when its own ref.read flushes another
// ABOUTME: still-dirty provider of the same invalidation wave and throws a
// ABOUTME: Null-cast TypeError. Mirrors main.dart's `lazy: false` wiring.

import 'dart:async';

import 'package:dm_repository/dm_repository.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follow_repository/follow_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/dm/unread_count/dm_unread_count_cubit.dart';
import 'package:openvine/providers/repository_providers.dart';

class _MockDmRepository extends Mock implements DmRepository {}

class _MockFollowRepository extends Mock implements FollowRepository {}

// Full 64-character hex Nostr IDs for test data — never truncate.
const _me = 'a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2';
const _alice =
    'c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4';

DmConversation _unreadAccepted() => DmConversation(
  id: 'accepted-convo',
  participantPubkeys: const [_me, _alice],
  isGroup: false,
  createdAt: 1700000000,
  lastMessageTimestamp: 1700000000,
  isRead: false,
  currentUserHasSent: true,
);

/// Override targets — tests mutate these to flip the repository instances
/// behind the REAL [dmRepositoryProvider] / [followRepositoryProvider], so a
/// single frame can carry a two-provider invalidation wave exactly like the
/// auth-ready rebuild in production.
final _dmSelector = StateProvider<DmRepository>((_) {
  throw StateError('must be overridden');
});
final _followSelector = StateProvider<FollowRepository>((_) {
  throw StateError('must be overridden');
});

int _createCount = 0;
DmUnreadCountCubit? _createdCubit;

/// Mirrors `main.dart`'s `_InboxBadgeRepositorySync`: forwards new repository
/// identities to the existing cubit from inside Riverpod notifications.
class _DmRepositorySync extends ConsumerWidget {
  const _DmRepositorySync({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void sync() {
      context.read<DmUnreadCountCubit>().setRepositories(
        dmRepository: ref.read(dmRepositoryProvider),
        followRepository: ref.read(followRepositoryProvider),
      );
    }

    ref
      ..listen(dmRepositoryProvider, (_, _) => sync())
      ..listen(followRepositoryProvider, (_, _) => sync());
    return child;
  }
}

/// Probe mirroring `main.dart`'s wiring around the badge cubit. The child is
/// deliberately NOT a cubit consumer: in production the crash window is the
/// cold-start stretch before the first bottom-nav/inbox build reads the
/// cubit, so nothing here may trigger the create through a descendant.
class _BadgeProbe extends ConsumerWidget {
  const _BadgeProbe({required this.lazy});

  final bool lazy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return BlocProvider<DmUnreadCountCubit>(
      lazy: lazy,
      create: (_) {
        _createCount += 1;
        return _createdCubit = DmUnreadCountCubit(
          dmRepository: ref.read(dmRepositoryProvider),
          followRepository: ref.read(followRepositoryProvider),
          // These tests assert creation/re-entrancy behaviour, not debounce
          // timing, so disable the coalescing delay for prompt settling.
          recomputeDebounce: Duration.zero,
        );
      },
      child: const _DmRepositorySync(child: SizedBox.shrink()),
    );
  }
}

({
  _MockDmRepository dm,
  StreamController<List<DmConversation>> accepted,
  StreamController<List<DmConversation>> potential,
})
_buildDm() {
  final dm = _MockDmRepository();
  final accepted = StreamController<List<DmConversation>>.broadcast();
  final potential = StreamController<List<DmConversation>>.broadcast();
  when(() => dm.userPubkey).thenReturn(_me);
  when(
    () => dm.userPubkeyStream,
  ).thenAnswer((_) => const Stream<String>.empty());
  when(dm.watchAcceptedConversations).thenAnswer((_) => accepted.stream);
  when(dm.watchPotentialRequests).thenAnswer((_) => potential.stream);
  return (dm: dm, accepted: accepted, potential: potential);
}

_MockFollowRepository _buildFollow() {
  final follow = _MockFollowRepository();
  when(
    () => follow.followingStream,
  ).thenAnswer((_) => const Stream<List<String>>.empty());
  when(() => follow.isFollowing(any())).thenReturn(false);
  return follow;
}

void main() {
  late List<Object> guardedErrors;
  late ProviderContainer container;

  Future<void> pumpProbe(
    WidgetTester tester, {
    required DmRepository dm,
    required FollowRepository follow,
    required bool lazy,
  }) async {
    // Production creates its container inside runZonedGuarded (main.dart), so
    // guarded Riverpod listener errors route to the zone handler captured at
    // construction. Mirroring that wiring lets the tests assert both "no
    // error" (fixed path) and the exact Null-cast TypeError (documented lazy
    // path) deterministically.
    runZonedGuarded(
      () {
        container = ProviderContainer(
          overrides: [
            _dmSelector.overrideWith((ref) => dm),
            _followSelector.overrideWith((ref) => follow),
            dmRepositoryProvider.overrideWith(
              (ref) => ref.watch(_dmSelector),
            ),
            followRepositoryProvider.overrideWith(
              (ref) => ref.watch(_followSelector),
            ),
          ],
        );
      },
      (error, stackTrace) => guardedErrors.add(error),
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: _BadgeProbe(lazy: lazy),
      ),
    );
  }

  /// Flips both repository providers in one frame — the production
  /// invalidation wave (all badge repositories watch nostrServiceProvider and
  /// rebuild together on auth-ready / account switch).
  void flipWave({required DmRepository dm, required FollowRepository follow}) {
    container.read(_dmSelector.notifier).state = dm;
    container.read(_followSelector.notifier).state = follow;
  }

  setUp(() {
    guardedErrors = [];
    _createCount = 0;
    // Owned and closed by the BlocProvider that created it — closing it from
    // tearDown would await a subscription cancel outside the test's fake
    // async zone and hang.
    _createdCubit = null;
  });

  group('$DmUnreadCountCubit eager create (#6115)', () {
    testWidgets(
      'is created at mount, before any consumer or provider wave can '
      'trigger a lazy create',
      (tester) async {
        final dmA = _buildDm();
        addTearDown(() async {
          await dmA.accepted.close();
          await dmA.potential.close();
        });

        await pumpProbe(
          tester,
          dm: dmA.dm,
          follow: _buildFollow(),
          lazy: false,
        );

        expect(_createCount, 1);
        expect(guardedErrors, isEmpty);
      },
    );

    testWidgets(
      'a two-provider wave fired before any consumer read re-points the '
      'already-created cubit without re-entering create',
      (tester) async {
        final dmA = _buildDm();
        final dmB = _buildDm();
        addTearDown(() async {
          await dmA.accepted.close();
          await dmA.potential.close();
          await dmB.accepted.close();
          await dmB.potential.close();
        });

        await pumpProbe(
          tester,
          dm: dmA.dm,
          follow: _buildFollow(),
          lazy: false,
        );

        flipWave(dm: dmB.dm, follow: _buildFollow());
        await tester.pump();

        expect(guardedErrors, isEmpty);
        expect(_createCount, 1);

        // The sync listeners forwarded the fresh repositories: the cubit is
        // subscribed to dmB, so an unread conversation there reaches state.
        dmB.accepted.add([_unreadAccepted()]);
        dmB.potential.add(const []);
        await tester.pump(const Duration(milliseconds: 20));
        expect(_createdCubit!.state, 1);
      },
    );

    testWidgets(
      'documents the 1.0.16 crash: with a lazy create the same wave '
      're-enters it and throws the Null cast, then self-heals',
      (tester) async {
        final dmA = _buildDm();
        final dmB = _buildDm();
        addTearDown(() async {
          await dmA.accepted.close();
          await dmA.potential.close();
          await dmB.accepted.close();
          await dmB.potential.close();
        });

        await pumpProbe(
          tester,
          dm: dmA.dm,
          follow: _buildFollow(),
          lazy: true,
        );

        // No consumer below the provider, so the lazy create never ran.
        expect(_createCount, 0);

        flipWave(dm: dmB.dm, follow: _buildFollow());
        await tester.pump();

        // First listener starts the lazy create; create's ref.read flushes
        // the other still-dirty provider, whose notification re-enters
        // context.read<DmUnreadCountCubit>() mid-create: provider's value is
        // still null and the `_value as T` cast throws (#6115).
        expect(guardedErrors, [isA<TypeError>()]);

        // Self-healing (why the crash is non-fatal in production): the outer
        // create completed and the cubit still tracks the fresh repository.
        expect(_createCount, 1);
        dmB.accepted.add([_unreadAccepted()]);
        dmB.potential.add(const []);
        await tester.pump(const Duration(milliseconds: 20));
        expect(_createdCubit!.state, 1);
      },
    );
  });
}
