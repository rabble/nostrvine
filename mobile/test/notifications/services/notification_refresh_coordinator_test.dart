// ABOUTME: Tests for notification refresh coalescing on app resume.
// ABOUTME: Guards cooldown consumption and failure routing semantics.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:notification_repository/notification_repository.dart';
import 'package:openvine/notifications/services/notification_refresh_coordinator.dart';

class _MockNotificationRepository extends Mock
    implements NotificationRepository {}

void main() {
  group(NotificationRefreshCoordinator, () {
    late _MockNotificationRepository repository;
    late DateTime now;
    late List<({Object error, String? reason})> reportedErrors;

    setUp(() {
      repository = _MockNotificationRepository();
      now = DateTime.utc(2026, 6, 9, 12);
      reportedErrors = [];
      when(
        () => repository.refresh(),
      ).thenAnswer((_) async => NotificationPage.empty);
      when(() => repository.isClosed).thenReturn(false);
    });

    NotificationRefreshCoordinator buildCoordinator({
      Duration cooldown = const Duration(seconds: 30),
    }) {
      return NotificationRefreshCoordinator(
        repository: repository,
        cooldown: cooldown,
        now: () => now,
        errorReporter: (error, stackTrace, {reason}) =>
            reportedErrors.add((error: error, reason: reason)),
      );
    }

    test('coalesces concurrent refresh requests', () async {
      final completer = Completer<NotificationPage>();
      when(() => repository.refresh()).thenAnswer((_) => completer.future);
      final coordinator = buildCoordinator();

      final first = coordinator.refresh(
        reason: NotificationRefreshReason.appResume,
      );
      final second = coordinator.refresh(
        reason: NotificationRefreshReason.appResume,
      );

      verify(() => repository.refresh()).called(1);
      completer.complete(NotificationPage.empty);
      await Future.wait([first, second]);
    });

    test('skips refreshes inside cooldown window', () async {
      final coordinator = buildCoordinator();

      await coordinator.refresh(reason: NotificationRefreshReason.appResume);
      now = now.add(const Duration(seconds: 10));
      await coordinator.refresh(reason: NotificationRefreshReason.appResume);

      verify(() => repository.refresh()).called(1);
    });

    test('allows refresh after cooldown window', () async {
      final coordinator = buildCoordinator();

      await coordinator.refresh(reason: NotificationRefreshReason.appResume);
      now = now.add(const Duration(seconds: 31));
      await coordinator.refresh(reason: NotificationRefreshReason.appResume);

      verify(() => repository.refresh()).called(2);
    });

    test('failed refresh does not consume the cooldown', () async {
      when(() => repository.refresh()).thenThrow(Exception('timeout'));
      final coordinator = buildCoordinator();

      await coordinator.refresh(reason: NotificationRefreshReason.appResume);
      now = now.add(const Duration(seconds: 1));
      when(
        () => repository.refresh(),
      ).thenAnswer((_) async => NotificationPage.empty);
      await coordinator.refresh(reason: NotificationRefreshReason.appResume);

      verify(() => repository.refresh()).called(2);
    });

    test('successful refresh after a failure restores the cooldown', () async {
      when(() => repository.refresh()).thenThrow(Exception('timeout'));
      final coordinator = buildCoordinator();

      await coordinator.refresh(reason: NotificationRefreshReason.appResume);
      when(
        () => repository.refresh(),
      ).thenAnswer((_) async => NotificationPage.empty);
      await coordinator.refresh(reason: NotificationRefreshReason.appResume);
      now = now.add(const Duration(seconds: 10));
      await coordinator.refresh(reason: NotificationRefreshReason.appResume);

      verify(() => repository.refresh()).called(2);
    });

    test('$Exception failure is not reported to the crash reporter', () async {
      when(() => repository.refresh()).thenThrow(Exception('timeout'));
      final coordinator = buildCoordinator();

      await coordinator.refresh(reason: NotificationRefreshReason.appResume);

      expect(reportedErrors, isEmpty);
    });

    test('$Error failure is reported to the crash reporter', () async {
      final error = StateError('invariant violated');
      when(() => repository.refresh()).thenThrow(error);
      final coordinator = buildCoordinator();

      await coordinator.refresh(reason: NotificationRefreshReason.appResume);

      expect(reportedErrors, hasLength(1));
      expect(reportedErrors.single.error, same(error));
      expect(
        reportedErrors.single.reason,
        equals('NotificationRefreshCoordinator.appResume'),
      );
    });

    test('closed-repository $StateError is not reported', () async {
      when(() => repository.refresh()).thenThrow(
        StateError('You cannot add new events after calling close'),
      );
      when(() => repository.isClosed).thenReturn(true);
      final coordinator = buildCoordinator();

      await coordinator.refresh(reason: NotificationRefreshReason.appResume);

      expect(reportedErrors, isEmpty);
    });
  });
}
