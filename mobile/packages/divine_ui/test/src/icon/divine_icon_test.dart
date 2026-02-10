import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DivineIconName', () {
    test('assetPath returns correct path', () {
      expect(
        DivineIconName.arrowLeft.assetPath,
        'assets/icon/arrow_left.svg',
      );
    });

    test('assetPath handles mixed case file names', () {
      expect(
        DivineIconName.caretDown.assetPath,
        'assets/icon/CaretDown.svg',
      );
    });

    test('fileName returns the raw file name', () {
      expect(DivineIconName.x.fileName, 'close');
    });

    test('all enum values have non-empty file names', () {
      for (final icon in DivineIconName.values) {
        expect(
          icon.fileName,
          isNotEmpty,
          reason: '${icon.name} has empty fileName',
        );
      }
    });
  });

  group('DivineIcon', () {
    testWidgets('renders an SvgPicture', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DivineIcon(icon: DivineIconName.arrowLeft),
          ),
        ),
      );

      expect(find.byType(SvgPicture), findsOneWidget);
    });

    testWidgets('uses default size of 24', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DivineIcon(icon: DivineIconName.arrowLeft),
          ),
        ),
      );

      final svgPicture = tester.widget<SvgPicture>(find.byType(SvgPicture));
      expect(svgPicture.width, 24);
      expect(svgPicture.height, 24);
    });

    testWidgets('uses custom size', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DivineIcon(icon: DivineIconName.arrowLeft, size: 32),
          ),
        ),
      );

      final svgPicture = tester.widget<SvgPicture>(find.byType(SvgPicture));
      expect(svgPicture.width, 32);
      expect(svgPicture.height, 32);
    });

    testWidgets('applies color filter when color is provided', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DivineIcon(
              icon: DivineIconName.arrowLeft,
              color: VineTheme.onSurface,
            ),
          ),
        ),
      );

      final svgPicture = tester.widget<SvgPicture>(find.byType(SvgPicture));
      expect(
        svgPicture.colorFilter,
        const ColorFilter.mode(VineTheme.onSurface, BlendMode.srcIn),
      );
    });

    testWidgets('does not apply color filter when color is null', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DivineIcon(icon: DivineIconName.arrowLeft),
          ),
        ),
      );

      final svgPicture = tester.widget<SvgPicture>(find.byType(SvgPicture));
      expect(svgPicture.colorFilter, isNull);
    });

    testWidgets('can be used with const constructor', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DivineIcon(
              icon: DivineIconName.check,
              color: VineTheme.primary,
            ),
          ),
        ),
      );

      expect(find.byType(DivineIcon), findsOneWidget);
    });
  });
}
