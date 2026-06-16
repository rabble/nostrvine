import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/foreground_idle_warmup_coordinator.dart';

void main() {
  group('ForegroundIdleWarmupCoordinator', () {
    late DateTime now;
    late bool isForeground;
    late bool isIdle;
    late List<String> calls;

    ForegroundIdleWarmupCoordinator coordinatorWith(
      List<ForegroundIdleWarmupTask> tasks,
    ) {
      return ForegroundIdleWarmupCoordinator(
        tasks: tasks,
        isForeground: () => isForeground,
        isIdle: () => isIdle,
        now: () => now,
      );
    }

    ForegroundIdleWarmupTask task(
      ForegroundIdleWarmupTaskId id, {
      Duration cooldown = const Duration(minutes: 5),
      Future<void> Function()? run,
    }) {
      return ForegroundIdleWarmupTask(
        id: id,
        cooldown: cooldown,
        run: run ?? () async => calls.add(id.name),
      );
    }

    setUp(() {
      now = DateTime(2026, 6, 17, 12);
      isForeground = true;
      isIdle = true;
      calls = [];
    });

    test('runs eligible warmups when the app is foreground and idle', () async {
      final coordinator = coordinatorWith([
        task(ForegroundIdleWarmupTaskId.forYou),
        task(ForegroundIdleWarmupTaskId.newVideos),
        task(ForegroundIdleWarmupTaskId.popular),
        task(ForegroundIdleWarmupTaskId.notifications),
      ]);

      await coordinator.requestWarmup(
        trigger: ForegroundIdleWarmupTrigger.videoPlaybackSettled,
      );

      expect(calls, [
        'forYou',
        'newVideos',
        'popular',
        'notifications',
      ]);
    });

    test('does not run while the app is backgrounded', () async {
      isForeground = false;
      final coordinator = coordinatorWith([
        task(ForegroundIdleWarmupTaskId.forYou),
      ]);

      await coordinator.requestWarmup(
        trigger: ForegroundIdleWarmupTrigger.videoPlaybackSettled,
      );

      expect(calls, isEmpty);
    });

    test('does not run while the app is not idle', () async {
      isIdle = false;
      final coordinator = coordinatorWith([
        task(ForegroundIdleWarmupTaskId.forYou),
      ]);

      await coordinator.requestWarmup(
        trigger: ForegroundIdleWarmupTrigger.videoPlaybackSettled,
      );

      expect(calls, isEmpty);
    });

    test('coalesces concurrent warmup requests into one serial run', () async {
      final completer = Completer<void>();
      final coordinator = coordinatorWith([
        task(
          ForegroundIdleWarmupTaskId.forYou,
          run: () async {
            calls.add('forYou-start');
            await completer.future;
            calls.add('forYou-end');
          },
        ),
        task(ForegroundIdleWarmupTaskId.popular),
      ]);

      final first = coordinator.requestWarmup(
        trigger: ForegroundIdleWarmupTrigger.videoPlaybackSettled,
      );
      final second = coordinator.requestWarmup(
        trigger: ForegroundIdleWarmupTrigger.periodicIdleCheck,
      );

      expect(identical(first, second), isTrue);
      expect(calls, ['forYou-start']);

      completer.complete();
      await first;

      expect(calls, ['forYou-start', 'forYou-end', 'popular']);
    });

    test('skips tasks inside their cooldown window', () async {
      final coordinator = coordinatorWith([
        task(ForegroundIdleWarmupTaskId.forYou),
      ]);

      await coordinator.requestWarmup(
        trigger: ForegroundIdleWarmupTrigger.videoPlaybackSettled,
      );
      await coordinator.requestWarmup(
        trigger: ForegroundIdleWarmupTrigger.periodicIdleCheck,
      );

      expect(calls, ['forYou']);

      now = now.add(const Duration(minutes: 5, seconds: 1));
      await coordinator.requestWarmup(
        trigger: ForegroundIdleWarmupTrigger.periodicIdleCheck,
      );

      expect(calls, ['forYou', 'forYou']);
    });

    test('failed tasks do not consume cooldown or block later tasks', () async {
      var shouldFail = true;
      final coordinator = coordinatorWith([
        task(
          ForegroundIdleWarmupTaskId.forYou,
          run: () async {
            calls.add('forYou');
            if (shouldFail) {
              throw StateError('network failed');
            }
          },
        ),
        task(ForegroundIdleWarmupTaskId.popular),
      ]);

      await coordinator.requestWarmup(
        trigger: ForegroundIdleWarmupTrigger.videoPlaybackSettled,
      );

      expect(calls, ['forYou', 'popular']);

      shouldFail = false;
      await coordinator.requestWarmup(
        trigger: ForegroundIdleWarmupTrigger.periodicIdleCheck,
      );

      expect(calls, ['forYou', 'popular', 'forYou']);
    });

    test('stops before the next task if the app stops being idle', () async {
      final coordinator = coordinatorWith([
        task(
          ForegroundIdleWarmupTaskId.forYou,
          run: () async {
            calls.add('forYou');
            isIdle = false;
          },
        ),
        task(ForegroundIdleWarmupTaskId.popular),
      ]);

      await coordinator.requestWarmup(
        trigger: ForegroundIdleWarmupTrigger.videoPlaybackSettled,
      );

      expect(calls, ['forYou']);
    });
  });

  group('ForegroundIdleWarmupScheduler', () {
    test('runs an initial warmup after the startup delay', () {
      fakeAsync((async) {
        final triggers = <ForegroundIdleWarmupTrigger>[];
        final scheduler = ForegroundIdleWarmupScheduler(
          requestWarmup: (trigger) {
            triggers.add(trigger);
            return Future<void>.value();
          },
        );

        scheduler.start();
        async.elapse(const Duration(seconds: 9));

        expect(triggers, isEmpty);

        async.elapse(const Duration(seconds: 1));

        expect(triggers, [ForegroundIdleWarmupTrigger.startupSettled]);
        scheduler.stop();
      });
    });

    test('runs periodic warmups after start', () {
      fakeAsync((async) {
        final triggers = <ForegroundIdleWarmupTrigger>[];
        final scheduler = ForegroundIdleWarmupScheduler(
          requestWarmup: (trigger) {
            triggers.add(trigger);
            return Future<void>.value();
          },
        );

        scheduler.start();
        async.elapse(const Duration(seconds: 10));
        async.elapse(const Duration(minutes: 10));

        expect(triggers, [
          ForegroundIdleWarmupTrigger.startupSettled,
          ForegroundIdleWarmupTrigger.periodicIdleCheck,
          ForegroundIdleWarmupTrigger.periodicIdleCheck,
        ]);
        scheduler.stop();
      });
    });

    test('start is idempotent', () {
      fakeAsync((async) {
        final triggers = <ForegroundIdleWarmupTrigger>[];
        final scheduler = ForegroundIdleWarmupScheduler(
          requestWarmup: (trigger) {
            triggers.add(trigger);
            return Future<void>.value();
          },
        );

        scheduler.start();
        scheduler.start();
        async.elapse(const Duration(seconds: 10));

        expect(triggers, [ForegroundIdleWarmupTrigger.startupSettled]);
        scheduler.stop();
      });
    });

    test('stop cancels scheduled warmups', () {
      fakeAsync((async) {
        final triggers = <ForegroundIdleWarmupTrigger>[];
        final scheduler = ForegroundIdleWarmupScheduler(
          requestWarmup: (trigger) {
            triggers.add(trigger);
            return Future<void>.value();
          },
        );

        scheduler.start();
        scheduler.stop();
        async.elapse(const Duration(minutes: 10));

        expect(triggers, isEmpty);
      });
    });
  });
}
