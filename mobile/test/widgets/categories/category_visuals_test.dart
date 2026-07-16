// ABOUTME: Tests for CategoryVisuals asset-path resolution and aliases.
// ABOUTME: Locks the #4398 alias map so backend names resolve to bundled SVGs.

import 'dart:io';

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

      test('resolves to null when no SVG is bundled for the slug (#6116)', () {
        // "fighting" has no assets/categories/fighting.svg; the old code pointed
        // assetPath at the missing file and let the load throw.
        final visuals = CategoryVisuals.forCategory(
          const VideoCategory(name: 'fighting', videoCount: 42),
          1,
        );

        expect(visuals.assetPath, isNull);
        // A missing asset must not cost the category its fallback colors.
        expect(visuals.backgroundColor, isNotNull);
        expect(visuals.foregroundColor, isNotNull);
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

    group('bundledAssetBasenames', () {
      test('stays in sync with the assets/categories/ directory (#6116)', () {
        // The set is the runtime source of truth for "is this asset bundled?".
        // If it drifts from disk, forCategory either drops a real asset (ugly
        // emoji fallback) or points at a missing file (the crash returns), so
        // pin it to the actual *.svg files here.
        final onDisk = Directory('assets/categories')
            .listSync()
            .whereType<File>()
            .map((e) => e.uri.pathSegments.last)
            .where((name) => name.endsWith('.svg'))
            .map((name) => name.substring(0, name.length - '.svg'.length))
            .toSet();

        expect(
          onDisk,
          isNotEmpty,
          reason: 'asset directory should not be empty',
        );
        expect(CategoryVisuals.bundledAssetBasenames, equals(onDisk));
      });

      test('covers every curated featured asset', () {
        // Featured categories bypass the bundled-set check, so verify their
        // hand-picked assets are on disk too.
        for (final name in const ['animals', 'food', 'nature', 'style']) {
          expect(
            CategoryVisuals.bundledAssetBasenames,
            contains(name),
            reason: '$name.svg backs a featured category',
          );
        }
      });
    });
  });
}
