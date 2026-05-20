// ABOUTME: Tests for MarkAllReadOnDispose — verifies that the wrapper fires
// ABOUTME: NotificationRepository.markAllAsRead exactly once when its
// ABOUTME: subtree is unmounted, and swallows any failure from the call.

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:notification_repository/notification_repository.dart';
import 'package:openvine/notifications/widgets/mark_all_read_on_dispose.dart';

class _MockNotificationRepository extends Mock
    implements NotificationRepository {}

void main() {
  group(MarkAllReadOnDispose, () {
    late _MockNotificationRepository repo;

    setUp(() {
      repo = _MockNotificationRepository();
      when(() => repo.markAllAsRead()).thenAnswer((_) async {});
    });

    testWidgets('does not call markAllAsRead while mounted', (tester) async {
      await tester.pumpWidget(
        MarkAllReadOnDispose(
          repository: repo,
          child: const SizedBox.shrink(),
        ),
      );
      await tester.pump();

      verifyNever(() => repo.markAllAsRead());
    });

    testWidgets('calls markAllAsRead exactly once on unmount', (tester) async {
      await tester.pumpWidget(
        MarkAllReadOnDispose(
          repository: repo,
          child: const SizedBox.shrink(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();

      verify(() => repo.markAllAsRead()).called(1);
    });

    testWidgets('swallows errors from markAllAsRead', (tester) async {
      when(
        () => repo.markAllAsRead(),
      ).thenAnswer((_) => Future<void>.error(StateError('offline')));

      await tester.pumpWidget(
        MarkAllReadOnDispose(
          repository: repo,
          child: const SizedBox.shrink(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();

      verify(() => repo.markAllAsRead()).called(1);
      // No unhandled exception should escape — pumpAndSettle would have
      // surfaced it via tester.takeException.
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders the child while mounted', (tester) async {
      const childKey = Key('mark-all-read-child');
      await tester.pumpWidget(
        MarkAllReadOnDispose(
          repository: repo,
          child: const SizedBox.shrink(key: childKey),
        ),
      );

      expect(find.byKey(childKey), findsOneWidget);
    });
  });
}
