// ABOUTME: Tests for NotificationsPage — verifies route constants and that
// ABOUTME: the page forwards bloc construction + initial refresh to the
// ABOUTME: repository without implicitly mutating read state.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follow_repository/follow_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:notification_repository/notification_repository.dart';
import 'package:openvine/notifications/providers/notification_repository_provider.dart';
import 'package:openvine/notifications/view/notifications_page.dart';

import '../../helpers/test_provider_overrides.dart';

class _MockNotificationRepository extends Mock
    implements NotificationRepository {}

class _MockFollowRepository extends Mock implements FollowRepository {}

void main() {
  group(NotificationsPage, () {
    group('route constants', () {
      test('routeName is notifications', () {
        expect(NotificationsPage.routeName, equals('notifications'));
      });

      test('path is /notifications', () {
        expect(NotificationsPage.path, equals('/notifications'));
      });

      test('pathWithIndex includes :index parameter', () {
        expect(
          NotificationsPage.pathWithIndex,
          equals('/notifications/:index'),
        );
      });

      test('pathForIndex with null returns base path', () {
        expect(NotificationsPage.pathForIndex(), equals('/notifications'));
      });

      test('pathForIndex with index returns indexed path', () {
        expect(NotificationsPage.pathForIndex(0), equals('/notifications/0'));
      });

      test('pathForIndex with non-zero index returns correct path', () {
        expect(NotificationsPage.pathForIndex(42), equals('/notifications/42'));
      });
    });

    group('initial load', () {
      late _MockNotificationRepository mockNotificationRepo;
      late _MockFollowRepository mockFollowRepo;

      setUp(() {
        mockNotificationRepo = _MockNotificationRepository();
        mockFollowRepo = _MockFollowRepository();

        when(
          () => mockNotificationRepo.watchSnapshot(),
        ).thenAnswer((_) => const Stream<NotificationPage>.empty());
        when(
          () => mockNotificationRepo.refresh(),
        ).thenAnswer((_) async => NotificationPage.empty);
        when(
          () => mockNotificationRepo.markAllAsRead(),
        ).thenAnswer((_) async {});
        when(() => mockFollowRepo.isFollowing(any())).thenReturn(false);
      });

      Widget buildSubject() {
        return testMaterialApp(
          mockFollowRepository: mockFollowRepo,
          additionalOverrides: [
            notificationRepositoryProvider.overrideWithValue(
              mockNotificationRepo,
            ),
          ],
          home: const NotificationsPage(),
        );
      }

      testWidgets('calls repository.refresh() once on open', (tester) async {
        await tester.pumpWidget(buildSubject());
        await tester.pumpAndSettle();

        verify(() => mockNotificationRepo.refresh()).called(1);
      });

      testWidgets('does not mark notifications read on open', (
        tester,
      ) async {
        await tester.pumpWidget(buildSubject());
        await tester.pumpAndSettle();

        verifyNever(() => mockNotificationRepo.markAllAsRead());
      });

      testWidgets(
        'marks all notifications read when the page is unmounted',
        (tester) async {
          await tester.pumpWidget(buildSubject());
          await tester.pumpAndSettle();
          verifyNever(() => mockNotificationRepo.markAllAsRead());

          // Replace the subtree with an empty widget to trigger dispose
          // on the NotificationsPage (and the wrapping
          // MarkAllReadOnDispose). This is the same lifecycle hook that
          // fires when the user navigates to a different bottom-nav
          // tab — the ShellRoute is not stateful, so leaving the
          // notifications route unmounts the page.
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pumpAndSettle();

          verify(() => mockNotificationRepo.markAllAsRead()).called(1);
        },
      );
    });
  });
}
