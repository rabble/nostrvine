import 'package:cache_sync/src/cache_result.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group(CacheResult, () {
    group('CacheResult.cached', () {
      test('exposes data', () {
        const result = CacheResult.cached(42);
        expect(result.data, equals(42));
      });

      test('isLive is false', () {
        const result = CacheResult.cached('hello');
        expect(result.isLive, isFalse);
      });

      test('isStale is true', () {
        const result = CacheResult.cached('hello');
        expect(result.isStale, isTrue);
      });
    });

    group('CacheResult.live', () {
      test('exposes data', () {
        const result = CacheResult.live(42);
        expect(result.data, equals(42));
      });

      test('isLive is true', () {
        const result = CacheResult.live('hello');
        expect(result.isLive, isTrue);
      });

      test('isStale is false', () {
        const result = CacheResult.live('hello');
        expect(result.isStale, isFalse);
      });
    });

    test('sealed hierarchy covers all subtypes', () {
      const results = <CacheResult<int>>[
        CacheResult.cached(1),
        CacheResult.live(2),
      ];

      for (final result in results) {
        // exhaustive switch — compiles only when all cases are handled
        final label = switch (result) {
          CacheResult(isLive: false) => 'cached',
          CacheResult(isLive: true) => 'live',
        };
        expect(label, isNotEmpty);
      }
    });

    // Equality contract: freshness (isLive) is part of identity.
    // A stale result and a live result carrying the same data are NOT equal —
    // this prevents any deduplication layer (distinct(), Equatable BLoC state)
    // from treating a live refresh as a no-op and leaving an "isRefreshing"
    // overlay stuck.
    group('equality', () {
      test('cached(x) is not equal to live(x) for the same data', () {
        expect(
          const CacheResult.cached(42),
          isNot(equals(const CacheResult.live(42))),
        );
      });

      test('two cached results with equal data are equal', () {
        expect(
          const CacheResult.cached(42),
          equals(const CacheResult.cached(42)),
        );
      });

      test('two live results with equal data are equal', () {
        expect(const CacheResult.live(42), equals(const CacheResult.live(42)));
      });

      test('results with different data are not equal', () {
        expect(
          const CacheResult.cached(1),
          isNot(equals(const CacheResult.cached(2))),
        );
        expect(
          const CacheResult.live(1),
          isNot(equals(const CacheResult.live(2))),
        );
      });

      test('hashCode differs between cached and live for same data', () {
        expect(
          const CacheResult.cached(42).hashCode,
          isNot(equals(const CacheResult.live(42).hashCode)),
        );
      });
    });
  });
}
