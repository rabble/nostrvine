// ABOUTME: Shared visual metadata for featured and fallback category presentation.
// ABOUTME: Keeps the categories discovery list and gallery screens visually consistent.

import 'package:flutter/material.dart';
import 'package:models/models.dart' show VideoCategory;

class CategoryVisuals {
  const CategoryVisuals({
    required this.backgroundColor,
    required this.foregroundColor,
    this.assetPath,
  });

  final Color backgroundColor;
  final Color foregroundColor;
  final String? assetPath;

  /// Resolves visuals for any category. Featured categories get custom colors;
  /// all others cycle through fallback colors. A category only receives an SVG
  /// [assetPath] when a matching illustration is actually bundled. Names with
  /// no bundled asset (e.g. `beverages`, `fighting` served by the backend)
  /// resolve to a null [assetPath] so consumers degrade to the plain colored
  /// card instead of throwing "Unable to load asset" (#4398).
  static CategoryVisuals forCategory(VideoCategory category, int index) {
    final name = category.name.toLowerCase();
    final featured = _featuredCategoryVisuals[name];
    if (featured != null) {
      return featured;
    }
    final fallback =
        _fallbackCategoryVisuals[index % _fallbackCategoryVisuals.length];
    // Fashion is stored as style.svg for display-name consistency.
    final assetName = name == 'fashion' ? 'style' : name;
    return CategoryVisuals(
      backgroundColor: fallback.backgroundColor,
      foregroundColor: fallback.foregroundColor,
      assetPath: bundledCategoryAssetNames.contains(assetName)
          ? 'assets/categories/$assetName.svg'
          : null,
    );
  }

  /// Stems (filename without `.svg`) of every category illustration bundled
  /// under `assets/categories/`. Single source of truth for whether a derived
  /// asset path exists in the app bundle, since the backend category list is
  /// open-ended and not guaranteed to match the bundled illustrations.
  ///
  /// Kept in lockstep with the on-disk asset directory by
  /// `test/widgets/categories/category_visuals_test.dart`; update both together
  /// when adding or removing a category illustration.
  static const Set<String> bundledCategoryAssetNames = {
    'action',
    'adventure',
    'animals',
    'animation',
    'architecture',
    'art',
    'automotive',
    'award-show',
    'awards',
    'baseball',
    'basketball',
    'beauty',
    'beverage',
    'cars',
    'celebration',
    'celebrities',
    'celebrity',
    'cityscape',
    'comedy',
    'concert',
    'cooking',
    'costume',
    'crafts',
    'crime',
    'culture',
    'dance',
    'diy',
    'drama',
    'education',
    'emotional',
    'emotions',
    'entertainment',
    'event',
    'family',
    'fans',
    'fantasy',
    'fashion',
    'festival',
    'film',
    'fitness',
    'food',
    'football',
    'furniture',
    'gaming',
    'golf',
    'grooming',
    'guitar',
    'halloween',
    'health',
    'hockey',
    'holiday',
    'home',
    'home-improvement',
    'horror',
    'hospital',
    'humor',
    'interior-design',
    'interview',
    'kids',
    'lifestyle',
    'magic',
    'makeup',
    'medical',
    'music',
    'mystery',
    'nature',
    'news',
    'outdoor',
    'party',
    'people',
    'performance',
    'pets',
    'politics',
    'prank',
    'pranks',
    'reality-show',
    'relationship',
    'relationships',
    'romance',
    'school',
    'science-fiction',
    'selfie',
    'shopping',
    'skateboarding',
    'skincare',
    'soccer',
    'social-gathering',
    'social-media',
    'sports',
    'style',
    'talk-show',
    'technology',
    'television',
    'toys',
    'transportation',
    'travel',
    'urban',
    'violence',
    'vlog',
    'vlogging',
    'wrestling',
  };
}

const _featuredCategoryVisuals = <String, CategoryVisuals>{
  'animals': CategoryVisuals(
    backgroundColor: Color(0xFF3E0C1F),
    foregroundColor: Color(0xFFFF7FAF),
    assetPath: 'assets/categories/animals.svg',
  ),
  'food': CategoryVisuals(
    backgroundColor: Color(0xFF272F0E),
    foregroundColor: Color(0xFFD2FF40),
    assetPath: 'assets/categories/food.svg',
  ),
  'nature': CategoryVisuals(
    backgroundColor: Color(0xFF231557),
    foregroundColor: Color(0xFF8568FF),
    assetPath: 'assets/categories/nature.svg',
  ),
  'sports': CategoryVisuals(
    backgroundColor: Color(0xFF471F10),
    foregroundColor: Color(0xFFFF7640),
    assetPath: 'assets/categories/sports.svg',
  ),
  'fashion': CategoryVisuals(
    backgroundColor: Color(0xFF0A223C),
    foregroundColor: Color(0xFF34BBF1),
    assetPath: 'assets/categories/style.svg',
  ),
  'music': CategoryVisuals(
    backgroundColor: Color(0xFF363313),
    foregroundColor: Color(0xFFFFF140),
    assetPath: 'assets/categories/music.svg',
  ),
  'fitness': CategoryVisuals(
    backgroundColor: Color(0xFF2D214D),
    foregroundColor: Color(0xFFA3A9FF),
    assetPath: 'assets/categories/fitness.svg',
  ),
  'art': CategoryVisuals(
    backgroundColor: Color(0xFF471F10),
    foregroundColor: Color(0xFFFF7640),
    assetPath: 'assets/categories/art.svg',
  ),
};

const _fallbackCategoryVisuals = <CategoryVisuals>[
  CategoryVisuals(
    backgroundColor: Color(0xFF103023),
    foregroundColor: Color(0xFF7AF0B7),
  ),
  CategoryVisuals(
    backgroundColor: Color(0xFF251C41),
    foregroundColor: Color(0xFFB6A7FF),
  ),
  CategoryVisuals(
    backgroundColor: Color(0xFF1E2C10),
    foregroundColor: Color(0xFFE4FF70),
  ),
  CategoryVisuals(
    backgroundColor: Color(0xFF0E2942),
    foregroundColor: Color(0xFF62CFFF),
  ),
];
