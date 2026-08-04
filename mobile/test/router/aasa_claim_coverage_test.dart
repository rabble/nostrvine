// ABOUTME: Guards served AASA path claims against mobile routing drift.
// ABOUTME: Keeps fixture updates deliberate when served AASA files change.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/deep_link_service.dart';

const _divineAppId = 'GZCZBKH7MY.co.openvine.app';

// Refresh fixtures with:
// curl https://divine.video/.well-known/apple-app-site-association \
//   > test/fixtures/deep_links/aasa_divine_video.json
// curl https://login.divine.video/.well-known/apple-app-site-association \
//   > test/fixtures/deep_links/aasa_login_divine_video.json
//
// Apex and www are served by divine-web. login.divine.video is served by
// keycast. Keep this test offline; curl only when intentionally refreshing the
// checked-in fixtures.
const _expectedClaimPatternsByHost = <String, List<String>>{
  'divine.video': [
    '/video/*',
    '/profile/*',
    '/hashtag/*',
    '/search/*',
    '/invite/*',
    '/list/*',
    '/app/callback',
  ],
  'www.divine.video': [
    '/video/*',
    '/profile/*',
    '/hashtag/*',
    '/search/*',
    '/invite/*',
    '/list/*',
    '/app/callback',
  ],
  'login.divine.video': [
    '/app/callback',
    '/app/callback/*',
    '/verify-email',
    '/reset-password',
  ],
};

const _allowlistedClaims = <String, String>{
  'divine.video /app/callback':
      'Keycast OAuth redirect consumed by the OAuth client, not DeepLinkService.',
  'www.divine.video /app/callback':
      'Keycast OAuth redirect consumed by the OAuth client, not DeepLinkService.',
  'login.divine.video /app/callback':
      'Keycast OAuth redirect consumed by the OAuth client, not DeepLinkService.',
  'login.divine.video /app/callback/*':
      'Keycast OAuth redirect with path params, consumed before app deep-link routing.',
  'login.divine.video /verify-email':
      'Auth link path matches an internal GoRoute directly; no DeepLinkType is emitted.',
  'login.divine.video /reset-password':
      'Auth link path matches an internal GoRoute redirect directly; no DeepLinkType is emitted.',
};

void main() {
  group('AASA claim coverage', () {
    for (final host in _expectedClaimPatternsByHost.keys) {
      test('$host claimed paths are routed or explicitly allowlisted', () {
        final patterns = _claimPatternsForHost(host);
        expect(patterns, _expectedClaimPatternsByHost[host]);

        for (final pattern in patterns) {
          for (final path in _representativePathsFor(pattern)) {
            final url = 'https://$host$path';
            final deepLink = DeepLinkService.parseDeepLink(url);
            final allowlistReason = _allowlistedClaims['$host $pattern'];

            if (deepLink.type == DeepLinkType.unknown) {
              expect(
                allowlistReason,
                isNotNull,
                reason:
                    '$host claims $pattern but $url has no mobile route '
                    'coverage and no allowlist reason.',
              );
            } else {
              expect(
                allowlistReason,
                isNull,
                reason:
                    '$host $pattern is now parsed by DeepLinkService; '
                    'remove the stale allowlist entry.',
              );
            }
          }
        }
      });
    }
  });
}

List<String> _claimPatternsForHost(String host) {
  final aasa = _readAasaForHost(host);
  final details = (aasa['applinks'] as Map<String, dynamic>)['details'] as List;
  final patterns = <String>[];

  for (final detail in details.cast<Map<String, dynamic>>()) {
    final appIDs = detail['appIDs'] as List? ?? const [];
    if (!appIDs.contains(_divineAppId)) {
      continue;
    }

    final components = detail['components'] as List? ?? [];
    for (final component in components.cast<Map<String, dynamic>>()) {
      if (component['exclude'] == true) {
        continue;
      }

      final pattern = component['/'] as String?;
      if (pattern != null && !patterns.contains(pattern)) {
        patterns.add(pattern);
      }
    }
  }

  return patterns;
}

Map<String, dynamic> _readAasaForHost(String host) {
  final fixtureName = switch (host) {
    'divine.video' || 'www.divine.video' => 'aasa_divine_video.json',
    'login.divine.video' => 'aasa_login_divine_video.json',
    _ => throw ArgumentError.value(host, 'host', 'No AASA fixture'),
  };
  final file = File('test/fixtures/deep_links/$fixtureName');
  return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
}

List<String> _representativePathsFor(String pattern) {
  return switch (pattern) {
    '/profile/*' => const ['/profile/sample', '/profile/sample/1'],
    '/hashtag/*' => const ['/hashtag/sample', '/hashtag/sample/1'],
    '/search/*' => const ['/search/sample', '/search/sample/1'],
    '/list/*' => const [
      '/list/sample',
      '/list/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa/sample',
    ],
    _ when pattern.endsWith('/*') => [
      '${pattern.substring(0, pattern.length - 1)}sample',
    ],
    _ => [pattern],
  };
}
