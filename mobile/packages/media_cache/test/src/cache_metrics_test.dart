import 'package:flutter_test/flutter_test.dart';
import 'package:media_cache/media_cache.dart';

void main() {
  group(CacheMetrics, () {
    late CacheMetrics metrics;

    setUp(() {
      metrics = CacheMetrics();
    });

    test('starts with all counters at zero', () {
      expect(metrics.hits, equals(0));
      expect(metrics.misses, equals(0));
      expect(metrics.prefetchedUsed, equals(0));
      expect(metrics.prefetchedTotal, equals(0));
    });

    group('hitRate', () {
      test('returns 0 when no lookups have been made', () {
        expect(metrics.hitRate, equals(0.0));
      });

      test('returns 1.0 when all lookups are hits', () {
        metrics.hits = 10;
        expect(metrics.hitRate, equals(1.0));
      });

      test('returns 0.0 when all lookups are misses', () {
        metrics.misses = 10;
        expect(metrics.hitRate, equals(0.0));
      });

      test('returns correct ratio for mixed hits and misses', () {
        metrics
          ..hits = 3
          ..misses = 1;
        expect(metrics.hitRate, equals(0.75));
      });

      test('returns 0.5 for equal hits and misses', () {
        metrics
          ..hits = 5
          ..misses = 5;
        expect(metrics.hitRate, equals(0.5));
      });
    });

    group('toMap', () {
      test('exports all metrics', () {
        metrics
          ..hits = 7
          ..misses = 3
          ..prefetchedUsed = 4
          ..prefetchedTotal = 10;

        final map = metrics.toMap();

        expect(map['cache_hits'], equals(7));
        expect(map['cache_misses'], equals(3));
        expect(map['cache_hit_rate'], equals(0.7));
        expect(map['prefetched_used'], equals(4));
        expect(map['prefetched_total'], equals(10));
      });

      test('exports zero values when fresh', () {
        final map = metrics.toMap();

        expect(map['cache_hits'], equals(0));
        expect(map['cache_misses'], equals(0));
        expect(map['cache_hit_rate'], equals(0));
        expect(map['prefetched_used'], equals(0));
        expect(map['prefetched_total'], equals(0));
      });
    });

    group('reset', () {
      test('resets all counters to zero', () {
        metrics
          ..hits = 10
          ..misses = 5
          ..prefetchedUsed = 3
          ..prefetchedTotal = 8
          ..reset();

        expect(metrics.hits, equals(0));
        expect(metrics.misses, equals(0));
        expect(metrics.prefetchedUsed, equals(0));
        expect(metrics.prefetchedTotal, equals(0));
      });

      test('hitRate returns 0 after reset', () {
        metrics
          ..hits = 10
          ..reset();

        expect(metrics.hitRate, equals(0.0));
      });
    });
  });
}
