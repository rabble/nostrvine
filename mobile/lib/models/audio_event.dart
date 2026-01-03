// ABOUTME: AudioEvent model for NIP-94 Kind 1063 audio file metadata events
// ABOUTME: Used for audio reuse feature - parsing audio shared for use in other videos

import 'package:nostr_sdk/event.dart';
import 'package:openvine/models/vine_sound.dart';

/// Kind number for audio file metadata events (NIP-94)
const int audioEventKind = 1063;

/// Represents an audio file metadata event (Kind 1063) for the audio reuse feature.
///
/// Published when a user opts in to make their audio available for reuse.
/// Contains metadata about the audio file including URL, MIME type, duration,
/// and a reference to the source video (Kind 34236).
///
/// See NIP-94 for the full file metadata specification.
class AudioEvent {
  /// Creates a new AudioEvent with the specified fields.
  const AudioEvent({
    required this.id,
    required this.pubkey,
    required this.createdAt,
    this.url,
    this.mimeType,
    this.sha256,
    this.fileSize,
    this.duration,
    this.title,
    this.sourceVideoReference,
    this.sourceVideoRelay,
  });

  /// Parse an AudioEvent from a Nostr Event.
  ///
  /// Throws [ArgumentError] if the event is not Kind 1063.
  /// Follows Postel's law: be liberal in what you accept from others.
  factory AudioEvent.fromNostrEvent(Event event) {
    if (event.kind != audioEventKind) {
      throw ArgumentError(
        'Event must be Kind $audioEventKind (audio file metadata), '
        'got Kind ${event.kind}',
      );
    }

    String? url;
    String? mimeType;
    String? sha256;
    int? fileSize;
    double? duration;
    String? title;
    String? sourceVideoReference;
    String? sourceVideoRelay;

    // Parse tags according to NIP-94
    for (final tagRaw in event.tags) {
      if (tagRaw is! List || tagRaw.isEmpty) continue;

      final tag = tagRaw.map((e) => e.toString()).toList();
      final tagName = tag[0];
      final tagValue = tag.length > 1 ? tag[1] : '';

      switch (tagName) {
        case 'url':
          url = tagValue.isNotEmpty ? tagValue : null;
        case 'm':
          mimeType = tagValue.isNotEmpty ? tagValue : null;
        case 'x':
          sha256 = tagValue.isNotEmpty ? tagValue : null;
        case 'size':
          fileSize = int.tryParse(tagValue);
        case 'duration':
          duration = double.tryParse(tagValue);
        case 'title':
          title = tagValue.isNotEmpty ? tagValue : null;
        case 'a':
          // Addressable reference to source video: "34236:<pubkey>:<d-tag>"
          sourceVideoReference = tagValue.isNotEmpty ? tagValue : null;
          // Optional relay hint is the third element
          if (tag.length > 2 && tag[2].isNotEmpty) {
            sourceVideoRelay = tag[2];
          }
      }
    }

    return AudioEvent(
      id: event.id,
      pubkey: event.pubkey,
      createdAt: event.createdAt,
      url: url,
      mimeType: mimeType,
      sha256: sha256,
      fileSize: fileSize,
      duration: duration,
      title: title,
      sourceVideoReference: sourceVideoReference,
      sourceVideoRelay: sourceVideoRelay,
    );
  }

  /// Create an AudioEvent from a bundled VineSound asset.
  ///
  /// Uses a special `asset://` URL scheme to indicate this is a bundled sound.
  /// The ID is prefixed with `bundled_` to distinguish from Nostr events.
  ///
  /// Usage:
  /// ```dart
  /// final audioEvent = AudioEvent.fromBundledSound(vineSound);
  /// if (audioEvent.isBundled) {
  ///   // Play from assets
  /// }
  /// ```
  factory AudioEvent.fromBundledSound(VineSound sound) {
    return AudioEvent(
      id: 'bundled_${sound.id}',
      pubkey: 'bundled', // Indicates this is not from a Nostr user
      createdAt: 0, // No timestamp for bundled sounds
      url: 'asset://${sound.assetPath}',
      mimeType: 'audio/mpeg',
      duration: sound.durationInSeconds,
      title: sound.title,
    );
  }

  /// Whether this audio is a bundled sound (from app assets).
  bool get isBundled => id.startsWith('bundled_');

  /// Get the asset path for bundled sounds.
  /// Returns null if this is not a bundled sound.
  String? get assetPath {
    if (!isBundled || url == null) return null;
    const prefix = 'asset://';
    if (url!.startsWith(prefix)) {
      return url!.substring(prefix.length);
    }
    return null;
  }

  /// The Nostr event ID (64-character hex string).
  final String id;

  /// The public key of the audio creator.
  final String pubkey;

  /// Unix timestamp when the event was created.
  final int createdAt;

  /// Blossom audio file URL.
  final String? url;

  /// MIME type of the audio file (e.g., "audio/aac", "audio/mp4").
  final String? mimeType;

  /// SHA-256 hash of the audio file.
  final String? sha256;

  /// File size in bytes.
  final int? fileSize;

  /// Duration in seconds.
  final double? duration;

  /// Audio title (e.g., "Original sound - @username").
  final String? title;

  /// Addressable reference to source video in format "kind:pubkey:d-tag".
  /// For OpenVine videos: "34236:<pubkey>:<vine-id>"
  final String? sourceVideoReference;

  /// Optional relay hint for the source video.
  final String? sourceVideoRelay;

  /// Get the kind number from the source video reference.
  /// Returns null if no source video reference is set.
  int? get sourceVideoKind {
    if (sourceVideoReference == null) return null;
    final parts = sourceVideoReference!.split(':');
    if (parts.isEmpty) return null;
    return int.tryParse(parts[0]);
  }

  /// Get the pubkey from the source video reference.
  /// Returns null if no source video reference is set or format is invalid.
  String? get sourceVideoPubkey {
    if (sourceVideoReference == null) return null;
    final parts = sourceVideoReference!.split(':');
    if (parts.length < 2) return null;
    return parts[1];
  }

  /// Get the d-tag identifier from the source video reference.
  /// Returns null if no source video reference is set or format is invalid.
  String? get sourceVideoIdentifier {
    if (sourceVideoReference == null) return null;
    final parts = sourceVideoReference!.split(':');
    if (parts.length < 3) return null;
    return parts[2];
  }

  /// Get formatted duration string (e.g., "0:06", "1:05").
  /// Returns empty string if duration is null.
  String get formattedDuration {
    if (duration == null) return '';
    final totalSeconds = duration!.round();
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  /// Get file size in kilobytes.
  /// Returns null if file size is not set.
  double? get fileSizeKB {
    if (fileSize == null) return null;
    return fileSize! / 1024.0;
  }

  /// Generate tags list for publishing this audio event.
  ///
  /// Only includes tags for non-null fields.
  List<List<String>> toTags() {
    final tags = <List<String>>[];

    if (url != null) {
      tags.add(['url', url!]);
    }

    if (mimeType != null) {
      tags.add(['m', mimeType!]);
    }

    if (sha256 != null) {
      tags.add(['x', sha256!]);
    }

    if (fileSize != null) {
      tags.add(['size', fileSize.toString()]);
    }

    if (duration != null) {
      tags.add(['duration', duration.toString()]);
    }

    if (title != null) {
      tags.add(['title', title!]);
    }

    if (sourceVideoReference != null) {
      if (sourceVideoRelay != null) {
        tags.add(['a', sourceVideoReference!, sourceVideoRelay!]);
      } else {
        tags.add(['a', sourceVideoReference!]);
      }
    }

    return tags;
  }

  /// Create a copy with updated fields.
  AudioEvent copyWith({
    String? id,
    String? pubkey,
    int? createdAt,
    String? url,
    String? mimeType,
    String? sha256,
    int? fileSize,
    double? duration,
    String? title,
    String? sourceVideoReference,
    String? sourceVideoRelay,
  }) {
    return AudioEvent(
      id: id ?? this.id,
      pubkey: pubkey ?? this.pubkey,
      createdAt: createdAt ?? this.createdAt,
      url: url ?? this.url,
      mimeType: mimeType ?? this.mimeType,
      sha256: sha256 ?? this.sha256,
      fileSize: fileSize ?? this.fileSize,
      duration: duration ?? this.duration,
      title: title ?? this.title,
      sourceVideoReference: sourceVideoReference ?? this.sourceVideoReference,
      sourceVideoRelay: sourceVideoRelay ?? this.sourceVideoRelay,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AudioEvent && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'AudioEvent('
        'id: $id, '
        'title: $title, '
        'duration: $duration'
        ')';
  }
}
