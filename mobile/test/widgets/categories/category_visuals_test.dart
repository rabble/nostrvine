// ABOUTME: Guards category illustration resolution against missing-asset
// ABOUTME: crashes (#4398) and keeps the bundled-asset set in sync with disk.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart' show VideoCategory;
import 'package:openvine/widgets/categories/category_visuals.dart';

void main() {
  group(CategoryVisuals, () {
    const assetPrefix = 'assets/categories/';
    const assetSuffix = '.svg';

    String? stemOf(String? assetPath) {
      if (assetPath == null) return null;
      expect(assetPath, startsWith(assetPrefix));
      expect(assetPath, endsWith(assetSuffix));
      return assetPath.substring(
        assetPrefix.length,
        assetPath.length - assetSuffix.length,
      );
    }

    CategoryVisuals visualsFor(String name) => CategoryVisuals.forCategory(
      VideoCategory(name: name, videoCount: 1),
      0,
    );

    test('bundledCategoryAssetNames matches the on-disk asset directory', () {
      final dir = Directory(assetPrefix);
      expect(
        dir.existsSync(),
        isTrue,
        reason: '${dir.path} not found; run flutter test from mobile/',
      );

      final onDisk = dir
          .listSync()
          .whereType<File>()
          .map((file) => file.uri.pathSegments.last)
          .where((name) => name.endsWith(assetSuffix))
          .map((name) => name.substring(0, name.length - assetSuffix.length))
          .toSet();

      const set = CategoryVisuals.bundledCategoryAssetNames;
      expect(
        set,
        equals(onDisk),
        reason:
            'bundledCategoryAssetNames drifted from $assetPrefix. '
            'On disk but missing from the set: ${onDisk.difference(set)}. '
            'In the set but not on disk: ${set.difference(onDisk)}.',
      );
    });

    test('forCategory never resolves to an unbundled asset path', () {
      final names = <String>{
        ...CategoryVisuals.bundledCategoryAssetNames,
        'beverages',
        'fighting',
        'BEVERAGES',
        'totally-unknown-category',
        '',
      };

      for (final name in names) {
        final stem = stemOf(visualsFor(name).assetPath);
        if (stem != null) {
          expect(
            CategoryVisuals.bundledCategoryAssetNames,
            contains(stem),
            reason: 'category "$name" resolved to unbundled $stem$assetSuffix',
          );
        }
      }
    });

    test('backend names with no bundled illustration resolve to null', () {
      // The exact names observed in the #4398 Crashlytics non-fatals.
      for (final name in const ['beverages', 'fighting']) {
        expect(
          visualsFor(name).assetPath,
          isNull,
          reason: '$name has no bundled asset and must not derive a path',
        );
      }
    });

    test('bundled non-featured names keep their illustration', () {
      expect(
        visualsFor('comedy').assetPath,
        equals('${assetPrefix}comedy$assetSuffix'),
      );
    });

    test('uppercase backend names still resolve case-insensitively', () {
      expect(
        visualsFor('Comedy').assetPath,
        equals('${assetPrefix}comedy$assetSuffix'),
      );
    });

    test('fashion resolves to the bundled style illustration', () {
      expect(
        visualsFor('fashion').assetPath,
        equals('${assetPrefix}style$assetSuffix'),
      );
    });

    test('every featured category points to a bundled illustration', () {
      const featured = [
        'animals',
        'food',
        'nature',
        'sports',
        'fashion',
        'music',
        'fitness',
        'art',
      ];

      for (final name in featured) {
        final stem = stemOf(visualsFor(name).assetPath);
        expect(stem, isNotNull, reason: 'featured $name should have an asset');
        expect(
          CategoryVisuals.bundledCategoryAssetNames,
          contains(stem),
          reason: 'featured $name -> $stem$assetSuffix is not bundled',
        );
      }
    });
  });
}
