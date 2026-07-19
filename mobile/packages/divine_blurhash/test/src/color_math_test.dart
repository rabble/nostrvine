import 'package:divine_blurhash/src/color_math.dart';
import 'package:test/test.dart';

void main() {
  group('color math', () {
    test('sRgbToLinear maps the channel extremes to 0 and 1', () {
      expect(sRgbToLinear(0), 0.0);
      expect(sRgbToLinear(255), closeTo(1, 1e-9));
    });

    test('sRgbToLinear uses the linear segment for small values', () {
      // v = 10/255 ≈ 0.039 ≤ 0.04045 → v / 12.92
      expect(sRgbToLinear(10), closeTo(10 / 255 / 12.92, 1e-12));
    });

    test('linearToSRgb maps 0 and 1 back to the channel extremes', () {
      expect(linearToSRgb(0), 0);
      expect(linearToSRgb(1), 255);
    });

    test('linearToSRgb uses the linear segment near zero', () {
      expect(linearToSRgb(0.002), (0.002 * 12.92 * 255 + 0.5).toInt());
    });

    test('linearToSRgb clamps out-of-range values', () {
      expect(linearToSRgb(-0.5), 0);
      expect(linearToSRgb(1.5), 255);
    });

    test('signPow preserves the sign of its input', () {
      expect(signPow(2, 2), closeTo(4, 1e-9));
      expect(signPow(-2, 2), closeTo(-4, 1e-9));
      expect(signPow(0, 2), 0.0);
    });
  });
}
