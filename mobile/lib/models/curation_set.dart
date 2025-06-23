// ABOUTME: Model for NIP-51 video curation sets (kind 30005)
// ABOUTME: Represents curated collections of videos with metadata and referenced video events

import 'package:nostr_sdk/event.dart';

/// NIP-51 Video Curation Set
/// Kind 30005: Groups of videos picked by users as interesting and/or belonging to the same category
class CurationSet {
  final String id;              // "d" tag identifier
  final String curatorPubkey;   // Public key of the curator
  final String? title;          // Optional title
  final String? description;    // Optional description
  final String? imageUrl;       // Optional cover image
  final List<String> videoIds;  // List of video event IDs (from "a" tags)
  final DateTime createdAt;
  final int eventKind;          // Should be 30005 for video curation sets

  const CurationSet({
    required this.id,
    required this.curatorPubkey,
    this.title,
    this.description,
    this.imageUrl,
    required this.videoIds,
    required this.createdAt,
    this.eventKind = 30005,
  });

  /// Create CurationSet from Nostr event
  factory CurationSet.fromNostrEvent(Event event) {
    if (event.kind != 30005) {
      throw ArgumentError('Invalid event kind for video curation set: ${event.kind}');
    }

    String? setId;
    String? title;
    String? description; 
    String? imageUrl;
    final List<String> videoIds = [];

    // Parse tags
    for (final tag in event.tags) {
      if (tag.isEmpty) continue;
      
      switch (tag[0]) {
        case 'd':
          if (tag.length > 1) setId = tag[1];
          break;
        case 'title':
          if (tag.length > 1) title = tag[1];
          break;
        case 'description':
          if (tag.length > 1) description = tag[1];
          break;
        case 'image':
          if (tag.length > 1) imageUrl = tag[1];
          break;
        case 'a':
          // Video reference: "a", "kind:pubkey:identifier"
          if (tag.length > 1) {
            final parts = tag[1].split(':');
            if (parts.length >= 3 && parts[0] == '22') { // NIP-71 video events
              // Extract the identifier part as video ID
              final videoId = parts.sublist(2).join(':');
              videoIds.add(videoId);
            }
          }
          break;
        case 'e':
          // Direct event reference
          if (tag.length > 1) {
            videoIds.add(tag[1]);
          }
          break;
      }
    }

    return CurationSet(
      id: setId ?? 'unnamed',
      curatorPubkey: event.pubkey,
      title: title,
      description: description,
      imageUrl: imageUrl,
      videoIds: videoIds,
      createdAt: DateTime.fromMillisecondsSinceEpoch(event.createdAt * 1000),
    );
  }

  /// Convert to Nostr event for publishing
  Event toNostrEvent() {
    final tags = <List<String>>[
      ['d', id],
    ];

    if (title != null) tags.add(['title', title!]);
    if (description != null) tags.add(['description', description!]);
    if (imageUrl != null) tags.add(['image', imageUrl!]);

    // Add video references as "a" tags
    for (final videoId in videoIds) {
      // Assuming videos are kind 22 (NIP-71)
      tags.add(['a', '22:$curatorPubkey:$videoId']);
    }

    return Event(
      curatorPubkey,
      eventKind,
      tags,
      description ?? '',
      createdAt: createdAt.millisecondsSinceEpoch ~/ 1000,
    );
  }

  @override
  String toString() {
    return 'CurationSet(id: $id, title: $title, curator: ${curatorPubkey.substring(0, 8)}..., videos: ${videoIds.length})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CurationSet &&
        other.id == id &&
        other.curatorPubkey == curatorPubkey;
  }

  @override
  int get hashCode => Object.hash(id, curatorPubkey);
}

/// Predefined curation set types for OpenVine
enum CurationSetType {
  editorsPicks('editors_picks', "Editor's Picks", "Curated collection from OpenVine"),
  trending('trending', 'Trending Now', 'Popular videos right now'),
  featured('featured', 'Featured', 'Highlighted content'),
  topWeekly('top_weekly', 'Top This Week', 'Most popular videos this week'),
  newAndNoteworthy('new_noteworthy', 'New & Noteworthy', 'Fresh content worth watching'),
  staffPicks('staff_picks', 'Staff Picks', 'Personal favorites from our team');

  const CurationSetType(this.id, this.displayName, this.description);

  final String id;
  final String displayName;
  final String description;
}

/// Sample curation sets for development/testing
class SampleCurationSets {
  static final List<CurationSet> _sampleSets = [
    CurationSet(
      id: CurationSetType.editorsPicks.id,
      curatorPubkey: '70ed6c56d6fb355f102a1e985741b5ee65f6ae9f772e028894b321bc74854082',
      title: CurationSetType.editorsPicks.displayName,
      description: CurationSetType.editorsPicks.description,
      imageUrl: 'https://example.com/editors-picks.jpg',
      videoIds: [], // Will be populated with actual video IDs
      createdAt: DateTime.now(),
    ),
    CurationSet(
      id: CurationSetType.trending.id,
      curatorPubkey: 'openvine_algorithm',
      title: CurationSetType.trending.displayName,
      description: CurationSetType.trending.description,
      videoIds: [], // Will be populated with trending video IDs
      createdAt: DateTime.now(),
    ),
    CurationSet(
      id: CurationSetType.featured.id,
      curatorPubkey: 'openvine_editorial_team',
      title: CurationSetType.featured.displayName,
      description: CurationSetType.featured.description,
      videoIds: [], // Will be populated with featured video IDs
      createdAt: DateTime.now(),
    ),
  ];

  static List<CurationSet> get all => List.unmodifiable(_sampleSets);

  static CurationSet? getById(String id) {
    try {
      return _sampleSets.firstWhere((set) => set.id == id);
    } catch (e) {
      return null;
    }
  }

  static CurationSet? getByType(CurationSetType type) {
    return getById(type.id);
  }
}