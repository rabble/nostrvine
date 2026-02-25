// ABOUTME: Model for NIP-51 curated video lists (kind 30005).
// ABOUTME: Represents user-created collections with playlist features,
// ABOUTME: collaboration support, and mixed video references
// ABOUTME: (event IDs + addressable coordinates).

import 'package:equatable/equatable.dart';

/// Ordering options for playlist playback.
enum PlayOrder {
  /// Order by date added (oldest first).
  chronological,

  /// Reverse chronological order (newest first).
  reverse,

  /// Custom manual order set by the user.
  manual,

  /// Randomized order.
  shuffle,
}

/// Serialization helpers for [PlayOrder].
extension PlayOrderExtension on PlayOrder {
  /// Converts this [PlayOrder] to its string representation.
  String get value {
    switch (this) {
      case PlayOrder.chronological:
        return 'chronological';
      case PlayOrder.reverse:
        return 'reverse';
      case PlayOrder.manual:
        return 'manual';
      case PlayOrder.shuffle:
        return 'shuffle';
    }
  }

  /// Parses a string into a [PlayOrder], defaulting to
  /// [PlayOrder.chronological].
  static PlayOrder fromString(String value) {
    switch (value) {
      case 'chronological':
        return PlayOrder.chronological;
      case 'reverse':
        return PlayOrder.reverse;
      case 'manual':
        return PlayOrder.manual;
      case 'shuffle':
        return PlayOrder.shuffle;
      default:
        return PlayOrder.chronological;
    }
  }
}

/// A curated list of videos with playlist features.
///
/// Represents a NIP-51 kind 30005 event containing references to video events.
/// Video references in [videoEventIds] are mixed:
/// - **Event IDs**: 64-character hex strings
/// - **Addressable coordinates**: `kind:pubkey:d-tag` format
///   (NIP-71 kinds 34235, 34236, 34237)
///
/// WARNING: Lists with [isPublic] set to `false` are stored locally only
/// (SharedPreferences). They are ephemeral and will be lost if the user
/// clears app data, uninstalls, or switches devices.
class CuratedList extends Equatable {
  /// Creates a curated list.
  const CuratedList({
    required this.id,
    required this.name,
    required this.videoEventIds,
    required this.createdAt,
    required this.updatedAt,
    this.pubkey,
    this.description,
    this.imageUrl,
    this.isPublic = true,
    this.nostrEventId,
    this.tags = const [],
    this.isCollaborative = false,
    this.allowedCollaborators = const [],
    this.thumbnailEventId,
    this.playOrder = PlayOrder.chronological,
  });

  /// Creates a [CuratedList] from a JSON map.
  factory CuratedList.fromJson(Map<String, dynamic> json) => CuratedList(
    id: json['id'] as String,
    name: json['name'] as String,
    pubkey: json['pubkey'] as String?,
    description: json['description'] as String?,
    imageUrl: json['imageUrl'] as String?,
    videoEventIds: List<String>.from(json['videoEventIds'] as List? ?? []),
    createdAt: DateTime.parse(json['createdAt'] as String),
    updatedAt: DateTime.parse(json['updatedAt'] as String),
    isPublic: json['isPublic'] as bool? ?? true,
    nostrEventId: json['nostrEventId'] as String?,
    tags: List<String>.from(json['tags'] as List? ?? []),
    isCollaborative: json['isCollaborative'] as bool? ?? false,
    allowedCollaborators: List<String>.from(
      json['allowedCollaborators'] as List? ?? [],
    ),
    thumbnailEventId: json['thumbnailEventId'] as String?,
    playOrder: PlayOrderExtension.fromString(
      json['playOrder'] as String? ?? 'chronological',
    ),
  );

  /// The list identifier (Nostr d-tag).
  final String id;

  /// Display name of the list.
  final String name;

  /// Creator's public key for attribution.
  final String? pubkey;

  /// Optional description of the list.
  final String? description;

  /// Optional cover image URL.
  final String? imageUrl;

  /// Video references — mixed event IDs (64-char hex) and addressable
  /// coordinates (`kind:pubkey:d-tag`).
  final List<String> videoEventIds;

  /// When the list was created.
  final DateTime createdAt;

  /// When the list was last updated.
  final DateTime updatedAt;

  /// Whether to publish this list to Nostr relays.
  ///
  /// WARNING: `isPublic = false` means local-only storage. Private lists
  /// have no backup and are lost on app uninstall or device change.
  final bool isPublic;

  /// The Nostr event ID when published to relays.
  final String? nostrEventId;

  /// Tags for categorization and discovery.
  final List<String> tags;

  /// Whether others can add videos to this list.
  final bool isCollaborative;

  /// Public keys allowed to collaborate on this list.
  final List<String> allowedCollaborators;

  /// Featured video event ID used as thumbnail.
  final String? thumbnailEventId;

  /// How videos should be ordered during playback.
  final PlayOrder playOrder;

  /// Creates a copy of this list with the given fields replaced.
  CuratedList copyWith({
    String? id,
    String? name,
    String? pubkey,
    String? description,
    String? imageUrl,
    List<String>? videoEventIds,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isPublic,
    String? nostrEventId,
    List<String>? tags,
    bool? isCollaborative,
    List<String>? allowedCollaborators,
    String? thumbnailEventId,
    PlayOrder? playOrder,
  }) => CuratedList(
    id: id ?? this.id,
    name: name ?? this.name,
    pubkey: pubkey ?? this.pubkey,
    description: description ?? this.description,
    imageUrl: imageUrl ?? this.imageUrl,
    videoEventIds: videoEventIds ?? this.videoEventIds,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    isPublic: isPublic ?? this.isPublic,
    nostrEventId: nostrEventId ?? this.nostrEventId,
    tags: tags ?? this.tags,
    isCollaborative: isCollaborative ?? this.isCollaborative,
    allowedCollaborators: allowedCollaborators ?? this.allowedCollaborators,
    thumbnailEventId: thumbnailEventId ?? this.thumbnailEventId,
    playOrder: playOrder ?? this.playOrder,
  );

  /// Converts this list to a JSON map.
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'pubkey': pubkey,
    'description': description,
    'imageUrl': imageUrl,
    'videoEventIds': videoEventIds,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'isPublic': isPublic,
    'nostrEventId': nostrEventId,
    'tags': tags,
    'isCollaborative': isCollaborative,
    'allowedCollaborators': allowedCollaborators,
    'thumbnailEventId': thumbnailEventId,
    'playOrder': playOrder.value,
  };

  @override
  List<Object?> get props => [
    id,
    name,
    pubkey,
    description,
    imageUrl,
    videoEventIds,
    createdAt,
    updatedAt,
    isPublic,
    nostrEventId,
    tags,
    isCollaborative,
    allowedCollaborators,
    thumbnailEventId,
    playOrder,
  ];
}
