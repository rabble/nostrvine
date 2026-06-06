// ABOUTME: Tests for CategoryVisuals asset-path resolution and aliases.
// ABOUTME: Locks the #4398 alias map so backend names resolve to bundled SVGs.

import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart' show VideoCategory;
import 'package:openvine/widgets/categories/category_visuals.dart';

void main() {
  group(CategoryVisuals, () {
    group('forCategory asset path', () {
      test('aliases backend "beverages" onto the bundled beverage.svg', () {
        final visuals = CategoryVisuals.forCategory(
          const VideoCategory(name: 'beverages', videoCount: 5),
          0,
        );

        expect(visuals.assetPath, equals('assets/categories/beverage.svg'));
      });

      test('derives the path from the slug for non-aliased categories', () {
        final visuals = CategoryVisuals.forCategory(
          const VideoCategory(name: 'comedy', videoCount: 99),
          3,
        );

        expect(visuals.assetPath, equals('assets/categories/comedy.svg'));
      });

      test('is case-insensitive on the slug', () {
        final visuals = CategoryVisuals.forCategory(
          const VideoCategory(name: 'BEVERAGES', videoCount: 5),
          0,
        );

        expect(visuals.assetPath, equals('assets/categories/beverage.svg'));
      });
    });

    group('featured categories', () {
      test('returns the curated visuals for a featured category', () {
        final visuals = CategoryVisuals.forCategory(
          const VideoCategory(name: 'music', videoCount: 1797),
          7,
        );

        expect(visuals.assetPath, equals('assets/categories/music.svg'));
        // Featured categories use a hand-picked palette, not a fallback color.
        expect(visuals.backgroundColor, isNot(equals(visuals.foregroundColor)));
      });

      test('maps fashion to the curated style asset', () {
        final visuals = CategoryVisuals.forCategory(
          const VideoCategory(name: 'fashion', videoCount: 10),
          0,
        );

        expect(visuals.assetPath, equals('assets/categories/style.svg'));
      });
    });
  });
}
