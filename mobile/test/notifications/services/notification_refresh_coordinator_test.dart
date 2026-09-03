// ABOUTME: Tests for notification refresh coalescing on app resume.
// ABOUTME: Guards cooldown consumption and failure routing semantics.

import 'dart:async';

import 'package:fake_async/fake_async.dart';
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
      Duration pushDebounce = const Duration(seconds: 3),
    }) {
      return NotificationRefreshCoordinator(
        repository: repository,
        cooldown: cooldown,
        pushDebounce: pushDebounce,
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

    group('foreground push refresh', () {
      test('trailing-debounces a burst into one refresh', () {
        fakeAsync((async) {
          final coordinator = buildCoordinator();

          coordinator.schedulePushRefresh();
          async.elapse(const Duration(seconds: 1));
          coordinator.schedulePushRefresh();
          async.elapse(const Duration(seconds: 1));
          coordinator.schedulePushRefresh();

          async.elapse(const Duration(milliseconds: 2999));
          verifyNever(() => repository.refreshApplied());

          async.elapse(const Duration(milliseconds: 1));
          async.flushMicrotasks();
          verify(() => repository.refreshApplied()).called(1);
        });
      });

      test('preserves the deep-pagination guard', () {
        fakeAsync((async) {
          when(() => repository.hasPaginatedBeyondFirstPage).thenReturn(true);
          final coordinator = buildCoordinator();

          coordinator.schedulePushRefresh();
          async.elapse(const Duration(seconds: 3));
          async.flushMicrotasks();

          verifyNever(() => repository.refreshApplied());
        });
      });

      test('dispose cancels a pending refresh', () {
        fakeAsync((async) {
          final coordinator = buildCoordinator();

          coordinator.schedulePushRefresh();
          coordinator.dispose();
          async.elapse(const Duration(seconds: 3));
          async.flushMicrotasks();

          verifyNever(() => repository.refreshApplied());
        });
      });

      test('a failed push refresh does not suppress the next burst', () {
        fakeAsync((async) {
          when(
            () => repository.refreshApplied(),
          ).thenThrow(Exception('timeout'));
          final coordinator = buildCoordinator();

          coordinator.schedulePushRefresh();
          async.elapse(const Duration(seconds: 3));
          async.flushMicrotasks();

          when(
            () => repository.refreshApplied(),
          ).thenAnswer((_) async => true);
          coordinator.schedulePushRefresh();
          async.elapse(const Duration(seconds: 3));
          async.flushMicrotasks();

          verify(() => repository.refreshApplied()).called(2);
        });
      });

      test('refreshes after an earlier refresh finishes', () {
        fakeAsync((async) {
          final firstRefresh = Completer<bool>();
          var calls = 0;
          when(() => repository.refreshApplied()).thenAnswer((_) {
            calls += 1;
            return calls == 1 ? firstRefresh.future : Future.value(true);
          });
          final coordinator = buildCoordinator();

          unawaited(
            coordinator.refresh(reason: NotificationRefreshReason.appResume),
          );
          coordinator.schedulePushRefresh();
          async.elapse(const Duration(seconds: 3));
          async.flushMicrotasks();
          expect(calls, 1);

          firstRefresh.complete(true);
          async.flushMicrotasks();
          expect(calls, 2);
        });
      });
    });
  });
}
