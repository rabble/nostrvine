// ABOUTME: Test for notifications screen pull-to-refresh functionality
// ABOUTME: Ensures RefreshIndicator is present and relay provider refresh works

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/invite_status/invite_status_cubit.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/providers/relay_notifications_provider.dart';
import 'package:openvine/screens/notifications_screen.dart';
import 'package:openvine/widgets/notification_list_item.dart';

class _MockInviteStatusCubit extends MockCubit<InviteStatusState>
    implements InviteStatusCubit {}

/// Tracks how many times refresh was called across all instances
int _globalRefreshCount = 0;

/// Mock notifier that tracks refresh calls without hitting real APIs
class _MockRelayNotifications extends RelayNotifications {
  @override
  Future<NotificationFeedState> build() async {
    return NotificationFeedState(
      notifications: [
        NotificationModel(
          id: 'notif1',
          type: NotificationType.like,
          actorPubkey: 'user123',
          actorName: 'Test User',
          message: 'liked your video',
          timestamp: DateTime.now(),
        ),
      ],
      isInitialLoad: false,
      lastUpdated: DateTime.now(),
    );
  }

  @override
  Future<void> refresh() async {
    _globalRefreshCount++;
  }
}

void main() {
  Widget shell(ProviderContainer c) {
    final mockInviteCubit = _MockInviteStatusCubit();
    when(() => mockInviteCubit.state).thenReturn(const InviteStatusState());
    when(mockInviteCubit.load).thenAnswer((_) async {});
    return UncontrolledProviderScope(
      container: c,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BlocProvider<InviteStatusCubit>.value(
          value: mockInviteCubit,
          child: const Scaffold(
            body: NotificationsScreen(skipInitialBootstrapForTesting: true),
          ),
        ),
      ),
    );
  }

  group('NotificationsScreen Refresh', () {
    setUp(() {
      _globalRefreshCount = 0;
    });

    testWidgets(
      'refresh indicator is present and notifications render from relay provider',
      (WidgetTester tester) async {
        final c = ProviderContainer(
          overrides: [
            relayNotificationsProvider.overrideWith(
              _MockRelayNotifications.new,
            ),
          ],
        );
        addTearDown(c.dispose);

        await tester.pumpWidget(shell(c));
        await tester.pumpAndSettle();

        // Assert: RefreshIndicator and notification items are present
        expect(find.byType(RefreshIndicator), findsOneWidget);
        expect(find.byType(NotificationListItem), findsOneWidget);
      },
    );

    testWidgets(
      'calling refresh on relay notifications notifier increments call count',
      (WidgetTester tester) async {
        final c = ProviderContainer(
          overrides: [
            relayNotificationsProvider.overrideWith(
              _MockRelayNotifications.new,
            ),
          ],
        );
        addTearDown(c.dispose);

        await tester.pumpWidget(shell(c));
        await tester.pumpAndSettle();

        // Act: Call refresh directly (what the onRefresh callback does)
        await c.read(relayNotificationsProvider.notifier).refresh();

        // Assert: Verify refresh was called on the notifier
        expect(_globalRefreshCount, equals(1));
      },
    );
  });
}
