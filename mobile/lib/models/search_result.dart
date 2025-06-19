// ABOUTME: Data models for search results across different search types
// ABOUTME: Supports users, videos, and hashtags with unified result handling

import 'package:flutter/foundation.dart';

/// Unified search result container
class SearchResult {
  final SearchResultType type;
  final String id;
  final dynamic data;

  SearchResult({
    required this.type,
    required this.id, 
    required this.data,
  });
}

/// Types of search results
enum SearchResultType {
  user,
  video,
  hashtag,
}

/// User search result data
class UserSearchResult {
  final String pubkey;
  final String displayName;
  final String username;
  final String? bio;
  final String? profilePicture;
  final int followCount;
  final bool isFollowing;

  UserSearchResult({
    required this.pubkey,
    required this.displayName,
    required this.username,
    this.bio,
    this.profilePicture,
    this.followCount = 0,
    this.isFollowing = false,
  });

  factory UserSearchResult.fromJson(Map<String, dynamic> json) {
    return UserSearchResult(
      pubkey: json['pubkey'] ?? '',
      displayName: json['displayName'] ?? json['name'] ?? 'Unknown User',
      username: json['username'] ?? json['nip05'] ?? '',
      bio: json['about'],
      profilePicture: json['picture'],
      followCount: json['followCount'] ?? 0,
      isFollowing: json['isFollowing'] ?? false,
    );
  }
}

/// Video search result data
class VideoSearchResult {
  final String eventId;
  final String title;
  final String description;
  final String creatorName;
  final String creatorPubkey;
  final String? thumbnailUrl;
  final String? videoUrl;
  final Duration? duration;
  final List<String> hashtags;
  final int viewCount;
  final DateTime createdAt;

  VideoSearchResult({
    required this.eventId,
    required this.title,
    required this.description,
    required this.creatorName,
    required this.creatorPubkey,
    this.thumbnailUrl,
    this.videoUrl,
    this.duration,
    this.hashtags = const [],
    this.viewCount = 0,
    required this.createdAt,
  });

  factory VideoSearchResult.fromJson(Map<String, dynamic> json) {
    return VideoSearchResult(
      eventId: json['id'] ?? '',
      title: json['title'] ?? 'Untitled Video',
      description: json['description'] ?? '',
      creatorName: json['creatorName'] ?? 'Unknown Creator',
      creatorPubkey: json['creatorPubkey'] ?? '',
      thumbnailUrl: json['thumbnailUrl'],
      videoUrl: json['videoUrl'],
      duration: json['duration'] != null 
          ? Duration(seconds: json['duration']) 
          : null,
      hashtags: List<String>.from(json['hashtags'] ?? []),
      viewCount: json['viewCount'] ?? 0,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (json['createdAt'] ?? 0) * 1000,
      ),
    );
  }
}

/// Hashtag search result data
class HashtagSearchResult {
  final String hashtag;
  final int usageCount;
  final List<String> recentVideoThumbnails;
  final DateTime? lastUsed;

  HashtagSearchResult({
    required this.hashtag,
    this.usageCount = 0,
    this.recentVideoThumbnails = const [],
    this.lastUsed,
  });

  factory HashtagSearchResult.fromJson(Map<String, dynamic> json) {
    return HashtagSearchResult(
      hashtag: json['hashtag'] ?? '',
      usageCount: json['usageCount'] ?? 0,
      recentVideoThumbnails: List<String>.from(json['recentThumbnails'] ?? []),
      lastUsed: json['lastUsed'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(json['lastUsed'] * 1000)
          : null,
    );
  }
}

/// Search query and filters
class SearchQuery {
  final String query;
  final SearchResultType type;
  final Map<String, dynamic> filters;

  SearchQuery({
    required this.query,
    required this.type,
    this.filters = const {},
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SearchQuery &&
          runtimeType == other.runtimeType &&
          query == other.query &&
          type == other.type &&
          mapEquals(filters, other.filters);

  @override
  int get hashCode => query.hashCode ^ type.hashCode ^ filters.hashCode;

  @override
  String toString() => 'SearchQuery(query: $query, type: $type, filters: $filters)';
}