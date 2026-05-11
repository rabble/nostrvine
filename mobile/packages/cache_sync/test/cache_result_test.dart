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
  });
}
