// ABOUTME: AudioEvent model for NIP-94 Kind 1063 audio file
// ABOUTME: metadata events. Used for audio reuse feature -
// ABOUTME: parsing audio shared for use in other videos

import 'package:meta/meta.dart';
import 'package:models/src/video_event.dart';
import 'package:models/src/vine_sound.dart';
import 'package:nostr_sdk/event.dart';

/// Kind number for audio file metadata events (NIP-94)
const int audioEventKind = 1063;

/// The kind of underlying media source backing an [AudioEvent].
///
/// Used to pick the correct loading strategy: a bundled [asset], an
/// on-disk [file] (imported audio), or a remote [network] URL.
enum AudioSourceKind {
  /// Bundled app asset. The resolved path is the bare asset path, with the
  /// `asset://` scheme stripped.
  asset,

  /// Local file on disk (imported audio).
  file,

  /// Remote `http`/`https` URL.
  network,
}

/// Represents an audio file metadata event (Kind 1063)
/// for the audio reuse feature.
///
/// Published when a user opts in to make their audio available for reuse.
/// Contains metadata about the audio file including URL, MIME type, duration,
/// and a reference to the source video (Kind 34236).
///
/// See NIP-94 for the full file metadata specification.
@immutable
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
    this.source,
    this.sourceVideoReference,
    this.sourceVideoRelay,
    this.externalSource,
    this.startOffset = Duration.zero,
    this.volume = 1.0,
    this.startTime = Duration.zero,
    this.endTime,
    this.anchorClipId,
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
    String? source;
    String? sourceVideoReference;
    String? sourceVideoRelay;

    // Parse tags according to NIP-94
    for (final tagRaw in event.tags) {
      if (tagRaw.isEmpty) continue;

      final tag = tagRaw.map((e) => e).toList();
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
        case 'source':
          source = tagValue.isNotEmpty ? tagValue : null;
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
      source: source,
      sourceVideoReference: sourceVideoReference,
      sourceVideoRelay: sourceVideoRelay,
    );
  }

  /// Create an AudioEvent from a bundled VineSound asset.
  ///
  /// Uses a special `asset://` URL scheme to indicate this is a bundled sound.
  /// The ID is prefixed with [bundledMarker] to distinguish from Nostr events.
  ///
  /// Usage:
  /// ```dart
  /// final audioEvent = AudioEvent.fromBundledSound(vineSound);
  /// if (audioEvent.isBundled) {
  ///   // Play from assets
  /// }
  /// ```
  factory AudioEvent.fromBundledSound(VineSound sound, {int index = 0}) {
    String? source;
    if (sound.artist != null) {
      source =
          sound.sourceUrl != null && sound.sourceUrl!.contains('freesound.org')
          ? '${sound.artist} via Freesound'
          : sound.artist;
    }

    return AudioEvent(
      id: '${bundledMarker}_${sound.id}',
      pubkey: bundledMarker, // Indicates this is not from a Nostr user
      createdAt: index, // List position as recency proxy
      url: 'asset://${sound.assetPath}',
      mimeType: 'audio/mpeg',
      duration: sound.durationInSeconds,
      title: sound.title,
      source: source,
    );
  }

  /// Create a synthetic AudioEvent from a video's audio track.
  ///
  /// Uses the video URL as the audio source. The audio player can extract
  /// the audio track from video files. The ID is prefixed with `video_`
  /// to distinguish from real Kind 1063 events.
  factory AudioEvent.fromVideoOriginalSound(
    VideoEvent video, {
    required String creatorName,
  }) {
    return AudioEvent(
      id: 'video_${video.id}',
      pubkey: video.pubkey,
      createdAt: video.createdAt,
      url: video.videoUrl,
      duration: video.duration?.toDouble(),
      title: 'Original sound - $creatorName',
      source: 'Original Sound',
      sourceVideoReference: '34236:${video.pubkey}:${video.vineId ?? video.id}',
    );
  }

  /// Create a draft-local AudioEvent for an imported audio file.
  factory AudioEvent.fromLocalImport({
    required String id,
    required String filePath,
    required int createdAt,
    required String title,
    required String mimeType,
    double? duration,
  }) {
    return AudioEvent(
      id: id,
      pubkey: localImportMarker,
      createdAt: createdAt,
      url: filePath,
      mimeType: mimeType,
      duration: duration,
      title: title,
      source: 'Imported audio',
    );
  }

  /// Deserialize from JSON for draft restoration.
  factory AudioEvent.fromJson(Map<String, dynamic> json) {
    return AudioEvent(
      id: json['id'] as String,
      pubkey: json['pubkey'] as String,
      createdAt: json['createdAt'] as int,
      url: json['url'] as String?,
      mimeType: json['mimeType'] as String?,
      sha256: json['sha256'] as String?,
      fileSize: json['fileSize'] as int?,
      duration: json['duration'] as double?,
      title: json['title'] as String?,
      source: json['source'] as String?,
      sourceVideoReference: json['sourceVideoReference'] as String?,
      sourceVideoRelay: json['sourceVideoRelay'] as String?,
      externalSource: _parseExternalSource(json['externalSource']),
      startOffset: json['startOffsetMs'] != null
          ? Duration(milliseconds: json['startOffsetMs'] as int)
          : Duration.zero,
      volume: (json['volume'] as num?)?.toDouble() ?? 1.0,
      startTime: json['startTimeMs'] != null
          ? Duration(milliseconds: json['startTimeMs'] as int)
          : Duration.zero,
      endTime: json['endTimeMs'] != null
          ? Duration(milliseconds: json['endTimeMs'] as int)
          : null,
      anchorClipId: json['anchorClipId'] as String?,
    );
  }

  /// Marker for bundled sounds to distinguish from Nostr events.
  /// Used as ID prefix (with underscore) and as pubkey value.
  static const bundledMarker = 'bundled';

  /// Marker for draft-local imported audio.
  static const localImportMarker = 'local_import';

  /// Marker for sounds resolved from server-side external provider search.
  static const externalProviderMarker = 'external_provider';

  /// Whether this audio is derived from a video's original sound.
  bool get isOriginalSound => id.startsWith('video_');

  /// Whether this track is a video's original sound that is still anchored to
  /// one of the editor's clips.
  ///
  /// Clip-anchored original sound is controlled through its source clip's
  /// volume arc, so the timeline volume panel hides its individual arc. A
  /// standalone original sound the user *added* from another video
  /// (`anchorClipId == null`) is not clip-anchored and therefore keeps its
  /// own volume arc — unlike [isOriginalSound] alone, which would also hide
  /// those added tracks.
  bool get isClipAnchoredOriginalSound => isOriginalSound && isAnchored;

  /// Whether this audio is a bundled sound (from app assets).
  bool get isBundled => id.startsWith('${bundledMarker}_');

  /// Whether this audio is a draft-local imported file.
  bool get isLocalImport => id.startsWith('${localImportMarker}_');

  /// Local file path for imported audio.
  ///
  /// Returns null for bundled and published Nostr audio.
  String? get localFilePath {
    if (!isLocalImport || url == null || url!.isEmpty) return null;
    return url;
  }

  /// Whether this audio came from a normalized external sound provider.
  bool get isExternalProviderSound => externalSource != null;

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

  /// Classifies the playable source for this audio and returns the matching
  /// path, or `null` when no usable source exists.
  ///
  /// Imported audio stores its on-disk path in [url]; it must be loaded as a
  /// file rather than parsed as a network URL (which fails with "No host
  /// specified in URI" / iOS "unsupported URL"). Bundled sounds expose a bare
  /// asset path. Bare absolute paths (`/var/mobile/...`) and `file://` URIs —
  /// e.g. clip-extracted J-cut audio whose [url] is a raw on-disk path — are
  /// also classified as files, matching the `#4395` file-vs-network guard used
  /// at the duration/render/waveform call sites so this getter is a true
  /// superset they can migrate onto without reintroducing that bug. Everything
  /// else (`http(s)`, plus unhandled schemes like `content://`/`blob:`) is
  /// network.
  ({AudioSourceKind kind, String path})? get resolvedSource {
    if (isBundled) {
      final path = assetPath;
      return path == null || path.isEmpty
          ? null
          : (kind: AudioSourceKind.asset, path: path);
    }
    if (isLocalImport) {
      final path = localFilePath;
      return path == null || path.isEmpty
          ? null
          : (kind: AudioSourceKind.file, path: path);
    }
    final rawUrl = url;
    if (rawUrl == null || rawUrl.isEmpty) return null;
    final parsed = Uri.tryParse(rawUrl);
    final isLocalFile =
        parsed == null ||
        parsed.scheme.isEmpty ||
        parsed.scheme == 'file' ||
        rawUrl.startsWith('/');
    if (isLocalFile) {
      final filePath = parsed != null && parsed.scheme == 'file'
          ? parsed.toFilePath()
          : rawUrl;
      return (kind: AudioSourceKind.file, path: filePath);
    }
    return (kind: AudioSourceKind.network, path: rawUrl);
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

  /// Source attribution (e.g., "Original Sound", "Spotify", "SoundCloud").
  final String? source;

  /// Addressable reference to source video in format "kind:pubkey:d-tag".
  /// For OpenVine videos: `34236:<pubkey>:<vine-id>`
  final String? sourceVideoReference;

  /// Optional relay hint for the source video.
  final String? sourceVideoRelay;

  /// Normalized source, attribution, and license metadata for proxy-backed
  /// sounds from Freesound, Openverse, or future providers.
  final AudioExternalSource? externalSource;

  /// Start offset within the audio track.
  ///
  /// This is the point from which the audio will start
  /// playing during video playback. Default is
  /// [Duration.zero] (start from beginning). Only used
  /// locally, not published to Nostr.
  final Duration startOffset;

  /// Volume of the audio track (0.0 silent, 1.0 full).
  final double volume;

  /// The time on the editor timeline where this audio event starts playing.
  /// Default is [Duration.zero] (start of the timeline).
  final Duration startTime;

  /// The time on the editor timeline where this audio event stops playing.
  /// If null, the audio plays until the end of its duration.
  final Duration? endTime;

  /// ID of the `DivineVideoClip` this audio was extracted from and is
  /// currently anchored to.
  ///
  /// When non-null, the audio is "anchored": editing the source clip's
  /// trim (e.g. trimming its left edge) keeps the audio aligned with the
  /// clip's source content so a J-Cut can be created without losing sync.
  /// Set when audio is extracted from a clip; cleared (set to `null`) when
  /// the user manually moves the audio on the timeline, after which it
  /// behaves as an independent, free-floating track.
  ///
  /// Local-only editor state, never published to Nostr.
  final String? anchorClipId;

  /// Whether this audio is currently anchored to a source video clip.
  bool get isAnchored => anchorClipId != null;

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

    if (source != null) {
      tags.add(['source', source!]);
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
    String? source,
    String? sourceVideoReference,
    String? sourceVideoRelay,
    AudioExternalSource? externalSource,
    Duration? startOffset,
    double? volume,
    Duration? startTime,
    Duration? endTime,
    String? anchorClipId,
    bool clearAnchorClipId = false,
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
      source: source ?? this.source,
      sourceVideoReference: sourceVideoReference ?? this.sourceVideoReference,
      sourceVideoRelay: sourceVideoRelay ?? this.sourceVideoRelay,
      externalSource: externalSource ?? this.externalSource,
      startOffset: startOffset ?? this.startOffset,
      volume: volume ?? this.volume,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      anchorClipId: clearAnchorClipId
          ? null
          : (anchorClipId ?? this.anchorClipId),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AudioEvent &&
        other.id == id &&
        other.startOffset == startOffset &&
        other.startTime == startTime &&
        other.endTime == endTime &&
        other.anchorClipId == anchorClipId;
  }

  @override
  int get hashCode =>
      Object.hash(id, startOffset, startTime, endTime, anchorClipId);

  @override
  String toString() {
    return 'AudioEvent('
        'id: $id, '
        'title: $title, '
        'duration: $duration'
        ')';
  }

  /// Serialize to JSON for draft persistence.
  Map<String, dynamic> toJson() => {
    'id': id,
    'pubkey': pubkey,
    'createdAt': createdAt,
    'url': ?url,
    'mimeType': ?mimeType,
    'sha256': ?sha256,
    'fileSize': ?fileSize,
    'duration': ?duration,
    'title': ?title,
    'source': ?source,
    'sourceVideoReference': ?sourceVideoReference,
    'sourceVideoRelay': ?sourceVideoRelay,
    // Always serialize volume so history and draft snapshots preserve
    // explicit user edits instead of relying on an implicit default.
    'volume': volume,
    if (externalSource != null) 'externalSource': externalSource!.toJson(),
    if (startOffset != .zero) 'startOffsetMs': startOffset.inMilliseconds,
    if (startTime != Duration.zero) 'startTimeMs': startTime.inMilliseconds,
    if (endTime != null) 'endTimeMs': endTime!.inMilliseconds,
    'anchorClipId': ?anchorClipId,
  };
}

AudioExternalSource? _parseExternalSource(Object? value) {
  if (value is! Map<String, dynamic>) {
    return null;
  }
  return AudioExternalSource.fromJson(value);
}

/// Normalized metadata for a sound result served by the sound library proxy.
@immutable
class AudioExternalSource {
  const AudioExternalSource({
    required this.provider,
    required this.providerSoundId,
    required this.providerName,
    required this.license,
    this.creatorName,
    this.creatorUrl,
    this.sourceUrl,
    this.previewUrl,
  });

  factory AudioExternalSource.fromJson(Map<String, dynamic> json) {
    final licenseJson = json['license'];
    if (licenseJson is! Map<String, dynamic>) {
      throw const FormatException('External audio source missing license');
    }

    return AudioExternalSource(
      provider: json['provider'] as String,
      providerSoundId: json['providerSoundId'] as String,
      providerName: json['providerName'] as String,
      creatorName: json['creatorName'] as String?,
      creatorUrl: json['creatorUrl'] as String?,
      sourceUrl: json['sourceUrl'] as String?,
      previewUrl: json['previewUrl'] as String?,
      license: AudioLicenseMetadata.fromJson(licenseJson),
    );
  }

  final String provider;
  final String providerSoundId;
  final String providerName;
  final String? creatorName;
  final String? creatorUrl;
  final String? sourceUrl;
  final String? previewUrl;
  final AudioLicenseMetadata license;

  Map<String, dynamic> toJson() => {
    'provider': provider,
    'providerSoundId': providerSoundId,
    'providerName': providerName,
    'creatorName': ?creatorName,
    'creatorUrl': ?creatorUrl,
    'sourceUrl': ?sourceUrl,
    'previewUrl': ?previewUrl,
    'license': license.toJson(),
  };

  @override
  bool operator ==(Object other) {
    return other is AudioExternalSource &&
        other.provider == provider &&
        other.providerSoundId == providerSoundId &&
        other.providerName == providerName &&
        other.creatorName == creatorName &&
        other.creatorUrl == creatorUrl &&
        other.sourceUrl == sourceUrl &&
        other.previewUrl == previewUrl &&
        other.license == license;
  }

  @override
  int get hashCode => Object.hash(
    provider,
    providerSoundId,
    providerName,
    creatorName,
    creatorUrl,
    sourceUrl,
    previewUrl,
    license,
  );
}

/// License metadata that has already been normalized by the sound proxy.
@immutable
class AudioLicenseMetadata {
  const AudioLicenseMetadata({
    required this.type,
    required this.name,
    required this.url,
    required this.allowsCommercialUse,
    required this.allowsDerivatives,
    required this.requiresAttribution,
  });

  factory AudioLicenseMetadata.fromJson(Map<String, dynamic> json) {
    return AudioLicenseMetadata(
      type: json['type'] as String,
      name: json['name'] as String,
      url: json['url'] as String,
      allowsCommercialUse: json['allowsCommercialUse'] as bool,
      allowsDerivatives: json['allowsDerivatives'] as bool? ?? true,
      requiresAttribution: json['requiresAttribution'] as bool,
    );
  }

  final String type;
  final String name;
  final String url;
  final bool allowsCommercialUse;
  final bool allowsDerivatives;
  final bool requiresAttribution;

  Map<String, dynamic> toJson() => {
    'type': type,
    'name': name,
    'url': url,
    'allowsCommercialUse': allowsCommercialUse,
    'allowsDerivatives': allowsDerivatives,
    'requiresAttribution': requiresAttribution,
  };

  @override
  bool operator ==(Object other) {
    return other is AudioLicenseMetadata &&
        other.type == type &&
        other.name == name &&
        other.url == url &&
        other.allowsCommercialUse == allowsCommercialUse &&
        other.allowsDerivatives == allowsDerivatives &&
        other.requiresAttribution == requiresAttribution;
  }

  @override
  int get hashCode => Object.hash(
    type,
    name,
    url,
    allowsCommercialUse,
    allowsDerivatives,
    requiresAttribution,
  );
}
