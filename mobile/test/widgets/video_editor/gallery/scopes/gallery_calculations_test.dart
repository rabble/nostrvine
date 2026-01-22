import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/widgets/video_editor/gallery/scopes/gallery_calculations.dart';

void main() {
  group('GalleryCalculations', () {
    test('stores calculation function references', () {
      final calculations = GalleryCalculations(
        calculateScale: (index) => index * 0.1,
        calculateXOffset: (index) => index * 10.0,
      );

      expect(calculations.calculateScale(5), 0.5);
      expect(calculations.calculateXOffset(3), 30.0);
    });

    test('calculateScale returns correct values for different indices', () {
      final calculations = GalleryCalculations(
        calculateScale: (index) => 1.0 - (index * 0.15),
        calculateXOffset: (_) => 0,
      );

      expect(calculations.calculateScale(0), 1.0);
      expect(calculations.calculateScale(1), 0.85);
      expect(calculations.calculateScale(2), 0.7);
    });

    test('calculateXOffset can return negative values', () {
      final calculations = GalleryCalculations(
        calculateScale: (_) => 1.0,
        calculateXOffset: (index) => index > 0 ? -50.0 : 50.0,
      );

      expect(calculations.calculateXOffset(0), 50.0);
      expect(calculations.calculateXOffset(1), -50.0);
    });
  });

  group('GalleryCalculationsScope', () {
    late GalleryCalculations testCalculations;

    setUp(() {
      testCalculations = GalleryCalculations(
        calculateScale: (index) => 1.0,
        calculateXOffset: (index) => 0.0,
      );
    });

    testWidgets('of() returns calculations from ancestor', (tester) async {
      GalleryCalculations? retrievedCalculations;

      await tester.pumpWidget(
        GalleryCalculationsScope(
          calculations: testCalculations,
          child: Builder(
            builder: (context) {
              retrievedCalculations = GalleryCalculationsScope.of(context);
              return const SizedBox();
            },
          ),
        ),
      );

      expect(retrievedCalculations, testCalculations);
    });

    testWidgets('of() throws assertion when no scope in tree', (tester) async {
      await tester.pumpWidget(
        Builder(
          builder: (context) {
            expect(
              () => GalleryCalculationsScope.of(context),
              throwsA(isA<AssertionError>()),
            );
            return const SizedBox();
          },
        ),
      );
    });

    testWidgets('calculations are accessible in nested widgets', (
      tester,
    ) async {
      double? scaleResult;
      double? offsetResult;

      final calculations = GalleryCalculations(
        calculateScale: (index) => 0.9,
        calculateXOffset: (index) => 25.0,
      );

      await tester.pumpWidget(
        GalleryCalculationsScope(
          calculations: calculations,
          child: Builder(
            builder: (context) {
              final calc = GalleryCalculationsScope.of(context);
              scaleResult = calc.calculateScale(0);
              offsetResult = calc.calculateXOffset(0);
              return const SizedBox();
            },
          ),
        ),
      );

      expect(scaleResult, 0.9);
      expect(offsetResult, 25.0);
    });

    testWidgets('updateShouldNotify always returns false', (tester) async {
      // GalleryCalculationsScope doesn't notify on changes
      // because calculations don't change identity
      final calculations1 = GalleryCalculations(
        calculateScale: (_) => 1.0,
        calculateXOffset: (_) => 0.0,
      );
      final calculations2 = GalleryCalculations(
        calculateScale: (_) => 0.5,
        calculateXOffset: (_) => 10.0,
      );

      final scope1 = GalleryCalculationsScope(
        calculations: calculations1,
        child: const SizedBox(),
      );
      final scope2 = GalleryCalculationsScope(
        calculations: calculations2,
        child: const SizedBox(),
      );

      // Should always return false per the implementation
      expect(scope1.updateShouldNotify(scope2), false);
    });

    testWidgets('works with deeply nested widgets', (tester) async {
      GalleryCalculations? retrievedCalculations;

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: GalleryCalculationsScope(
            calculations: testCalculations,
            child: Column(
              children: [
                Row(
                  children: [
                    Builder(
                      builder: (context) {
                        retrievedCalculations = GalleryCalculationsScope.of(
                          context,
                        );
                        return const SizedBox();
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );

      expect(retrievedCalculations, testCalculations);
    });
  });
}
