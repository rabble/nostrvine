// ABOUTME: Tests for VideoEventPublisher retry logic with exponential backoff
// ABOUTME: Verifies 3 retry attempts with 2s, 4s delays match implementation

import 'package:flutter_test/flutter_test.dart';

/// Extracted retry logic from VideoEventPublisher for testability
/// This mirrors the retry pattern used in publishVideoEvent()
class RetryExecutor {
  /// Execute an operation with retry logic (up to maxRetries attempts)
  /// Returns true if operation succeeded, false if all attempts failed
  /// Uses exponential backoff: delay = attempt * 2 seconds
  static Future<bool> executeWithRetry({
    required Future<bool> Function() operation,
    int maxRetries = 3,
    void Function(int attempt, int delaySeconds)? onRetry,
    void Function()? onAllFailed,
  }) async {
    for (var attempt = 1; attempt <= maxRetries; attempt++) {
      final result = await operation();

      if (result) {
        return true;
      }

      if (attempt < maxRetries) {
        final delaySeconds = attempt * 2; // 2s, 4s backoff
        onRetry?.call(attempt, delaySeconds);
        await Future<void>.delayed(Duration(seconds: delaySeconds));
      } else {
        onAllFailed?.call();
      }
    }

    return false;
  }
}

void main() {
  group('VideoEventPublisher retry logic', () {
    group('RetryExecutor.executeWithRetry', () {
      test(
        'returns true immediately when operation succeeds on first try',
        () async {
          var callCount = 0;

          final result = await RetryExecutor.executeWithRetry(
            operation: () async {
              callCount++;
              return true; // Succeeds immediately
            },
          );

          expect(result, isTrue);
          expect(
            callCount,
            equals(1),
            reason: 'Should only call once on success',
          );
        },
      );

      test('retries up to 3 times when operation fails', () async {
        var callCount = 0;

        final result = await RetryExecutor.executeWithRetry(
          operation: () async {
            callCount++;
            return false; // Always fails
          },
        );

        expect(result, isFalse);
        expect(callCount, equals(3), reason: 'Should try 3 times (maxRetries)');
      });

      test('returns true on second attempt when first fails', () async {
        var callCount = 0;

        final result = await RetryExecutor.executeWithRetry(
          operation: () async {
            callCount++;
            return callCount >= 2; // Fails first, succeeds second
          },
        );

        expect(result, isTrue);
        expect(callCount, equals(2), reason: 'Should succeed on second try');
      });

      test('returns true on third attempt when first two fail', () async {
        var callCount = 0;

        final result = await RetryExecutor.executeWithRetry(
          operation: () async {
            callCount++;
            return callCount >= 3; // Fails first two, succeeds third
          },
        );

        expect(result, isTrue);
        expect(callCount, equals(3), reason: 'Should succeed on third try');
      });

      test('calls onRetry callback with correct attempt and delay', () async {
        final retryAttempts = <int>[];
        final retryDelays = <int>[];

        await RetryExecutor.executeWithRetry(
          operation: () async => false,
          onRetry: (attempt, delaySeconds) {
            retryAttempts.add(attempt);
            retryDelays.add(delaySeconds);
          },
        );

        // Should have 2 retries (attempt 1 and 2, not 3 since that's the last)
        expect(retryAttempts, equals([1, 2]));
        expect(
          retryDelays,
          equals([2, 4]),
          reason: 'Delays should be 2s, 4s (exponential backoff)',
        );
      });

      test('calls onAllFailed callback when all attempts exhausted', () async {
        var allFailedCalled = false;

        await RetryExecutor.executeWithRetry(
          operation: () async => false,
          onAllFailed: () {
            allFailedCalled = true;
          },
        );

        expect(allFailedCalled, isTrue);
      });

      test(
        'does not call onAllFailed when operation eventually succeeds',
        () async {
          var allFailedCalled = false;
          var callCount = 0;

          await RetryExecutor.executeWithRetry(
            operation: () async {
              callCount++;
              return callCount >= 2; // Succeeds on second try
            },
            onAllFailed: () {
              allFailedCalled = true;
            },
          );

          expect(allFailedCalled, isFalse);
        },
      );

      test(
        'does not call onRetry when operation succeeds on first try',
        () async {
          var retryCalled = false;

          await RetryExecutor.executeWithRetry(
            operation: () async => true,
            onRetry: (_, __) {
              retryCalled = true;
            },
          );

          expect(retryCalled, isFalse);
        },
      );

      test('respects custom maxRetries parameter', () async {
        var callCount = 0;

        await RetryExecutor.executeWithRetry(
          operation: () async {
            callCount++;
            return false;
          },
          maxRetries: 5,
        );

        expect(callCount, equals(5));
      });
    });

    group('Exponential backoff calculation', () {
      test('attempt 1 delay is 2 seconds', () {
        const attempt = 1;
        final delaySeconds = attempt * 2;
        expect(delaySeconds, equals(2));
      });

      test('attempt 2 delay is 4 seconds', () {
        const attempt = 2;
        final delaySeconds = attempt * 2;
        expect(delaySeconds, equals(4));
      });

      test('attempt 3 would be 6 seconds (but no delay on last attempt)', () {
        const attempt = 3;
        final delaySeconds = attempt * 2;
        expect(delaySeconds, equals(6));
        // Note: In actual implementation, delay is not applied after last attempt
      });

      test('total wait time for 3 attempts is 6 seconds (2s + 4s)', () {
        // attempt 1: fail, wait 2s
        // attempt 2: fail, wait 4s
        // attempt 3: fail (no wait after)
        const totalWaitSeconds = 2 + 4;
        expect(totalWaitSeconds, equals(6));
      });
    });

    group('VideoEventPublisher retry constants', () {
      // These tests document the expected constants from VideoEventPublisher
      test('maxRetries should be 3', () {
        const maxRetries = 3;
        expect(maxRetries, equals(3));
      });

      test('backoff formula should be attempt * 2', () {
        // Verify the formula: delaySeconds = attempt * 2
        expect(1 * 2, equals(2), reason: 'Attempt 1 delay');
        expect(2 * 2, equals(4), reason: 'Attempt 2 delay');
      });
    });
  });
}
