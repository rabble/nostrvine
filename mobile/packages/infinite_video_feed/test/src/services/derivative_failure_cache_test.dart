import 'package:flutter_test/flutter_test.dart';
import 'package:infinite_video_feed/src/services/derivative_failure_cache.dart';

const _hash =
    'a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2';
const _variantUrl = 'https://media.divine.video/$_hash/720p.mp4';
const _rawUrl = 'https://media.divine.video/$_hash';
const _hlsUrl = 'https://media.divine.video/$_hash/hls/master.m3u8';

void main() {
  group(DerivativeFailureCache, () {
    late DateTime now;
    late DerivativeFailureCache cache;

    setUp(() {
      now = DateTime(2026, 8, 14, 12);
      cache = DerivativeFailureCache(clock: () => now);
    });

    test('records failures for derivative sources by hash', () {
      cache.recordFailureForSource(_variantUrl);

      expect(cache.hasFreshFailureForHash(_hash), isTrue);
    });

    test('ignores raw and HLS sources', () {
      cache
        ..recordFailureForSource(_rawUrl)
        ..recordFailureForSource(_hlsUrl);

      expect(cache.hasFreshFailureForHash(_hash), isFalse);
    });

    test('expires failures after the TTL', () {
      cache.recordFailureForSource(_variantUrl);

      now = now.add(derivativeFailureCacheTtl);
      expect(cache.hasFreshFailureForHash(_hash), isTrue);

      now = now.add(const Duration(milliseconds: 1));
      expect(cache.hasFreshFailureForHash(_hash), isFalse);
    });
  });

  group('derivativeHashForSource', () {
    test('returns a hash only for derivative sources', () {
      expect(derivativeHashForSource(_variantUrl), equals(_hash));
      expect(derivativeHashForSource(_rawUrl), isNull);
      expect(derivativeHashForSource(_hlsUrl), isNull);
      expect(derivativeHashForSource('https://example.com/video.mp4'), isNull);
    });
  });
}
