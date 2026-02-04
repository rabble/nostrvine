import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('IconSource', () {
    group('SvgIconSource', () {
      test('stores asset path correctly', () {
        const source = SvgIconSource('assets/icon/test.svg');
        expect(source.assetPath, 'assets/icon/test.svg');
      });

      test('equality works correctly for same paths', () {
        const source1 = SvgIconSource('assets/icon/test.svg');
        const source2 = SvgIconSource('assets/icon/test.svg');
        expect(source1, equals(source2));
      });

      test('equality works correctly for different paths', () {
        const source1 = SvgIconSource('assets/icon/test1.svg');
        const source2 = SvgIconSource('assets/icon/test2.svg');
        expect(source1, isNot(equals(source2)));
      });
    });

    group('MaterialIconSource', () {
      test('stores icon data correctly', () {
        const source = MaterialIconSource(Icons.arrow_back);
        expect(source.iconData, Icons.arrow_back);
      });

      test('equality works correctly for same icons', () {
        const source1 = MaterialIconSource(Icons.arrow_back);
        const source2 = MaterialIconSource(Icons.arrow_back);
        expect(source1, equals(source2));
      });

      test('equality works correctly for different icons', () {
        const source1 = MaterialIconSource(Icons.arrow_back);
        const source2 = MaterialIconSource(Icons.menu);
        expect(source1, isNot(equals(source2)));
      });
    });
  });
}
