// ABOUTME: Unit tests for universal_link_resolver — pure Uri -> path mapping
// ABOUTME: Covers divine.video host gating and every DeepLinkType branch

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/router/universal_link_resolver.dart';

void main() {
  group('universalLinkToRouterPath', () {
    group('host gating', () {
      test('returns null for non-http schemes', () {
        expect(
          universalLinkToRouterPath(Uri.parse('divine://signer-callback')),
          isNull,
        );
      });

      test('returns null for unrelated hosts', () {
        expect(
          universalLinkToRouterPath(
            Uri.parse('https://example.com/search/music'),
          ),
          isNull,
        );
      });

      test('returns null for path-only URIs (in-app navigation)', () {
        expect(
          universalLinkToRouterPath(Uri.parse('/home/0')),
          isNull,
        );
      });

      test('accepts divine.video host', () {
        expect(
          universalLinkToRouterPath(
            Uri.parse('https://divine.video/search/music'),
          ),
          equals('/search-results/music'),
        );
      });

      test(
        'returns null for login.divine.video — OAuth callback paths '
        'already match internal GoRoutes by coincidence',
        () {
          expect(
            universalLinkToRouterPath(
              Uri.parse('https://login.divine.video/search/music'),
            ),
            isNull,
          );
        },
      );
    });

    group('search', () {
      test('maps /search/:term to /search-results/:term', () {
        expect(
          universalLinkToRouterPath(
            Uri.parse('https://divine.video/search/flutter'),
          ),
          equals('/search-results/flutter'),
        );
      });

      test('maps /search/:term/:index by dropping the index', () {
        // The internal SearchResultsPage route does not accept a trailing
        // index, so it is intentionally dropped.
        expect(
          universalLinkToRouterPath(
            Uri.parse('https://divine.video/search/flutter/3'),
          ),
          equals('/search-results/flutter'),
        );
      });

      test('returns null for /search without a term', () {
        expect(
          universalLinkToRouterPath(Uri.parse('https://divine.video/search')),
          isNull,
        );
      });
    });

    group('profile', () {
      test('maps /profile/:npub to /profile/:npub', () {
        const npub =
            'npub1xyz000000000000000000000000000000000000000000000000000000000';
        expect(
          universalLinkToRouterPath(
            Uri.parse('https://divine.video/profile/$npub'),
          ),
          equals('/profile/$npub'),
        );
      });

      test('maps /profile/:npub/:index to /profile/:npub/:index', () {
        const npub =
            'npub1abc000000000000000000000000000000000000000000000000000000000';
        expect(
          universalLinkToRouterPath(
            Uri.parse('https://divine.video/profile/$npub/7'),
          ),
          equals('/profile/$npub/7'),
        );
      });
    });

    group('hashtag', () {
      test('maps /hashtag/:tag to /hashtag/:tag', () {
        expect(
          universalLinkToRouterPath(
            Uri.parse('https://divine.video/hashtag/flutter'),
          ),
          equals('/hashtag/flutter'),
        );
      });

      test('preserves URL-encoded non-ASCII tags', () {
        // Uri.parse decodes the percent-encoded emoji into pathSegments;
        // HashtagScreenRouter.pathForTag then re-encodes it via
        // Uri.encodeComponent, so the round-trip is deterministic.
        final encoded = Uri.encodeComponent('🔥');
        final result = universalLinkToRouterPath(
          Uri.parse('https://divine.video/hashtag/$encoded'),
        );
        expect(result, equals('/hashtag/$encoded'));
      });
    });

    group('paths deferred to the DeepLinkService listener', () {
      test('/video/:id returns null (listener uses push for back-nav)', () {
        expect(
          universalLinkToRouterPath(
            Uri.parse('https://divine.video/video/abc123'),
          ),
          isNull,
        );
      });

      test('/invite/:code returns null', () {
        // Invite is not part of the Android intent filter; it reaches the
        // app via other channels and is handled by the listener.
        expect(
          universalLinkToRouterPath(
            Uri.parse('https://divine.video/invite/ABCD-EFGH'),
          ),
          isNull,
        );
      });

      test('unknown divine.video path returns null', () {
        expect(
          universalLinkToRouterPath(
            Uri.parse('https://divine.video/nope'),
          ),
          isNull,
        );
      });
    });
  });
}
