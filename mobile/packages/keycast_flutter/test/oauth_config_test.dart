// ABOUTME: Tests OAuthConfig endpoint derivation from serverUrl.
// ABOUTME: Covers the NIP-05 document consumed by username availability.

import 'package:flutter_test/flutter_test.dart';
import 'package:keycast_flutter/keycast_flutter.dart';

void main() {
  group(OAuthConfig, () {
    const config = OAuthConfig(
      serverUrl: 'https://login.divine.video',
      clientId: 'divine-mobile',
      redirectUri: 'divine://auth',
    );

    test('derives every endpoint from serverUrl', () {
      expect(
        config.authorizeUrl,
        equals('https://login.divine.video/api/oauth/authorize'),
      );
      expect(
        config.tokenUrl,
        equals('https://login.divine.video/api/oauth/token'),
      );
      expect(
        config.nostrApiUrl,
        equals('https://login.divine.video/api/nostr'),
      );
    });

    // Consumed by ProfileRepository as the second username-availability
    // source. Keycast resolves the tenant from the request Host, so the
    // origin must carry through unchanged.
    test('nip05Url points at the tenant named by serverUrl', () {
      expect(
        config.nip05Url,
        equals('https://login.divine.video/.well-known/nostr.json'),
      );
    });

    test('nip05Url follows a non-production origin', () {
      const local = OAuthConfig(
        serverUrl: 'http://localhost:43000',
        clientId: 'divine-mobile',
        redirectUri: 'divine://auth',
      );

      expect(
        local.nip05Url,
        equals('http://localhost:43000/.well-known/nostr.json'),
      );
    });
  });
}
