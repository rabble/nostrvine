// ABOUTME: Source-reading contract test for the web platform label, which
// ABOUTME: VM tests cannot execute (see divine_video_player's Apple threading
// ABOUTME: contract test for the pattern).

import 'dart:io';

import 'package:test/test.dart';

void main() {
  group('web platform label contract', () {
    // The web implementation is only compiled into a browser build, so this
    // asserts on its source the way the Apple threading contract test does.
    final source = File('lib/src/platform_label_web.dart').readAsStringSync();

    test('web sends no X-Divine-Platform token', () {
      expect(
        source,
        contains('String? get divinePlatformToken => null'),
        reason:
            'X-Divine-Platform is not on the CORS safelist, so a non-null '
            'token on web turns every request into a preflight that backend '
            'CORS policy rejects — breaking all web API calls. Reverting '
            'this constant is invisible to every VM test; this guard is not.',
      );
    });
  });
}
