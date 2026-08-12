// ABOUTME: Tests the reported-URL policy for network-request metrics.
// ABOUTME: Identifier segments must collapse so Firebase aggregates them.

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/observability/network/http_url_pattern.dart';

void main() {
  const pubkey =
      '32e1827635450ebb3c5a7d12c1f8e7b2b514439ac10a67eef3d9fd9c5c68e245';
  const eventId =
      'a1b2c3d4e5f60718293a4b5c6d7e8f90a1b2c3d4e5f60718293a4b5c6d7e8f90';

  group('httpMetricUrlPattern', () {
    test('collapses a pubkey path segment so one endpoint is one pattern', () {
      final videos = httpMetricUrlPattern(
        Uri.parse('https://api.divine.video/api/users/$pubkey/videos'),
      );
      final otherUser = httpMetricUrlPattern(
        Uri.parse('https://api.divine.video/api/users/$eventId/videos'),
      );

      expect(videos, 'https://api.divine.video/api/users/:id/videos');
      expect(otherUser, videos);
    });

    test('drops the query string', () {
      expect(
        httpMetricUrlPattern(
          Uri.parse(
            'https://api.divine.video/api/videos'
            '?limit=20&cursor=$eventId&moderation_profile=default',
          ),
        ),
        'https://api.divine.video/api/videos',
      );
    });

    test('drops userinfo and the fragment', () {
      expect(
        httpMetricUrlPattern(
          Uri.parse('https://token@api.divine.video/api/videos#top'),
        ),
        'https://api.divine.video/api/videos',
      );
    });

    test('keeps an explicit non-default port so local runs stay distinct', () {
      expect(
        httpMetricUrlPattern(Uri.parse('http://localhost:47777/api/videos')),
        'http://localhost:47777/api/videos',
      );
    });

    test('keeps a file extension while collapsing the sha256 stem', () {
      expect(
        httpMetricUrlPattern(Uri.parse('https://media.divine.video/$eventId')),
        'https://media.divine.video/:id',
      );
      expect(
        httpMetricUrlPattern(
          Uri.parse('https://media.divine.video/$eventId.MP4'),
        ),
        'https://media.divine.video/:id.mp4',
      );
    });

    test('collapses NIP-19 entities to their type', () {
      expect(
        httpMetricUrlPattern(
          Uri.parse(
            'https://names.divine.video/api/username/by-pubkey/'
            'npub180cvv07tjdrrgpa0j7j7tmnyl2yr6yr7l8j4s3evf6u64th6gkwsyjh6w6',
          ),
        ),
        'https://names.divine.video/api/username/by-pubkey/:npub',
      );
      expect(
        httpMetricUrlPattern(
          Uri.parse(
            'https://api.divine.video/api/events/'
            'nevent1qqstna2yrezu5wghjvswqqwuzqqqqqqqzq3thd',
          ),
        ),
        'https://api.divine.video/api/events/:nevent',
      );
    });

    test('collapses numeric and uuid segments', () {
      expect(
        httpMetricUrlPattern(
          Uri.parse('https://api.divine.video/api/leaderboard/2026/7'),
        ),
        'https://api.divine.video/api/leaderboard/:n/:n',
      );
      expect(
        httpMetricUrlPattern(
          Uri.parse(
            'https://api.divine.video/api/uploads/'
            '4b2f9c1e-3a6d-4f80-9c1a-7e5b8d2f0a13',
          ),
        ),
        'https://api.divine.video/api/uploads/:uuid',
      );
    });

    test('collapses free-text segments on registered routes', () {
      final alice = httpMetricUrlPattern(
        Uri.parse('https://names.divine.video/api/username/check/alice'),
      );
      final bob = httpMetricUrlPattern(
        Uri.parse('https://names.divine.video/api/username/check/bob'),
      );

      expect(
        alice,
        'https://names.divine.video/api/username/check/:username',
      );
      expect(bob, alice);
    });

    test('collapses free-form video ids that are not hex/uuid/opaque', () {
      const shortcode = '5gITeYOlL7g';
      final byId = httpMetricUrlPattern(
        Uri.parse('https://api.divine.video/api/videos/$shortcode'),
      );
      final stats = httpMetricUrlPattern(
        Uri.parse('https://api.divine.video/api/videos/$shortcode/stats'),
      );
      final views = httpMetricUrlPattern(
        Uri.parse('https://api.divine.video/api/videos/$shortcode/views'),
      );
      final comments = httpMetricUrlPattern(
        Uri.parse(
          'https://api.divine.video/api/v2/videos/$shortcode/comments',
        ),
      );
      final bulk = httpMetricUrlPattern(
        Uri.parse('https://api.divine.video/api/videos/stats/bulk'),
      );

      expect(byId, 'https://api.divine.video/api/videos/:id');
      expect(stats, 'https://api.divine.video/api/videos/:id/stats');
      expect(views, 'https://api.divine.video/api/videos/:id/views');
      expect(comments, 'https://api.divine.video/api/v2/videos/:id/comments');
      expect(bulk, 'https://api.divine.video/api/videos/stats/bulk');
    });

    test('brackets IPv6 loopback so the reported URL stays parseable', () {
      expect(
        httpMetricUrlPattern(Uri.parse('http://[::1]:43001/api/videos')),
        'http://[::1]:43001/api/videos',
      );
    });

    test('leaves route words alone, however long', () {
      expect(
        httpMetricUrlPattern(
          Uri.parse('https://api.divine.video/api/hashtags/trending'),
        ),
        'https://api.divine.video/api/hashtags/trending',
      );
      expect(
        httpMetricUrlPattern(
          Uri.parse(
            'https://api.divine.video/api/users/$pubkey/notifications/read',
          ),
        ),
        'https://api.divine.video/api/users/:id/notifications/read',
      );
    });

    test('preserves a trailing slash rather than merging two routes', () {
      expect(
        httpMetricUrlPattern(Uri.parse('https://api.divine.video/api/videos/')),
        'https://api.divine.video/api/videos/',
      );
    });

    test('lower-cases the host so casing does not split a pattern', () {
      expect(
        httpMetricUrlPattern(Uri.parse('https://API.Divine.Video/api/videos')),
        'https://api.divine.video/api/videos',
      );
    });

    test('emits only characters a URI parser accepts', () {
      // Both Firebase SDKs parse the reported URL before recording it, and
      // neither is lenient: Android runs it through `java.net.URI.create`
      // and drops the metric when that throws, iOS 16 gets nil from
      // `NSURL(string:)`. A placeholder built from excluded characters —
      // `{id}` was the first attempt — reports nothing at all, silently.
      // Dart's own `Uri.parse` accepts braces, so it cannot stand in for
      // this check.
      const uuid = '4b2f9c1e-3a6d-4f80-9c1a-7e5b8d2f0a13';
      const npub =
          'npub180cvv07tjdrrgpa0j7j7tmnyl2yr6yr7l8j4s3evf6u64th6gkwsyjh6w6';
      const opaque = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9';
      final patterns = [
        for (final url in [
          'https://api.divine.video/api/users/$pubkey/videos',
          'https://api.divine.video/api/videos/$eventId/stats',
          'https://media.divine.video/$eventId.mp4',
          'https://api.divine.video/api/leaderboard/2026/7',
          'https://api.divine.video/api/uploads/$uuid',
          'https://names.divine.video/api/username/by-pubkey/$npub',
          'https://names.divine.video/api/username/check/alice',
          'https://api.divine.video/api/auth/$opaque',
          'http://10.0.2.2:43001/api/users/$pubkey',
        ])
          httpMetricUrlPattern(Uri.parse(url)),
      ];

      // RFC 2396 + RFC 2732, the grammar `java.net.URI` enforces. Excludes
      // `{`, `}`, space, `<`, `>`, `"`, `\`, `^`, `` ` `` and `|`.
      final legal = RegExp(r"^[A-Za-z0-9\-._~!$&'()*+,;=:@/?#%\[\]]+$");
      for (final pattern in patterns) {
        expect(
          legal.hasMatch(pattern),
          isTrue,
          reason: 'reported URL is not parseable by the SDKs: $pattern',
        );
      }
    });
  });

  group('isInstrumentedHost', () {
    test('accepts Divine-operated hosts and their subdomains', () {
      expect(isInstrumentedHost('api.divine.video'), isTrue);
      expect(isInstrumentedHost('media.divine.video'), isTrue);
      expect(isInstrumentedHost('divine.video'), isTrue);
      expect(isInstrumentedHost('relay.poc.dvines.org'), isTrue);
      expect(isInstrumentedHost('API.DIVINE.VIDEO'), isTrue);
    });

    test('accepts local-stack hosts so a local run can be verified', () {
      expect(isInstrumentedHost('localhost'), isTrue);
      expect(isInstrumentedHost('10.0.2.2'), isTrue);
    });

    test('rejects third-party hosts', () {
      expect(isInstrumentedHost('api.github.com'), isFalse);
      expect(isInstrumentedHost('nos.lol'), isFalse);
      expect(isInstrumentedHost('app-ads-services.com'), isFalse);
      expect(isInstrumentedHost(''), isFalse);
    });

    test('rejects a look-alike host that merely ends in our name', () {
      expect(isInstrumentedHost('notdivine.video'), isFalse);
      expect(isInstrumentedHost('divine.video.evil.com'), isFalse);
    });
  });
}
