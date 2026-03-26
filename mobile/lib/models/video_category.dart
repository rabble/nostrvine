// ABOUTME: Model for video categories from the Funnelcake REST API
// ABOUTME: Represents a content category with name, video count, and emoji

import 'package:equatable/equatable.dart';

/// A video content category from VLM classification.
class VideoCategory extends Equatable {
  const VideoCategory({required this.name, required this.videoCount});

  factory VideoCategory.fromJson(Map<String, dynamic> json) {
    return VideoCategory(
      name: json['name'] as String? ?? '',
      videoCount: _parseInt(json['video_count']),
    );
  }

  /// The category name (e.g., "music", "comedy").
  final String name;

  /// Number of videos in this category.
  final int videoCount;

  /// Display name with first letter capitalized.
  String get displayName {
    if (name.isEmpty) return '';
    final normalizedName = name.toLowerCase();
    final customLabel = _categoryDisplayNames[normalizedName];
    if (customLabel != null) {
      return customLabel;
    }
    return name[0].toUpperCase() + name.substring(1);
  }

  /// Emoji icon for this category.
  String get emoji => _categoryEmojis[name.toLowerCase()] ?? '🎬';

  /// Whether this category is one of the featured Figma categories.
  bool get isFeatured => _featuredCategoryOrder.contains(name.toLowerCase());

  /// Sort rank for featured-first category ordering.
  int get featuredRank {
    final index = _featuredCategoryOrder.indexOf(name.toLowerCase());
    return index == -1 ? _featuredCategoryOrder.length : index;
  }

  @override
  List<Object?> get props => [name, videoCount];

  static int _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }
}

const _featuredCategoryOrder = <String>[
  'animals',
  'food',
  'nature',
  'sports',
  'fashion',
  'music',
  'fitness',
  'art',
];

const _categoryDisplayNames = <String, String>{
  'fashion': 'Style',
};

/// Mapping of category names to emoji icons.
const _categoryEmojis = <String, String>{
  'music': '🎵',
  'sports': '🏆',
  'dance': '💃',
  'comedy': '😂',
  'travel': '✈️',
  'fashion': '👗',
  'family': '👨‍👩‍👧‍👦',
  'gaming': '🎮',
  'beauty': '✨',
  'tech': '💻',
  'food': '🍕',
  'education': '🎓',
  'animals': '🐾',
  'basketball': '🏀',
  'diy': '🔧',
  'news': '📰',
  'drama': '🎭',
  'nature': '🌿',
  'celebrity': '🌟',
  'pets': '🐶',
  'art': '🎨',
  'vlog': '📹',
  'performance': '🎤',
  'lifestyle': '💖',
  'fitness': '💪',
  'automotive': '🚗',
  'romance': '💕',
  'animation': '🎬',
  'action': '💥',
  'crime': '🔍',
  'football': '⚽',
  'people': '👥',
  'cooking': '👨‍🍳',
  'entertainment': '🎪',
  'technology': '🖥️',
};
