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
  /// all others cycle through fallback colors. Every category gets an SVG
  /// asset path derived from its name.
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
      assetPath: 'assets/categories/$assetName.svg',
    );
  }
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
