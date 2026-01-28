// ABOUTME: Data model for Vine drafts that users save before publishing
// ABOUTME: Includes video file path, metadata, publish status, and timestamps

import 'dart:convert';
import 'package:models/models.dart' show AspectRatio;
import 'package:models/models.dart' show NativeProofData;
import 'package:openvine/models/recording_clip.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

enum PublishStatus { draft, publishing, failed, published }

class VineDraft {
  const VineDraft({
    required this.id,
    required this.clips,
    required this.title,
    required this.description,
    required this.hashtags,
    required this.selectedApproach,
    required this.createdAt,
    required this.lastModified,
    required this.publishStatus,
    this.publishError,
    this.allowAudioReuse = false,
    this.expireTime,
    required this.publishAttempts,
    this.proofManifestJson,
  });

  factory VineDraft.create({
    required List<RecordingClip> clips,
    required String title,
    required String description,
    required Set<String> hashtags,
    required String selectedApproach,
    bool allowAudioReuse = false,
    Duration? expireTime,
    String? id,
    String? proofManifestJson,
  }) {
    final now = DateTime.now();
    return VineDraft(
      id: id ?? 'draft_${now.millisecondsSinceEpoch}',
      clips: clips,
      title: title,
      description: description,
      hashtags: hashtags,
      selectedApproach: selectedApproach,
      createdAt: now,
      lastModified: now,
      allowAudioReuse: allowAudioReuse,
      expireTime: expireTime,
      publishStatus: PublishStatus.draft,
      publishError: null,
      publishAttempts: 0,
      proofManifestJson: proofManifestJson,
    );
  }

  factory VineDraft.fromJson(Map<String, dynamic> json) {
    final List<RecordingClip> clips = [];

    // Backward compatibility: Handle old draft format with single videoFilePath
    // instead of the newer clips array format
    if (json['videoFilePath'] != null) {
      final now = DateTime.now();
      clips.add(
        RecordingClip(
          id: 'draft_${now.millisecondsSinceEpoch}',
          video: EditorVideo.file(json['videoFilePath']),
          duration: .zero,
          recordedAt: DateTime.parse(json['createdAt'] as String),
          aspectRatio: AspectRatio.values.firstWhere(
            (e) => e.name == json['aspectRatio'],
            orElse: () => .square,
          ),
        ),
      );
    } else {
      clips.addAll(
        List.from(
          json['clips'] ?? [],
        ).map((jsonClip) => RecordingClip.fromJson(jsonClip)),
      );
    }

    return VineDraft(
      id: json['id'] as String,
      clips: clips,
      title: json['title'] as String,
      description: json['description'] as String,
      hashtags: Set<String>.from(json['hashtags'] as Iterable),
      selectedApproach: json['selectedApproach'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      lastModified: DateTime.parse(json['lastModified'] as String),
      expireTime: json['expireTime'] != null
          ? Duration(milliseconds: json['expireTime'] as int)
          : null,
      publishStatus: json['publishStatus'] != null
          ? PublishStatus.values.byName(json['publishStatus'] as String)
          : PublishStatus.draft, // Migration: default for old drafts
      allowAudioReuse: json['allowAudioReuse'] ?? false,
      publishError: json['publishError'] as String?,
      publishAttempts: json['publishAttempts'] as int? ?? 0,
      proofManifestJson: json['proofManifestJson'] as String?,
    );
  }

  final List<RecordingClip> clips;
  final String id;
  final String title;
  final String description;
  final Set<String> hashtags;
  final String selectedApproach;
  final DateTime createdAt;
  final DateTime lastModified;
  final Duration? expireTime;
  final PublishStatus publishStatus;
  final String? proofManifestJson;
  final String? publishError;
  final int publishAttempts;
  final bool allowAudioReuse;

  /// Check if this draft has ProofMode data
  bool get hasProofMode => proofManifestJson != null;

  /// Get deserialized NativeProofData (null if not present or invalid JSON)
  /// This is the new ProofMode format using native libraries
  NativeProofData? get nativeProof {
    if (proofManifestJson == null) return null;
    try {
      final json = jsonDecode(proofManifestJson!);
      // Check if this is native proof data (has 'videoHash' field)
      if (json is Map<String, dynamic> && json.containsKey('videoHash')) {
        return NativeProofData.fromJson(json);
      }
      return null;
    } catch (e) {
      Log.error(
        'Failed to parse NativeProofData: $e',
        name: 'VineDraft',
        category: LogCategory.system,
      );
      return null;
    }
  }

  VineDraft copyWith({
    List<RecordingClip>? clips,
    String? title,
    String? description,
    Set<String>? hashtags,
    PublishStatus? publishStatus,
    Object? publishError = _sentinel,
    Duration? expireTime,
    bool? allowAudioReuse,
    int? publishAttempts,
    Object? proofManifestJson = _sentinel,
  }) => VineDraft(
    id: id,
    clips: clips ?? this.clips,
    title: title ?? this.title,
    description: description ?? this.description,
    hashtags: hashtags ?? this.hashtags,
    selectedApproach: selectedApproach,
    createdAt: createdAt,
    lastModified: DateTime.now(),
    expireTime: expireTime ?? this.expireTime,
    allowAudioReuse: allowAudioReuse ?? this.allowAudioReuse,
    publishStatus: publishStatus ?? this.publishStatus,
    publishError: publishError == _sentinel
        ? this.publishError
        : publishError as String?,
    publishAttempts: publishAttempts ?? this.publishAttempts,
    proofManifestJson: proofManifestJson == _sentinel
        ? this.proofManifestJson
        : proofManifestJson as String?,
  );

  static const _sentinel = Object();

  Map<String, dynamic> toJson() => {
    'id': id,
    'clips': clips.map((clip) => clip.toJson()).toList(),
    'title': title,
    'description': description,
    'hashtags': hashtags.toList(),
    'selectedApproach': selectedApproach,
    'createdAt': createdAt.toIso8601String(),
    'lastModified': lastModified.toIso8601String(),
    if (expireTime != null) 'expireTime': expireTime!.inMilliseconds,
    'allowAudioReuse': allowAudioReuse,
    'publishStatus': publishStatus.name,
    'publishError': publishError,
    'publishAttempts': publishAttempts,
    'proofManifestJson': proofManifestJson,
  };

  String get displayDuration {
    final duration = DateTime.now().difference(createdAt);
    if (duration.inDays > 0) {
      return '${duration.inDays}d ago';
    } else if (duration.inHours > 0) {
      return '${duration.inHours}h ago';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  bool get hasTitle => title.trim().isNotEmpty;
  bool get hasDescription => description.trim().isNotEmpty;
  bool get hasHashtags => hashtags.isNotEmpty;
  bool get canRetry => publishStatus == PublishStatus.failed;
  bool get isPublishing => publishStatus == PublishStatus.publishing;
}
