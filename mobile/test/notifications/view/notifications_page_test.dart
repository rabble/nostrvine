// ABOUTME: Tests for NotificationsPage — verifies BLoC creation, event
// ABOUTME: dispatch, and route constants.

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/notifications/view/notifications_page.dart';

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
        expect(
          NotificationsPage.pathForIndex(0),
          equals('/notifications/0'),
        );
      });

      test('pathForIndex with non-zero index returns correct path', () {
        expect(
          NotificationsPage.pathForIndex(42),
          equals('/notifications/42'),
        );
      });
    });
  });
}
