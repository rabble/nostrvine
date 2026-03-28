import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('font assets', () {
    for (final path in _fontPaths) {
      test('$path contains a valid font signature', () async {
        final file = File(path);
        final bytes = await file.readAsBytes();

        expect(
          bytes.length,
          greaterThanOrEqualTo(4),
          reason: '$path should contain at least a font header.',
        );
        expect(
          _hasKnownFontSignature(bytes),
          isTrue,
          reason: '$path is not a valid TTF/OTF/TTC font file.',
        );
      });
    }
  });
}

const _fontPaths = <String>[
  'assets/fonts/BricolageGrotesque-Bold.ttf',
  'assets/fonts/BricolageGrotesque-ExtraBold.ttf',
  'assets/fonts/Inter-Regular.ttf',
  'assets/fonts/Inter-SemiBold.ttf',
  'assets/fonts/Pacifico-Regular.ttf',
  'google_fonts/BricolageGrotesque-Bold.ttf',
  'google_fonts/BricolageGrotesque-ExtraBold.ttf',
  'google_fonts/Inter-Medium.ttf',
  'google_fonts/Inter-Regular.ttf',
  'google_fonts/Inter-SemiBold.ttf',
];

bool _hasKnownFontSignature(List<int> bytes) {
  final header = bytes.take(4).toList(growable: false);

  return _matches(header, const [0x00, 0x01, 0x00, 0x00]) ||
      _matches(header, const [0x4F, 0x54, 0x54, 0x4F]) ||
      _matches(header, const [0x74, 0x74, 0x63, 0x66]) ||
      _matches(header, const [0x74, 0x72, 0x75, 0x65]);
}

bool _matches(List<int> actual, List<int> expected) {
  if (actual.length != expected.length) {
    return false;
  }

  for (var index = 0; index < actual.length; index++) {
    if (actual[index] != expected[index]) {
      return false;
    }
  }

  return true;
}
