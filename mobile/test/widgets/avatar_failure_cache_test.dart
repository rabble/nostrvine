import 'package:flutter_test/flutter_test.dart';
import 'package:media_cache/media_cache.dart';
import 'package:openvine/widgets/avatar_failure_cache.dart';

void main() {
  group(AvatarFailureCache, () {
    late DateTime now;
    late AvatarFailureCache cache;

    setUp(() {
      now = DateTime.utc(2026, 7, 7, 12);
      cache = AvatarFailureCache.testing(clock: () => now);
    });

    test('records and reports a failed URL until its TTL expires', () {
      const url = 'https://example.com/avatar.png';

      cache.recordFailure(url, ttl: AvatarFailureCache.deterministicFailureTtl);

      expect(cache.isFailed(url), isTrue);

      now = now.add(AvatarFailureCache.deterministicFailureTtl);

      expect(cache.isFailed(url), isFalse);
      expect(cache.isFailed(url), isFalse);
    });

    test('supports short transient failures', () {
      const url = 'https://example.com/avatar.png';

      cache.recordFailure(url, ttl: AvatarFailureCache.transientFailureTtl);

      now = now.add(
        AvatarFailureCache.transientFailureTtl -
            const Duration(milliseconds: 1),
      );
      expect(cache.isFailed(url), isTrue);

      now = now.add(const Duration(milliseconds: 1));
      expect(cache.isFailed(url), isFalse);
    });

    test('records deterministic failures for one hour', () {
      const url = 'https://example.com/avatar.png';

      final kind = cache.recordFailureForError(
        url,
        Exception('Invalid image data'),
      );

      expect(kind, AvatarFailureKind.deterministic);
      expect(cache.isFailed(url), isTrue);

      now = now.add(AvatarFailureCache.transientFailureTtl);
      expect(cache.isFailed(url), isTrue);

      now = now.add(
        AvatarFailureCache.deterministicFailureTtl -
            AvatarFailureCache.transientFailureTtl,
      );
      expect(cache.isFailed(url), isFalse);
    });

    test('treats malformed SVG parse errors as deterministic', () {
      const url = 'https://divine.video/divine-logo.svg';

      final kind = cache.recordFailureForError(
        url,
        Exception('XmlParserException: ">" expected at 1:5'),
      );

      expect(kind, AvatarFailureKind.deterministic);
      expect(cache.isFailed(url), isTrue);

      now = now.add(AvatarFailureCache.transientFailureTtl);
      expect(cache.isFailed(url), isTrue);
    });

    test('records unknown failures as transient', () {
      const url = 'https://example.com/avatar.png';

      final kind = cache.recordFailureForError(url, Exception('HTTP 503'));

      expect(kind, AvatarFailureKind.transient);
      expect(cache.isFailed(url), isTrue);

      now = now.add(AvatarFailureCache.transientFailureTtl);
      expect(cache.isFailed(url), isFalse);
    });

    test('caches completed raster download failures transiently', () {
      const url = 'https://blotcdn.com/broken-avatar.png';

      final kind = cache.recordFailureForError(
        url,
        const MediaCacheImageLoadException(url),
      );

      expect(kind, AvatarFailureKind.transient);
      expect(cache.isFailed(url), isTrue);

      now = now.add(AvatarFailureCache.transientFailureTtl);
      expect(cache.isFailed(url), isFalse);
    });

    test('treats empty cached image files as deterministic', () {
      const url = 'https://example.com/avatar.png';

      final kind = cache.recordFailureForError(
        url,
        StateError(
          "File: '/tmp/avatar.png' is empty and cannot be loaded as an image.",
        ),
      );

      expect(kind, AvatarFailureKind.deterministic);
      expect(cache.isFailed(url), isTrue);

      now = now.add(AvatarFailureCache.transientFailureTtl);
      expect(cache.isFailed(url), isTrue);
    });

    test('caches surfaced cancellation-shaped errors transiently', () {
      const url = 'https://example.com/avatar.png';

      final kind = cache.recordFailureForError(
        url,
        Exception('SvgPicture load cancelled'),
      );

      expect(kind, AvatarFailureKind.transient);
      expect(cache.isFailed(url), isTrue);
    });

    test('evicts least recently used entries when bounded', () {
      cache = AvatarFailureCache.testing(clock: () => now, maxEntries: 2);

      cache.recordFailure(
        'https://example.com/a.png',
        ttl: AvatarFailureCache.deterministicFailureTtl,
      );
      cache.recordFailure(
        'https://example.com/b.png',
        ttl: AvatarFailureCache.deterministicFailureTtl,
      );
      expect(cache.isFailed('https://example.com/a.png'), isTrue);

      cache.recordFailure(
        'https://example.com/c.png',
        ttl: AvatarFailureCache.deterministicFailureTtl,
      );

      expect(cache.isFailed('https://example.com/a.png'), isTrue);
      expect(cache.isFailed('https://example.com/b.png'), isFalse);
      expect(cache.isFailed('https://example.com/c.png'), isTrue);
    });

    test('clear removes cached failures', () {
      const url = 'https://example.com/avatar.png';

      cache.recordFailure(url, ttl: AvatarFailureCache.deterministicFailureTtl);
      cache.clear();

      expect(cache.isFailed(url), isFalse);
    });
  });
}
