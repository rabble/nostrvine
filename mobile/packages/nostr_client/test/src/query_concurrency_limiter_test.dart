import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_client/src/query_concurrency_limiter.dart';

void main() {
  group(QueryConcurrencyLimiter, () {
    test('allows up to maxConcurrent acquisitions without waiting', () async {
      final limiter = QueryConcurrencyLimiter(2);

      await limiter.acquire();
      await limiter.acquire();

      expect(limiter.activeCount, 2);
      expect(limiter.waitingCount, 0);
    });

    test(
      'queues acquisitions beyond the cap until a slot is released',
      () async {
        final limiter = QueryConcurrencyLimiter(2);
        await limiter.acquire();
        await limiter.acquire();

        var thirdCompleted = false;
        unawaited(limiter.acquire().then((_) => thirdCompleted = true));

        // The third acquire is parked while the cap is full.
        await Future<void>.delayed(Duration.zero);
        expect(thirdCompleted, isFalse);
        expect(limiter.waitingCount, 1);
        expect(limiter.activeCount, 2);

        // Releasing one slot hands it straight to the waiter.
        limiter.release();
        await Future<void>.delayed(Duration.zero);
        expect(thirdCompleted, isTrue);
        expect(limiter.waitingCount, 0);
        expect(limiter.activeCount, 2);
      },
    );

    test('never exceeds the cap under a burst far larger than it', () async {
      const cap = 3;
      final limiter = QueryConcurrencyLimiter(cap);
      var running = 0;
      var peak = 0;

      Future<void> task() async {
        await limiter.acquire();
        try {
          running++;
          peak = peak > running ? peak : running;
          await Future<void>.delayed(const Duration(milliseconds: 5));
        } finally {
          running--;
          limiter.release();
        }
      }

      await Future.wait([for (var i = 0; i < 30; i++) task()]);

      expect(peak, lessThanOrEqualTo(cap));
      expect(limiter.activeCount, 0);
      expect(limiter.waitingCount, 0);
    });

    test('release with no waiters and no active slots is a no-op', () {
      final limiter = QueryConcurrencyLimiter(1)..release();

      expect(limiter.activeCount, 0);
    });
  });
}
