import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_app_bridge_repository/nostr_app_bridge_repository.dart';
import 'package:openvine/screens/apps/nostr_app_launch_mode.dart';

NostrAppDirectoryEntry _entry({
  required String slug,
  required String launchUrl,
}) {
  return NostrAppDirectoryEntry(
    id: 'id-$slug',
    slug: slug,
    name: slug,
    tagline: '',
    description: '',
    iconUrl: '',
    launchUrl: launchUrl,
    allowedOrigins: [Uri.parse(launchUrl).origin],
    allowedMethods: const [],
    allowedSignEventKinds: const [],
    promptRequiredFor: const [],
    status: 'approved',
    sortOrder: 0,
    createdAt: null,
    updatedAt: null,
  );
}

void main() {
  group('appRequiresSystemBrowser', () {
    test('returns true for the verifier app (cross-origin OAuth)', () {
      final app = _entry(
        slug: 'verifier',
        launchUrl: 'https://verifier.divine.video/',
      );
      expect(appRequiresSystemBrowser(app), isTrue);
    });

    test(
      'returns true for the older verifyer slug (directory data may carry it)',
      () {
        final app = _entry(
          slug: 'verifyer',
          launchUrl: 'https://verifyer.divine.video/',
        );
        expect(appRequiresSystemBrowser(app), isTrue);
      },
    );

    test('returns false for an ordinary sandbox app', () {
      final app = _entry(slug: 'primal', launchUrl: 'https://primal.net/');
      expect(appRequiresSystemBrowser(app), isFalse);
    });

    test('matches the real preloaded verifier app (guards slug drift)', () {
      final verifier = preloadedNostrApps.firstWhere(
        (app) => app.id == 'bundled-verifier',
      );
      expect(appRequiresSystemBrowser(verifier), isTrue);
    });
  });

  group('isAllowedSystemBrowserTarget', () {
    test(
      'accepts the real preloaded verifier launch_url (guards host drift)',
      () {
        final verifier = preloadedNostrApps.firstWhere(
          (app) => app.id == 'bundled-verifier',
        );
        expect(isAllowedSystemBrowserTarget(verifier.launchUrl), isTrue);
      },
    );

    test('accepts both verifier host spellings over https', () {
      expect(
        isAllowedSystemBrowserTarget('https://verifier.divine.video/'),
        isTrue,
      );
      expect(
        isAllowedSystemBrowserTarget('https://verifyer.divine.video/'),
        isTrue,
      );
    });

    test('rejects the pinned host over a non-https scheme', () {
      expect(
        isAllowedSystemBrowserTarget('http://verifier.divine.video/'),
        isFalse,
      );
    });

    test('rejects non-web schemes', () {
      expect(isAllowedSystemBrowserTarget('tel:12345'), isFalse);
      expect(
        isAllowedSystemBrowserTarget('intent://verifier.divine.video'),
        isFalse,
      );
    });

    test('rejects a userinfo-spoofed host', () {
      expect(
        isAllowedSystemBrowserTarget(
          'https://verifier.divine.video@evil.test/',
        ),
        isFalse,
      );
    });

    test('rejects a subdomain-suffix-spoofed host', () {
      expect(
        isAllowedSystemBrowserTarget(
          'https://verifier.divine.video.evil.test/',
        ),
        isFalse,
      );
    });

    test('rejects an off-host https url', () {
      expect(isAllowedSystemBrowserTarget('https://evil.test/'), isFalse);
    });
  });
}
