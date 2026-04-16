// ABOUTME: Model for video categories from the Funnelcake REST API
// ABOUTME: Represents a content category with name, video count, and emoji

import 'package:equatable/equatable.dart';
import 'package:models/src/user_profile_data.dart';

/// A video content category from VLM classification.
class VideoCategory extends Equatable {
  const VideoCategory({required this.name, required this.videoCount});

  factory VideoCategory.fromJson(Map<String, dynamic> json) {
    return VideoCategory(
      name: json['name'] as String? ?? '',
      videoCount: parseIntSafe(json['video_count']),
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
///
/// Sourced from relay.divine.video/api/categories (100 categories).
/// Each entry has a matching OpenMoji SVG in assets/categories/.
const _categoryEmojis = <String, String>{
  'action': '💥',
  'adventure': '🏕',
  'animals': '🐾',
  'animation': '🎬',
  'architecture': '🏛',
  'art': '🎨',
  'automotive': '🚗',
  'award-show': '🏆',
  'awards': '🏆',
  'baseball': '⚾',
  'basketball': '🏀',
  'beauty': '✨',
  'beverage': '🥤',
  'cars': '🚗',
  'celebration': '🎆',
  'celebrities': '⭐',
  'celebrity': '🌟',
  'cityscape': '🌆',
  'comedy': '😂',
  'concert': '🎶',
  'cooking': '👨‍🍳',
  'costume': '🎭',
  'crafts': '🧵',
  'crime': '🔍',
  'culture': '🌍',
  'dance': '💃',
  'diy': '🔧',
  'drama': '🎭',
  'education': '🎓',
  'emotional': '😢',
  'emotions': '😔',
  'entertainment': '🎪',
  'event': '📅',
  'family': '👨‍👩‍👧‍👦',
  'fans': '👏',
  'fantasy': '🧚',
  'fashion': '👗',
  'festival': '🎪',
  'film': '🎬',
  'fitness': '💪',
  'food': '🍕',
  'football': '⚽',
  'furniture': '🛋',
  'gaming': '🎮',
  'golf': '⛳',
  'grooming': '💇',
  'guitar': '🎸',
  'halloween': '🎃',
  'health': '⚕',
  'hockey': '🏒',
  'holiday': '🌴',
  'home': '🏠',
  'home-improvement': '🏠',
  'horror': '👻',
  'hospital': '🏥',
  'humor': '🤣',
  'interior-design': '🛋',
  'interview': '🎙',
  'kids': '🧒',
  'lifestyle': '💖',
  'magic': '🪄',
  'makeup': '💄',
  'medical': '⚕',
  'music': '🎸',
  'mystery': '🕵',
  'nature': '🌿',
  'news': '📰',
  'outdoor': '⛺',
  'party': '🎉',
  'people': '👥',
  'performance': '🎤',
  'pets': '🐶',
  'politics': '🏛',
  'prank': '🤪',
  'pranks': '🤪',
  'reality-show': '📺',
  'relationship': '💑',
  'relationships': '💑',
  'romance': '💕',
  'school': '🏫',
  'science-fiction': '🚀',
  'selfie': '🤳',
  'shopping': '🛒',
  'skateboarding': '🛹',
  'skincare': '🫧',
  'soccer': '⚽',
  'social-gathering': '🤝',
  'social-media': '📱',
  'sports': '🏆',
  'talk-show': '📺',
  'tech': '💻',
  'technology': '💻',
  'television': '📺',
  'toys': '🧸',
  'transportation': '🚌',
  'travel': '✈️',
  'urban': '🏙',
  'violence': '💢',
  'vlog': '📹',
  'vlogging': '📹',
  'wrestling': '🤼',
};
