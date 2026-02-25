// ABOUTME: Unit tests for DeepLinkService URL parsing and deep link handling
// ABOUTME: Tests video URLs, profile URLs, and unknown URL patterns

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/deep_link_service.dart';

void main() {
  group('DeepLinkService URL Parsing', () {
    late DeepLinkService service;

    setUp(() {
      service = DeepLinkService();
    });

    tearDown(() {
      service.dispose();
    });

    group('Video URL Parsing', () {
      test('parses valid video URL correctly', () {
        const videoId = 'abc123def456';
        final url = 'https://divine.video/video/$videoId';

        final result = service.parseDeepLink(url);

        expect(result.type, equals(DeepLinkType.video));
        expect(result.videoId, equals(videoId));
        expect(result.npub, isNull);
      });

      test('parses video URL with 64-char hex ID', () {
        const videoId =
            'a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2';
        final url = 'https://divine.video/video/$videoId';

        final result = service.parseDeepLink(url);

        expect(result.type, equals(DeepLinkType.video));
        expect(result.videoId, equals(videoId));
      });

      test('handles video URL with trailing slash', () {
        const videoId = 'abc123';
        final url = 'https://divine.video/video/$videoId/';

        final result = service.parseDeepLink(url);

        // Should still parse - trailing slash creates empty segment
        expect(result.type, equals(DeepLinkType.unknown));
      });

      test('rejects video URL without ID', () {
        const url = 'https://divine.video/video';

        final result = service.parseDeepLink(url);

        expect(result.type, equals(DeepLinkType.unknown));
        expect(result.videoId, isNull);
      });

      test('rejects video URL with extra path segments', () {
        const url = 'https://divine.video/video/abc123/extra';

        final result = service.parseDeepLink(url);

        expect(result.type, equals(DeepLinkType.unknown));
      });
    });

    group('Profile URL Parsing', () {
      test('parses valid profile URL correctly', () {
        const npub = 'npub1abc123def456';
        final url = 'https://divine.video/profile/$npub';

        final result = service.parseDeepLink(url);

        expect(result.type, equals(DeepLinkType.profile));
        expect(result.npub, equals(npub));
        expect(result.videoId, isNull);
      });

      test('parses profile URL with real npub format', () {
        const npub =
            'npub1sn0wdenkukak0d9dfczzeacvhkrgz92ak56egt7vdgzn8pv2wfqqhrjdv9';
        final url = 'https://divine.video/profile/$npub';

        final result = service.parseDeepLink(url);

        expect(result.type, equals(DeepLinkType.profile));
        expect(result.npub, equals(npub));
      });

      test('rejects profile URL without npub', () {
        const url = 'https://divine.video/profile';

        final result = service.parseDeepLink(url);

        expect(result.type, equals(DeepLinkType.unknown));
        expect(result.npub, isNull);
      });

      test('parses profile URL with video index', () {
        const npub = 'npub1abc123def456';
        final url = 'https://divine.video/profile/$npub/3';

        final result = service.parseDeepLink(url);

        expect(result.type, equals(DeepLinkType.profile));
        expect(result.npub, equals(npub));
        expect(result.index, equals(3));
      });

      test('parses profile URL with non-numeric index as null', () {
        const npub = 'npub1abc123def456';
        final url = 'https://divine.video/profile/$npub/extra';

        final result = service.parseDeepLink(url);

        expect(result.type, equals(DeepLinkType.profile));
        expect(result.npub, equals(npub));
        expect(result.index, isNull);
      });
    });

    group('Hashtag URL Parsing', () {
      test('parses /hashtag/{tag} correctly', () {
        final result = service.parseDeepLink(
          'https://divine.video/hashtag/vibes',
        );

        expect(result.type, equals(DeepLinkType.hashtag));
        expect(result.hashtag, equals('vibes'));
        expect(result.index, isNull);
      });

      test('parses /hashtag/{tag}/{index} with index', () {
        final result = service.parseDeepLink(
          'https://divine.video/hashtag/music/5',
        );

        expect(result.type, equals(DeepLinkType.hashtag));
        expect(result.hashtag, equals('music'));
        expect(result.index, equals(5));
      });

      test('rejects hashtag URL without tag', () {
        final result = service.parseDeepLink('https://divine.video/hashtag');

        expect(result.type, equals(DeepLinkType.unknown));
      });
    });

    group('Search URL Parsing', () {
      test('parses /search/{term} correctly', () {
        final result = service.parseDeepLink(
          'https://divine.video/search/flutter',
        );

        expect(result.type, equals(DeepLinkType.search));
        expect(result.searchTerm, equals('flutter'));
        expect(result.index, isNull);
      });

      test('parses /search/{term}/{index} with index', () {
        final result = service.parseDeepLink(
          'https://divine.video/search/dart/2',
        );

        expect(result.type, equals(DeepLinkType.search));
        expect(result.searchTerm, equals('dart'));
        expect(result.index, equals(2));
      });

      test('rejects search URL without term', () {
        final result = service.parseDeepLink('https://divine.video/search');

        expect(result.type, equals(DeepLinkType.unknown));
      });
    });

    group('Unknown URL Patterns', () {
      test('rejects non-divine.video domain', () {
        const url = 'https://example.com/video/abc123';

        final result = service.parseDeepLink(url);

        expect(result.type, equals(DeepLinkType.unknown));
      });

      test('rejects invalid path structure', () {
        const url = 'https://divine.video/unknown/path';

        final result = service.parseDeepLink(url);

        expect(result.type, equals(DeepLinkType.unknown));
      });

      test('rejects root URL', () {
        const url = 'https://divine.video/';

        final result = service.parseDeepLink(url);

        expect(result.type, equals(DeepLinkType.unknown));
      });

      test('handles malformed URL gracefully', () {
        const url = 'not-a-valid-url';

        final result = service.parseDeepLink(url);

        expect(result.type, equals(DeepLinkType.unknown));
      });

      test('handles empty string gracefully', () {
        const url = '';

        final result = service.parseDeepLink(url);

        expect(result.type, equals(DeepLinkType.unknown));
      });
    });

    group('URL Scheme Handling', () {
      test('accepts http scheme', () {
        const videoId = 'abc123';
        final url = 'http://divine.video/video/$videoId';

        final result = service.parseDeepLink(url);

        expect(result.type, equals(DeepLinkType.video));
        expect(result.videoId, equals(videoId));
      });

      test('accepts https scheme', () {
        const videoId = 'abc123';
        final url = 'https://divine.video/video/$videoId';

        final result = service.parseDeepLink(url);

        expect(result.type, equals(DeepLinkType.video));
        expect(result.videoId, equals(videoId));
      });
    });

    group('DeepLink Data Class', () {
      test('creates video deep link with correct data', () {
        const deepLink = DeepLink(type: DeepLinkType.video, videoId: 'test123');

        expect(deepLink.type, equals(DeepLinkType.video));
        expect(deepLink.videoId, equals('test123'));
        expect(deepLink.npub, isNull);
      });

      test('creates profile deep link with correct data', () {
        const deepLink = DeepLink(type: DeepLinkType.profile, npub: 'npub123');

        expect(deepLink.type, equals(DeepLinkType.profile));
        expect(deepLink.npub, equals('npub123'));
        expect(deepLink.videoId, isNull);
      });

      test('creates unknown deep link with no data', () {
        const deepLink = DeepLink(type: DeepLinkType.unknown);

        expect(deepLink.type, equals(DeepLinkType.unknown));
        expect(deepLink.videoId, isNull);
        expect(deepLink.npub, isNull);
      });

      test('creates hashtag deep link with index', () {
        const deepLink = DeepLink(
          type: DeepLinkType.hashtag,
          hashtag: 'art',
          index: 2,
        );

        expect(deepLink.type, equals(DeepLinkType.hashtag));
        expect(deepLink.hashtag, equals('art'));
        expect(deepLink.index, equals(2));
      });

      test('creates search deep link', () {
        const deepLink = DeepLink(
          type: DeepLinkType.search,
          searchTerm: 'test',
        );

        expect(deepLink.type, equals(DeepLinkType.search));
        expect(deepLink.searchTerm, equals('test'));
      });
    });

    group('$DeepLink toString', () {
      test('formats video deep link', () {
        const link = DeepLink(type: DeepLinkType.video, videoId: 'abc');
        expect(link.toString(), equals('DeepLink(type: video, videoId: abc)'));
      });

      test('formats profile deep link with index', () {
        const link = DeepLink(
          type: DeepLinkType.profile,
          npub: 'npub1x',
          index: 2,
        );
        expect(
          link.toString(),
          equals('DeepLink(type: profile, npub: npub1x, index: 2)'),
        );
      });

      test('formats hashtag deep link', () {
        const link = DeepLink(type: DeepLinkType.hashtag, hashtag: 'art');
        expect(
          link.toString(),
          equals('DeepLink(type: hashtag, hashtag: art)'),
        );
      });

      test('formats search deep link', () {
        const link = DeepLink(type: DeepLinkType.search, searchTerm: 'q');
        expect(
          link.toString(),
          equals('DeepLink(type: search, searchTerm: q)'),
        );
      });

      test('formats unknown deep link', () {
        const link = DeepLink(type: DeepLinkType.unknown);
        expect(link.toString(), equals('DeepLink(type: unknown)'));
      });
    });
  });
}
