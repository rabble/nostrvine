// ABOUTME: Tests for notification refresh coalescing on app resume.
// ABOUTME: Guards against duplicate authoritative refresh requests.

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

    setUp(() {
      repository = _MockNotificationRepository();
      now = DateTime.utc(2026, 6, 9, 12);
      when(
        () => repository.refresh(),
      ).thenAnswer((_) async => NotificationPage.empty);
    });

    NotificationRefreshCoordinator buildCoordinator({
      Duration cooldown = const Duration(seconds: 30),
    }) {
      return NotificationRefreshCoordinator(
        repository: repository,
        cooldown: cooldown,
        now: () => now,
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
  });
}
