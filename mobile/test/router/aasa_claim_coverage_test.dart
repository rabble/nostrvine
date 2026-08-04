// ABOUTME: Guards served AASA path claims against mobile routing drift.
// ABOUTME: Keeps fixture updates deliberate when divine-web changes links.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/deep_link_service.dart';

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
    test('fixtures pin the current served claim sets', () {
      expect(_claimPatternsForHost('divine.video'), [
        '/video/*',
        '/profile/*',
        '/hashtag/*',
        '/search/*',
        '/invite/*',
        '/list/*',
        '/app/callback',
      ]);
      expect(
        _claimPatternsForHost('www.divine.video'),
        _expectedClaimPatternsByHost['www.divine.video'],
      );
      expect(
        _claimPatternsForHost('login.divine.video'),
        _expectedClaimPatternsByHost['login.divine.video'],
      );
    });

    for (final host in _expectedClaimPatternsByHost.keys) {
      test('$host claimed paths are routed or explicitly allowlisted', () {
        final patterns = _claimPatternsForHost(host);
        expect(patterns, _expectedClaimPatternsByHost[host]);

        for (final pattern in patterns) {
          final url = 'https://$host${_representativePathFor(pattern)}';
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
            expect(allowlistReason, isNotEmpty);
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
      });
    }
  });
}

List<String> _claimPatternsForHost(String host) {
  final aasa = _readAasaForHost(host);
  final details = (aasa['applinks'] as Map<String, dynamic>)['details'] as List;
  final patterns = <String>[];

  for (final detail in details.cast<Map<String, dynamic>>()) {
    final components = detail['components'] as List? ?? [];
    for (final component in components.cast<Map<String, dynamic>>()) {
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

String _representativePathFor(String pattern) {
  if (pattern.endsWith('/*')) {
    return '${pattern.substring(0, pattern.length - 1)}sample';
  }
  return pattern;
}
