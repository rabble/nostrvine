import 'package:divine_video_player/divine_video_player.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:infinite_video_feed/src/services/load_watchdog.dart';

import '../../helpers/fake_controller.dart';

LoadWatchdog _makeWatchdog({
  required List<int> firedIndices,
  Duration threshold = const Duration(seconds: 3),
  List<String>? logs,
}) => LoadWatchdog(
  threshold: threshold,
  onSlowLoad: firedIndices.add,
  log: (msg) => logs?.add(msg),
);

void main() {
  group(LoadWatchdog, () {
    group('start with null controller', () {
      test('does nothing — no timer is started', () {
        fakeAsync((async) {
          final fired = <int>[];
          final watchdog = _makeWatchdog(firedIndices: fired)..start(0, null);
          async.elapse(const Duration(seconds: 10));

          expect(fired, isEmpty);
          watchdog.disposeAll();
        });
      });
    });

    group('start with a buffering controller', () {
      test('fires onSlowLoad after threshold elapses', () async {
        final fired = <int>[];
        final controller = FakeController()
          ..pushState(
            const DivineVideoPlayerState(status: PlaybackStatus.buffering),
          );
        final watchdog = _makeWatchdog(
          threshold: const Duration(milliseconds: 50),
          firedIndices: fired,
        )..start(3, controller);

        await Future<void>.delayed(const Duration(milliseconds: 1200));

        expect(fired, equals([3]));
        watchdog.disposeAll();
      });

      test('does not fire before threshold', () {
        fakeAsync((async) {
          final fired = <int>[];
          final controller = FakeController()
            ..pushState(
              const DivineVideoPlayerState(status: PlaybackStatus.buffering),
            );
          final watchdog = _makeWatchdog(
            threshold: const Duration(seconds: 5),
            firedIndices: fired,
          )..start(0, controller);
          async.elapse(const Duration(seconds: 4));

          expect(fired, isEmpty);
          watchdog.disposeAll();
        });
      });

      test('auto-stops when controller leaves buffering state', () {
        fakeAsync((async) {
          final fired = <int>[];
          final controller = FakeController()
            ..pushState(
              const DivineVideoPlayerState(status: PlaybackStatus.buffering),
            );
          final watchdog = _makeWatchdog(
            threshold: const Duration(seconds: 2),
            firedIndices: fired,
          )..start(0, controller);
          async.elapse(const Duration(seconds: 1));

          // Controller becomes playing → watchdog stops itself.
          controller.pushState(
            const DivineVideoPlayerState(status: PlaybackStatus.playing),
          );
          async.elapse(const Duration(seconds: 5));

          expect(fired, isEmpty);
          watchdog.disposeAll();
        });
      });
    });

    group('start restarts the timer for the same index', () {
      test('restarting resets the elapsed time', () {
        fakeAsync((async) {
          final fired = <int>[];
          final controller = FakeController()
            ..pushState(
              const DivineVideoPlayerState(status: PlaybackStatus.buffering),
            );
          final watchdog = _makeWatchdog(
            firedIndices: fired,
          )..start(0, controller);
          async.elapse(const Duration(seconds: 2));

          // Restart: elapsed clock resets.
          watchdog.start(0, controller);
          async.elapse(const Duration(seconds: 2));

          // Not enough time after restart → should not have fired.
          expect(fired, isEmpty);
          watchdog.disposeAll();
        });
      });
    });

    group('stop', () {
      test('cancels an active watchdog for the index', () {
        fakeAsync((async) {
          final fired = <int>[];
          final controller = FakeController()
            ..pushState(
              const DivineVideoPlayerState(status: PlaybackStatus.buffering),
            );
          final watchdog = _makeWatchdog(
            threshold: const Duration(seconds: 2),
            firedIndices: fired,
          )..start(0, controller);
          async.elapse(const Duration(seconds: 1));
          watchdog.stop(0);
          async.elapse(const Duration(seconds: 5));

          expect(fired, isEmpty);
          watchdog.disposeAll();
        });
      });
    });

    group('disposeAll', () {
      test('cancels all active watchdogs', () {
        fakeAsync((async) {
          final fired = <int>[];
          final c0 = FakeController()
            ..pushState(
              const DivineVideoPlayerState(status: PlaybackStatus.buffering),
            );
          final c1 = FakeController()
            ..pushState(
              const DivineVideoPlayerState(),
            );
          final watchdog =
              _makeWatchdog(
                  threshold: const Duration(seconds: 2),
                  firedIndices: fired,
                )
                ..start(0, c0)
                ..start(1, c1);

          async.elapse(const Duration(seconds: 1));
          watchdog.disposeAll();
          async.elapse(const Duration(seconds: 5));

          expect(fired, isEmpty);
        });
      });
    });
  });
}
