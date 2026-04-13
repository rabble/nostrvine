// ABOUTME: Tests for path_resolver — web-safe document root joining
//
// On web, getDocumentsPath returns '' without calling path_provider; that
// branch is exercised by `flutter build web` (compile-time). Optional:
// `flutter test test/utils/path_resolver_test.dart --platform chrome` plus a
// kIsWeb-only test if the environment has a working Chrome test runner.

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/utils/path_resolver.dart';

void main() {
  group('resolvePath', () {
    test('joins basename when documents root is empty (web)', () {
      expect(resolvePath('folder/clip.mp4', ''), 'clip.mp4');
    });

    test('joins basename under documents path on disk', () {
      expect(
        resolvePath('/old/container/clip.mp4', '/app/docs'),
        '/app/docs/clip.mp4',
      );
    });
  });
}
