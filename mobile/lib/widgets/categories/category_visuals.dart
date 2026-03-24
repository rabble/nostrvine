// ABOUTME: Shared visual metadata for featured and fallback category presentation.
// ABOUTME: Keeps the categories discovery list and gallery screens visually consistent.

import 'package:flutter/material.dart';
import 'package:openvine/models/video_category.dart';

class CategoryVisuals {
  const CategoryVisuals({
    required this.backgroundColor,
    required this.foregroundColor,
    this.assetPath,
  });

  final Color backgroundColor;
  final Color foregroundColor;
  final String? assetPath;

  static CategoryVisuals forCategory(VideoCategory category, int index) {
    final featured = _featuredCategoryVisuals[category.name.toLowerCase()];
    if (featured != null) {
      return featured;
    }
    return _fallbackCategoryVisuals[index % _fallbackCategoryVisuals.length];
  }
}

const _featuredCategoryVisuals = <String, CategoryVisuals>{
  'animals': CategoryVisuals(
    backgroundColor: Color(0xFF3E0C1F),
    foregroundColor: Color(0xFFFF7FAF),
    assetPath: 'assets/categories/animals.png',
  ),
  'food': CategoryVisuals(
    backgroundColor: Color(0xFF272F0E),
    foregroundColor: Color(0xFFD2FF40),
    assetPath: 'assets/categories/food.png',
  ),
  'nature': CategoryVisuals(
    backgroundColor: Color(0xFF231557),
    foregroundColor: Color(0xFF8568FF),
    assetPath: 'assets/categories/nature.png',
  ),
  'sports': CategoryVisuals(
    backgroundColor: Color(0xFF471F10),
    foregroundColor: Color(0xFFFF7640),
    assetPath: 'assets/categories/sports.png',
  ),
  'fashion': CategoryVisuals(
    backgroundColor: Color(0xFF0A223C),
    foregroundColor: Color(0xFF34BBF1),
    assetPath: 'assets/categories/style.png',
  ),
  'music': CategoryVisuals(
    backgroundColor: Color(0xFF363313),
    foregroundColor: Color(0xFFFFF140),
    assetPath: 'assets/categories/music.png',
  ),
  'fitness': CategoryVisuals(
    backgroundColor: Color(0xFF2D214D),
    foregroundColor: Color(0xFFA3A9FF),
    assetPath: 'assets/categories/fitness.png',
  ),
  'art': CategoryVisuals(
    backgroundColor: Color(0xFF471F10),
    foregroundColor: Color(0xFFFF7640),
    assetPath: 'assets/categories/art.png',
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
