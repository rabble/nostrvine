// ABOUTME: Tests for throttledListen / _ThrottledSubscription — rate-limiting
// ABOUTME: behavior, cancel-cleans-up-timer invariant, and onError tear-down
// ABOUTME: to guard against Timer.periodic leaks per sheet open/close cycle.

import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/blocs/comments/comments_list/throttled_subscription.dart';

void main() {
  group('throttledListen', () {
    test('emits up to maxPerSecond events in a single second window', () {
      fakeAsync((fake) {
        final received = <int>[];
        final source = StreamController<int>.broadcast();

        final sub = throttledListen<int>(
          source.stream,
          maxPerSecond: 3,
          onData: received.add,
        );

        // Burst of 7 within the same second.
        for (var i = 1; i <= 7; i++) {
          source.add(i);
        }
        fake.flushMicrotasks();

        expect(received, [1, 2, 3]);

        sub.cancel();
        source.close();
        fake.flushMicrotasks();
      });
    });

    test('refills budget after one second so subsequent events emit', () {
      fakeAsync((fake) {
        final received = <int>[];
        final source = StreamController<int>.broadcast();

        final sub = throttledListen<int>(
          source.stream,
          maxPerSecond: 2,
          onData: received.add,
        );

        source.add(1);
        source.add(2);
        source.add(3); // dropped — budget exhausted
        fake.flushMicrotasks();
        expect(received, [1, 2]);

        fake.elapse(const Duration(seconds: 1)); // refill
        source.add(4);
        source.add(5);
        fake.flushMicrotasks();
        expect(received, [1, 2, 4, 5]);

        sub.cancel();
        source.close();
        fake.flushMicrotasks();
      });
    });

    test('cancel() also cancels the refill periodic timer (no leak)', () {
      fakeAsync((fake) {
        final source = StreamController<int>.broadcast();
        final sub = throttledListen<int>(
          source.stream,
          maxPerSecond: 5,
          onData: (_) {},
        );

        // periodic refill timer is active.
        expect(fake.periodicTimerCount, 1);

        sub.cancel();
        fake.flushMicrotasks();

        // After cancel, no Timer leak.
        expect(fake.periodicTimerCount, 0);
        source.close();
      });
    });

    test(
      'underlying stream error tears down refill timer even if cancelOnError is the default false',
      () {
        fakeAsync((fake) {
          final received = <Object>[];
          final source = StreamController<int>.broadcast();

          throttledListen<int>(
            source.stream,
            maxPerSecond: 5,
            onData: (_) {},
            onError: received.add,
          );

          expect(fake.periodicTimerCount, 1);

          source.addError(Exception('relay went away'));
          fake.flushMicrotasks();

          // user onError still called
          expect(received, hasLength(1));
          // refill timer torn down on error path
          expect(fake.periodicTimerCount, 0);

          source.close();
        });
      },
    );

    test('onDone also cancels the refill timer', () {
      fakeAsync((fake) {
        final source = StreamController<int>.broadcast();
        throttledListen<int>(
          source.stream,
          maxPerSecond: 5,
          onData: (_) {},
        );

        expect(fake.periodicTimerCount, 1);

        source.close();
        fake.flushMicrotasks();

        expect(fake.periodicTimerCount, 0);
      });
    });
  });
}
