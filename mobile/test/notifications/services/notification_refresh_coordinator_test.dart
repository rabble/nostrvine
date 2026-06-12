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
        () => repository.refreshApplied(),
      ).thenAnswer((_) async => true);
      when(() => repository.isClosed).thenReturn(false);
      when(
        () => repository.hasPaginatedBeyondFirstPage,
      ).thenReturn(false);
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
      final completer = Completer<bool>();
      when(
        () => repository.refreshApplied(),
      ).thenAnswer((_) => completer.future);
      final coordinator = buildCoordinator();

      final first = coordinator.refresh(
        reason: NotificationRefreshReason.appResume,
      );
      final second = coordinator.refresh(
        reason: NotificationRefreshReason.appResume,
      );

      verify(() => repository.refreshApplied()).called(1);
      completer.complete(true);
      await Future.wait([first, second]);
    });

    test('skips refreshes inside cooldown window', () async {
      final coordinator = buildCoordinator();

      await coordinator.refresh(reason: NotificationRefreshReason.appResume);
      now = now.add(const Duration(seconds: 10));
      await coordinator.refresh(reason: NotificationRefreshReason.appResume);

      verify(() => repository.refreshApplied()).called(1);
    });

    test('allows refresh after cooldown window', () async {
      final coordinator = buildCoordinator();

      await coordinator.refresh(reason: NotificationRefreshReason.appResume);
      now = now.add(const Duration(seconds: 31));
      await coordinator.refresh(reason: NotificationRefreshReason.appResume);

      verify(() => repository.refreshApplied()).called(2);
    });

    test('failed refresh does not consume the cooldown', () async {
      when(() => repository.refreshApplied()).thenThrow(Exception('timeout'));
      final coordinator = buildCoordinator();

      await coordinator.refresh(reason: NotificationRefreshReason.appResume);
      now = now.add(const Duration(seconds: 1));
      when(
        () => repository.refreshApplied(),
      ).thenAnswer((_) async => true);
      await coordinator.refresh(reason: NotificationRefreshReason.appResume);

      verify(() => repository.refreshApplied()).called(2);
    });

    test('successful refresh after a failure restores the cooldown', () async {
      when(() => repository.refreshApplied()).thenThrow(Exception('timeout'));
      final coordinator = buildCoordinator();

      await coordinator.refresh(reason: NotificationRefreshReason.appResume);
      when(
        () => repository.refreshApplied(),
      ).thenAnswer((_) async => true);
      await coordinator.refresh(reason: NotificationRefreshReason.appResume);
      now = now.add(const Duration(seconds: 10));
      await coordinator.refresh(reason: NotificationRefreshReason.appResume);

      verify(() => repository.refreshApplied()).called(2);
    });

    test('superseded refresh does not consume the cooldown', () async {
      when(
        () => repository.refreshApplied(),
      ).thenAnswer((_) async => false);
      final coordinator = buildCoordinator();

      await coordinator.refresh(reason: NotificationRefreshReason.appResume);
      now = now.add(const Duration(seconds: 1));
      when(
        () => repository.refreshApplied(),
      ).thenAnswer((_) async => true);
      await coordinator.refresh(reason: NotificationRefreshReason.appResume);

      verify(() => repository.refreshApplied()).called(2);
    });

    test('$Exception failure is not reported to the crash reporter', () async {
      when(() => repository.refreshApplied()).thenThrow(Exception('timeout'));
      final coordinator = buildCoordinator();

      await coordinator.refresh(reason: NotificationRefreshReason.appResume);

      expect(reportedErrors, isEmpty);
    });

    test('$Error failure is reported to the crash reporter', () async {
      final error = StateError('invariant violated');
      when(() => repository.refreshApplied()).thenThrow(error);
      final coordinator = buildCoordinator();

      await coordinator.refresh(reason: NotificationRefreshReason.appResume);

      expect(reportedErrors, hasLength(1));
      expect(reportedErrors.single.error, same(error));
      expect(
        reportedErrors.single.reason,
        equals('NotificationRefreshCoordinator.appResume'),
      );
    });

    test('skips refresh while the snapshot is paginated beyond the first '
        'page', () async {
      when(() => repository.hasPaginatedBeyondFirstPage).thenReturn(true);
      final coordinator = buildCoordinator();

      await coordinator.refresh(reason: NotificationRefreshReason.appResume);

      verifyNever(() => repository.refreshApplied());
    });

    test('closed-repository $StateError is not reported', () async {
      when(() => repository.refreshApplied()).thenThrow(
        StateError('You cannot add new events after calling close'),
      );
      when(() => repository.isClosed).thenReturn(true);
      final coordinator = buildCoordinator();

      await coordinator.refresh(reason: NotificationRefreshReason.appResume);

      expect(reportedErrors, isEmpty);
    });
  });
}
