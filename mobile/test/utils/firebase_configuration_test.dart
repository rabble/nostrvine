import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/firebase_options.dart';
import 'package:openvine/utils/firebase_configuration.dart';

void main() {
  group('hasUsableFirebaseOptions', () {
    test('rejects web placeholder options', () {
      expect(
        hasUsableFirebaseOptions(DefaultFirebaseOptions.web),
        isFalse,
      );
    });

    test('accepts configured iOS options', () {
      expect(
        hasUsableFirebaseOptions(DefaultFirebaseOptions.ios),
        isTrue,
      );
    });

    test('accepts configured Android options', () {
      expect(
        hasUsableFirebaseOptions(DefaultFirebaseOptions.android),
        isTrue,
      );
    });

    test('rejects blank required values', () {
      const options = FirebaseOptions(
        apiKey: ' ',
        appId: '1:972941478875:web:abcdef',
        messagingSenderId: '972941478875',
        projectId: 'openvine-co',
      );

      expect(hasUsableFirebaseOptions(options), isFalse);
    });
  });
}
