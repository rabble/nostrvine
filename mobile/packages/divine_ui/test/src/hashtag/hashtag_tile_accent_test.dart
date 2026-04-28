import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('hashtagTileBackgroundForLabel', () {
    test('is stable for the same normalized label', () {
      final a = hashtagTileBackgroundForLabel('#rust');
      final b = hashtagTileBackgroundForLabel('rust');
      expect(a, b);
    });

    test('empty-ish input falls back to first palette slot', () {
      expect(
        hashtagTileBackgroundForLabel('   '),
        kHashtagTilePalette.first,
      );
    });
  });
}
