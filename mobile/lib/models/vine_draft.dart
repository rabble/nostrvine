// ABOUTME: Data model for Vine drafts that users save before publishing
// ABOUTME: Includes video file path, metadata, publish status, and timestamps

import 'dart:convert';
import 'package:models/models.dart' show AspectRatio;
import 'package:models/models.dart' show InspiredByInfo;
import 'package:models/models.dart' show NativeProofData;
import 'package:openvine/models/recording_clip.dart';
import 'package:openvine/utils/path_resolver.dart';
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
    this.editorStateHistory = const {},
    this.editorEditingParameters = const {},
    this.finalRenderedClip,
    this.collaboratorPubkeys = const [],
    this.inspiredByVideo,
    this.inspiredByNpub,
    this.selectedAudioEventId,
    this.selectedAudioRelay,
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
    Map<String, dynamic>? editorStateHistory,
    Map<String, dynamic>? editorEditingParameters,
    RecordingClip? finalRenderedClip,
    List<String> collaboratorPubkeys = const [],
    InspiredByInfo? inspiredByVideo,
    String? inspiredByNpub,
    String? selectedAudioEventId,
    String? selectedAudioRelay,
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
      editorStateHistory: editorStateHistory ?? const {},
      editorEditingParameters: editorEditingParameters ?? const {},
      finalRenderedClip: finalRenderedClip,
      collaboratorPubkeys: collaboratorPubkeys,
      inspiredByVideo: inspiredByVideo,
      inspiredByNpub: inspiredByNpub,
      selectedAudioEventId: selectedAudioEventId,
      selectedAudioRelay: selectedAudioRelay,
    );
  }

  factory VineDraft.fromJson(
    Map<String, dynamic> json,
    String documentsPath, {
    bool useOriginalPath = false,
  }) {
    final List<RecordingClip> clips = [];

    // Backward compatibility: Handle old draft format with single videoFilePath
    // instead of the newer clips array format
    if (json['videoFilePath'] != null) {
      final now = DateTime.now();
      final targetAspectRatio = AspectRatio.values.firstWhere(
        (e) => e.name == json['aspectRatio'],
        orElse: () => AspectRatio.square,
      );

      clips.add(
        RecordingClip(
          id: 'draft_${now.millisecondsSinceEpoch}',
          video: EditorVideo.file(
            resolvePath(
              json['videoFilePath'] as String,
              documentsPath,
              useOriginalPath: useOriginalPath,
            )!,
          ),
          duration: .zero,
          recordedAt: DateTime.parse(json['createdAt'] as String),
          originalAspectRatio: targetAspectRatio.value,
          targetAspectRatio: targetAspectRatio,
        ),
      );
    } else {
      clips.addAll(
        List.from(json['clips'] ?? []).map(
          (jsonClip) => RecordingClip.fromJson(
            jsonClip,
            documentsPath,
            useOriginalPath: useOriginalPath,
          ),
        ),
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
      editorStateHistory:
          (json['editorStateHistory'] as Map<String, dynamic>?) ?? const {},
      editorEditingParameters:
          (json['editorEditingParameters'] as Map<String, dynamic>?) ??
          const {},
      finalRenderedClip: json['finalRenderedClip'] != null
          ? RecordingClip.fromJson(
              json['finalRenderedClip'] as Map<String, dynamic>,
              documentsPath,
              useOriginalPath: useOriginalPath,
            )
          : null,
      collaboratorPubkeys: json['collaboratorPubkeys'] != null
          ? List<String>.from(json['collaboratorPubkeys'] as Iterable)
          : const [],
      inspiredByVideo: json['inspiredByVideo'] != null
          ? InspiredByInfo.fromJson(
              json['inspiredByVideo'] as Map<String, dynamic>,
            )
          : null,
      inspiredByNpub: json['inspiredByNpub'] as String?,
      selectedAudioEventId: json['selectedAudioEventId'] as String?,
      selectedAudioRelay: json['selectedAudioRelay'] as String?,
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

  final Map<String, dynamic> editorStateHistory;
  final Map<String, dynamic> editorEditingParameters;

  /// The final rendered clip ready for publishing.
  /// Cached to avoid re-rendering when no changes are made.
  final RecordingClip? finalRenderedClip;

  /// Pubkeys of collaborators tagged in this video.
  final List<String> collaboratorPubkeys;

  /// Reference to a specific video that inspired this one (a-tag).
  final InspiredByInfo? inspiredByVideo;

  /// NIP-27 npub reference for general "Inspired By" a creator.
  final String? inspiredByNpub;

  /// Event ID of a selected existing audio event to reference.
  final String? selectedAudioEventId;

  /// Relay hint for the selected audio event.
  final String? selectedAudioRelay;

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
    String? id,
    String? title,
    String? description,
    Set<String>? hashtags,
    PublishStatus? publishStatus,
    Object? publishError = _sentinel,
    Duration? expireTime,
    bool? allowAudioReuse,
    int? publishAttempts,
    Object? proofManifestJson = _sentinel,
    Map<String, dynamic>? editorStateHistory,
    Map<String, dynamic>? editorEditingParameters,
    Object? finalRenderedClip = _sentinel,
    List<String>? collaboratorPubkeys,
    InspiredByInfo? inspiredByVideo,
    String? inspiredByNpub,
    Object? selectedAudioEventId = _sentinel,
    Object? selectedAudioRelay = _sentinel,
  }) => VineDraft(
    id: id ?? this.id,
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
    editorStateHistory: editorStateHistory ?? this.editorStateHistory,
    editorEditingParameters:
        editorEditingParameters ?? this.editorEditingParameters,
    finalRenderedClip: finalRenderedClip == _sentinel
        ? this.finalRenderedClip
        : finalRenderedClip as RecordingClip?,
    collaboratorPubkeys: collaboratorPubkeys ?? this.collaboratorPubkeys,
    inspiredByVideo: inspiredByVideo ?? this.inspiredByVideo,
    inspiredByNpub: inspiredByNpub ?? this.inspiredByNpub,
    selectedAudioEventId: selectedAudioEventId == _sentinel
        ? this.selectedAudioEventId
        : selectedAudioEventId as String?,
    selectedAudioRelay: selectedAudioRelay == _sentinel
        ? this.selectedAudioRelay
        : selectedAudioRelay as String?,
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
    if (editorStateHistory.isNotEmpty) 'editorStateHistory': editorStateHistory,
    if (editorEditingParameters.isNotEmpty)
      'editorEditingParameters': editorEditingParameters,
    if (finalRenderedClip != null)
      'finalRenderedClip': finalRenderedClip!.toJson(),
    if (collaboratorPubkeys.isNotEmpty)
      'collaboratorPubkeys': collaboratorPubkeys,
    if (inspiredByVideo != null) 'inspiredByVideo': inspiredByVideo!.toJson(),
    if (inspiredByNpub != null) 'inspiredByNpub': inspiredByNpub,
    if (selectedAudioEventId != null)
      'selectedAudioEventId': selectedAudioEventId,
    if (selectedAudioRelay != null) 'selectedAudioRelay': selectedAudioRelay,
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
