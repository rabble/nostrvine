import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('VineTheme', () {
    test('has correct vineGreen color', () {
      expect(VineTheme.vineGreen.r, closeTo(0, 0.01));
      expect(VineTheme.vineGreen.g, closeTo(0.706, 0.01));
      expect(VineTheme.vineGreen.b, closeTo(0.533, 0.01));
    });
  });
}
