import 'package:flutter_test/flutter_test.dart';
import 'package:infinite_video_feed/src/widgets/infinite_video_feed.dart';

void main() {
  group('$InfiniteVideoFeed.autoRetryDelay', () {
    Duration? delay(int attempt, {int maxAttempts = 4}) =>
        InfiniteVideoFeed.autoRetryDelay(
          attempt: attempt,
          maxAttempts: maxAttempts,
          baseDelay: const Duration(seconds: 2),
          maxDelay: const Duration(seconds: 30),
        );

    test('first attempt waits the base delay', () {
      expect(delay(0), equals(const Duration(seconds: 2)));
    });

    test('doubles the delay on each subsequent attempt', () {
      expect(delay(1), equals(const Duration(seconds: 4)));
      expect(delay(2), equals(const Duration(seconds: 8)));
      expect(delay(3), equals(const Duration(seconds: 16)));
    });

    test('caps the backoff at maxDelay', () {
      // attempt 5 would be 2s * 32 = 64s, clamped to the 30s ceiling.
      expect(delay(5, maxAttempts: 10), equals(const Duration(seconds: 30)));
    });

    test('returns null once the attempt budget is exhausted', () {
      expect(delay(4), isNull);
      expect(delay(5), isNull);
    });

    test('returns null immediately when maxAttempts is zero', () {
      expect(delay(0, maxAttempts: 0), isNull);
    });
  });
}
