// ABOUTME: Tests for path_resolver — web-safe document root joining
//
// `getDocumentsPath` on web is covered by the web-only test below; run it with
// `flutter test test/utils/path_resolver_test.dart --platform chrome` (manual /
// local — not executed in CI). `flutter build web` only checks compilation, not
// this runtime branch.

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/utils/path_resolver.dart';

void main() {
  group('getDocumentsPath', () {
    test(
      'returns empty string on web without using path_provider',
      () async {
        expect(await getDocumentsPath(), '');
      },
      skip: !kIsWeb
          ? 'Web-only: run `flutter test test/utils/path_resolver_test.dart --platform chrome`'
          : null,
    );
  });

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
