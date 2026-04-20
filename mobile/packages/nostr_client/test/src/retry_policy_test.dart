// ABOUTME: Unit tests for RetryPolicy - exponential backoff with maxDelay cap.

import 'package:nostr_client/nostr_client.dart';
import 'package:test/test.dart';

void main() {
  group(RetryPolicy, () {
    test('delayFor returns baseDelay on the first retry', () {
      const policy = RetryPolicy(
        baseDelay: Duration(seconds: 2),
        maxDelay: Duration(seconds: 30),
      );
      expect(policy.delayFor(1), const Duration(seconds: 2));
    });

    test('delayFor doubles each attempt up to maxDelay', () {
      const policy = RetryPolicy(
        baseDelay: Duration(seconds: 2),
        maxDelay: Duration(seconds: 30),
      );
      expect(policy.delayFor(1), const Duration(seconds: 2));
      expect(policy.delayFor(2), const Duration(seconds: 4));
      expect(policy.delayFor(3), const Duration(seconds: 8));
      expect(policy.delayFor(4), const Duration(seconds: 16));
    });

    test('delayFor caps at maxDelay', () {
      const policy = RetryPolicy(
        baseDelay: Duration(seconds: 2),
        maxDelay: Duration(seconds: 10),
      );
      expect(policy.delayFor(1), const Duration(seconds: 2));
      expect(policy.delayFor(2), const Duration(seconds: 4));
      expect(policy.delayFor(3), const Duration(seconds: 8));
      // 2^3 * 2s = 16s, capped to 10s
      expect(policy.delayFor(4), const Duration(seconds: 10));
      expect(policy.delayFor(10), const Duration(seconds: 10));
    });

    test('defaults are sensible for user-initiated publishes', () {
      const policy = RetryPolicy();
      expect(policy.maxAttempts, 3);
      expect(policy.baseDelay, const Duration(seconds: 2));
      expect(policy.timeoutPerAttempt, const Duration(seconds: 15));
      expect(policy.maxDelay, const Duration(seconds: 30));
    });

    test('assertion rejects maxAttempts < 1', () {
      expect(
        () => RetryPolicy(maxAttempts: 0),
        throwsA(isA<AssertionError>()),
      );
    });
  });
}
