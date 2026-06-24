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
}
