// ABOUTME: Tests for NotificationsPage — verifies route constants and that
// ABOUTME: the page forwards bloc construction + initial-load events to the
// ABOUTME: repository, which in turn drives the badge cubit's stream.

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

      testWidgets('calls repository.markAllAsRead() after refresh succeeds', (
        tester,
      ) async {
        await tester.pumpWidget(buildSubject());
        await tester.pumpAndSettle();

        verifyInOrder([
          () => mockNotificationRepo.refresh(),
          () => mockNotificationRepo.markAllAsRead(),
        ]);
      });
    });
  });
}
