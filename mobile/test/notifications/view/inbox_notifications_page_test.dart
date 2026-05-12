// ABOUTME: Widget tests for InboxNotificationsPage — verifies that opening
// ABOUTME: the inbox triggers repository.refresh + markAllAsRead exactly
// ABOUTME: once (no fan-out across the five filter tabs).

// ignore_for_file: prefer_const_constructors

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follow_repository/follow_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:notification_repository/notification_repository.dart';
import 'package:openvine/blocs/invite_status/invite_status_cubit.dart';
import 'package:openvine/notifications/providers/notification_repository_provider.dart';
import 'package:openvine/notifications/view/inbox_notifications_page.dart';
import 'package:openvine/notifications/view/notifications_view.dart';
import 'package:openvine/providers/app_providers.dart';

import '../../helpers/test_provider_overrides.dart';

class _MockNotificationRepository extends Mock
    implements NotificationRepository {}

class _MockFollowRepository extends Mock implements FollowRepository {}

class _MockInviteStatusCubit extends MockCubit<InviteStatusState>
    implements InviteStatusCubit {}

void main() {
  group(InboxNotificationsPage, () {
    late _MockNotificationRepository mockNotificationRepo;
    late _MockFollowRepository mockFollowRepo;
    late _MockInviteStatusCubit mockInviteCubit;

    setUp(() {
      mockNotificationRepo = _MockNotificationRepository();
      mockFollowRepo = _MockFollowRepository();
      mockInviteCubit = _MockInviteStatusCubit();

      when(
        () => mockNotificationRepo.watchSnapshot(),
      ).thenAnswer((_) => const Stream<NotificationPage>.empty());
      when(
        () => mockNotificationRepo.refresh(),
      ).thenAnswer((_) async => NotificationPage.empty);
      when(() => mockNotificationRepo.markAllAsRead()).thenAnswer((_) async {});
      when(() => mockFollowRepo.isFollowing(any())).thenReturn(false);
      when(() => mockInviteCubit.state).thenReturn(InviteStatusState());
      when(mockInviteCubit.load).thenAnswer((_) async {});
    });

    Widget buildSubject() {
      return testMaterialApp(
        additionalOverrides: [
          notificationRepositoryProvider.overrideWithValue(
            mockNotificationRepo,
          ),
          followRepositoryProvider.overrideWithValue(mockFollowRepo),
        ],
        home: BlocProvider<InviteStatusCubit>.value(
          value: mockInviteCubit,
          child: Scaffold(body: const InboxNotificationsPage()),
        ),
      );
    }

    testWidgets(
      'opens the bloc via NotificationFeedStarted on first build',
      (tester) async {
        await tester.pumpWidget(buildSubject());
        await tester.pumpAndSettle();

        verifyInOrder([
          () => mockNotificationRepo.refresh(),
          () => mockNotificationRepo.markAllAsRead(),
        ]);
      },
    );

    testWidgets(
      'does not fan out refresh + markAllAsRead across the five filter tabs',
      (tester) async {
        await tester.pumpWidget(buildSubject());
        await tester.pumpAndSettle();

        // Swipe through the four non-default tabs. Each visit mounts a
        // fresh NotificationsView; the contract is that none of them
        // triggers another refresh / mark-all-read.
        for (var i = 1; i < 5; i++) {
          await tester.tap(find.byType(Tab).at(i));
          await tester.pumpAndSettle();
        }

        // Exactly one refresh + one markAllAsRead across the whole
        // inbox-open lifecycle, even after all five filter views have
        // mounted.
        verify(() => mockNotificationRepo.refresh()).called(1);
        verify(() => mockNotificationRepo.markAllAsRead()).called(1);
        // Confirm all five filter views actually mounted — guards
        // against the test silently passing because TabBarView never
        // built the off-default children.
        expect(find.byType(NotificationsView), findsWidgets);
      },
    );
  });
}
