import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('colorFromArgb32', () {
    test('reconstructs a color from its ARGB int', () {
      expect(colorFromArgb32(0xFF112233), equals(const Color(0xFF112233)));
    });

    test('round-trips through toARGB32', () {
      const color = Color(0x80AABBCC);
      expect(colorFromArgb32(color.toARGB32()), equals(color));
    });
  });
}
