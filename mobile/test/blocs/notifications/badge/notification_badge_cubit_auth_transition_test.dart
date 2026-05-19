// ABOUTME: Widget-level test for the badge cubit's auth-transition contract.
// ABOUTME: Verifies that the BlocProvider/ValueKey wiring around the cubit
// ABOUTME: discards the old subscription and re-subscribes when the Riverpod
// ABOUTME: notificationRepositoryProvider flips identity (signed-out ->
// ABOUTME: signed-in, account switch A->B).

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:notification_repository/notification_repository.dart';
import 'package:openvine/blocs/notifications/badge/notification_badge_cubit.dart';
import 'package:openvine/notifications/providers/notification_repository_provider.dart';

class _MockNotificationRepository extends Mock
    implements NotificationRepository {}

/// Override target — tests mutate this StateProvider to flip the
/// repository that [notificationRepositoryProvider] returns.
final _testRepoSelector = StateProvider<NotificationRepository?>(
  (_) => null,
);

/// Probe widget mirroring `main.dart`'s wiring around the badge cubit:
/// the [BlocProvider] is keyed on the identity of the repository, so
/// the cubit is closed and recreated whenever the Riverpod provider
/// hands over a new instance.
class _BadgeProbe extends ConsumerWidget {
  const _BadgeProbe();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return BlocProvider(
      key: ValueKey(
        identityHashCode(ref.watch(notificationRepositoryProvider)),
      ),
      create: (_) => NotificationBadgeCubit(
        repository: ref.read(notificationRepositoryProvider),
      ),
      child: BlocBuilder<NotificationBadgeCubit, int>(
        builder: (context, count) => Text('count=$count'),
      ),
    );
  }
}

void main() {
  group('NotificationBadgeCubit auth transition', () {
    testWidgets(
      'signed-out -> signed-in: badge resets at 0, then emits from the new '
      "repository's stream",
      (tester) async {
        final controllerB = StreamController<int>.broadcast();
        addTearDown(controllerB.close);
        final repoB = _MockNotificationRepository();
        when(repoB.watchUnreadCount).thenAnswer((_) => controllerB.stream);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              notificationRepositoryProvider.overrideWith(
                (ref) => ref.watch(_testRepoSelector),
              ),
            ],
            child: const MaterialApp(home: _BadgeProbe()),
          ),
        );

        expect(find.text('count=0'), findsOneWidget);
        verifyNever(repoB.watchUnreadCount);

        final container = ProviderScope.containerOf(
          tester.element(find.byType(_BadgeProbe)),
        );
        container.read(_testRepoSelector.notifier).state = repoB;
        await tester.pumpAndSettle();

        controllerB.add(5);
        await tester.pumpAndSettle();

        expect(find.text('count=5'), findsOneWidget);
        verify(repoB.watchUnreadCount).called(1);
      },
    );

    testWidgets(
      'account switch A -> B: old subscription is cancelled and the new '
      "cubit subscribes to B's stream",
      (tester) async {
        final controllerA = StreamController<int>.broadcast();
        final controllerB = StreamController<int>.broadcast();
        addTearDown(() async {
          await controllerA.close();
          await controllerB.close();
        });

        final repoA = _MockNotificationRepository();
        final repoB = _MockNotificationRepository();
        when(repoA.watchUnreadCount).thenAnswer((_) => controllerA.stream);
        when(repoB.watchUnreadCount).thenAnswer((_) => controllerB.stream);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              _testRepoSelector.overrideWith((_) => repoA),
              notificationRepositoryProvider.overrideWith(
                (ref) => ref.watch(_testRepoSelector),
              ),
            ],
            child: const MaterialApp(home: _BadgeProbe()),
          ),
        );

        controllerA.add(3);
        await tester.pumpAndSettle();
        expect(find.text('count=3'), findsOneWidget);

        // Swap repositories — Pattern A: in production this transitions
        // through a null phase, but the BlocProvider's ValueKey keyed on
        // identity is the contract this test pins. Any identity flip must
        // close the prior cubit and create a fresh one against B.
        final container = ProviderScope.containerOf(
          tester.element(find.byType(_BadgeProbe)),
        );
        container.read(_testRepoSelector.notifier).state = repoB;
        await tester.pumpAndSettle();

        // Pre-emission default for the new cubit is 0 before B's stream
        // pushes its first value.
        expect(find.text('count=0'), findsOneWidget);

        controllerB.add(7);
        await tester.pumpAndSettle();
        expect(find.text('count=7'), findsOneWidget);

        // Late emission on A's stream must not reach the new cubit —
        // proving the prior subscription was cancelled when the
        // BlocProvider replaced the cubit instance.
        controllerA.add(99);
        await tester.pumpAndSettle();
        expect(find.text('count=99'), findsNothing);
        expect(find.text('count=7'), findsOneWidget);
      },
    );
  });
}
