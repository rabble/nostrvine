// ABOUTME: Data model for Vine drafts that users save before publishing
// ABOUTME: Includes video file path, metadata, publish status, and timestamps

import 'dart:convert';

import 'package:db_client/db_client.dart';
import 'package:models/models.dart' show AspectRatio;
import 'package:models/models.dart' show InspiredByInfo;
import 'package:models/models.dart' show NativeProofData;
import 'package:openvine/models/audio_event.dart';
import 'package:openvine/models/content_label.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/utils/path_resolver.dart';
import 'package:pro_video_editor/pro_video_editor.dart';
import 'package:unified_logger/unified_logger.dart';

enum PublishStatus { draft, publishing, failed, published }

class DivineVideoDraft {
  const DivineVideoDraft({
    required this.id,
    required this.clips,
    required this.title,
    required this.description,
    required this.hashtags,
    required this.selectedApproach,
    required this.createdAt,
    required this.lastModified,
    required this.publishStatus,
    required this.publishAttempts,
    this.publishError,
    this.allowAudioReuse = true,
    this.expireTime,
    this.proofManifestJson,
    this.editorStateHistory = const {},
    this.editorEditingParameters = const {},
    this.finalRenderedClip,
    this.collaboratorPubkeys = const {},
    this.inspiredByVideo,
    this.inspiredByNpub,
    this.selectedSound,
    this.contentWarning,
    this.originalAudioVolume = 1.0,
    this.customAudioVolume = 1.0,
  });

  factory DivineVideoDraft.create({
    required List<DivineVideoClip> clips,
    required String title,
    required String description,
    required Set<String> hashtags,
    required String selectedApproach,
    bool allowAudioReuse = true,
    Duration? expireTime,
    String? id,
    String? proofManifestJson,
    Map<String, dynamic>? editorStateHistory,
    Map<String, dynamic>? editorEditingParameters,
    DivineVideoClip? finalRenderedClip,
    Set<String> collaboratorPubkeys = const {},
    InspiredByInfo? inspiredByVideo,
    String? inspiredByNpub,
    AudioEvent? selectedSound,
    String? contentWarning,
    double originalAudioVolume = 1.0,
    double customAudioVolume = 1.0,
  }) {
    final now = DateTime.now();
    return DivineVideoDraft(
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
      publishAttempts: 0,
      proofManifestJson: proofManifestJson,
      editorStateHistory: editorStateHistory ?? const {},
      editorEditingParameters: editorEditingParameters ?? const {},
      finalRenderedClip: finalRenderedClip,
      collaboratorPubkeys: collaboratorPubkeys,
      inspiredByVideo: inspiredByVideo,
      inspiredByNpub: inspiredByNpub,
      selectedSound: selectedSound,
      contentWarning: contentWarning,
      originalAudioVolume: originalAudioVolume,
      customAudioVolume: customAudioVolume,
    );
  }

  factory DivineVideoDraft.fromJson(
    Map<String, dynamic> json,
    String documentsPath, {
    bool useOriginalPath = false,
  }) {
    final List<DivineVideoClip> clips = [];

    // Backward compatibility: Handle old draft format with single videoFilePath
    // instead of the newer clips array format
    if (json['videoFilePath'] != null) {
      final now = DateTime.now();
      final targetAspectRatio = AspectRatio.values.firstWhere(
        (e) => e.name == json['aspectRatio'],
        orElse: () => AspectRatio.square,
      );

      clips.add(
        DivineVideoClip(
          id: 'draft_${now.millisecondsSinceEpoch}',
          video: EditorVideo.file(
            resolvePath(
              json['videoFilePath'] as String,
              documentsPath,
              useOriginalPath: useOriginalPath,
            ),
          ),
          duration: .zero,
          recordedAt: DateTime.parse(json['createdAt'] as String),
          originalAspectRatio: targetAspectRatio.value,
          targetAspectRatio: targetAspectRatio,
        ),
      );
    } else {
      clips.addAll(
        List.from(json['clips'] as Iterable? ?? []).map(
          (jsonClip) => DivineVideoClip.fromJson(
            jsonClip as Map<String, dynamic>,
            documentsPath,
            useOriginalPath: useOriginalPath,
          ),
        ),
      );
    }

    return DivineVideoDraft(
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
      allowAudioReuse: json['allowAudioReuse'] as bool? ?? true,
      publishError: json['publishError'] as String?,
      publishAttempts: json['publishAttempts'] as int? ?? 0,
      proofManifestJson: json['proofManifestJson'] as String?,
      editorStateHistory:
          (json['editorStateHistory'] as Map<String, dynamic>?) ?? const {},
      editorEditingParameters:
          (json['editorEditingParameters'] as Map<String, dynamic>?) ??
          const {},
      finalRenderedClip: json['finalRenderedClip'] != null
          ? DivineVideoClip.fromJson(
              json['finalRenderedClip'] as Map<String, dynamic>,
              documentsPath,
              useOriginalPath: useOriginalPath,
            )
          : null,
      collaboratorPubkeys: json['collaboratorPubkeys'] != null
          ? Set<String>.from(json['collaboratorPubkeys'] as Iterable)
          : const {},
      inspiredByVideo: json['inspiredByVideo'] != null
          ? InspiredByInfo.fromJson(
              json['inspiredByVideo'] as Map<String, dynamic>,
            )
          : null,
      inspiredByNpub: json['inspiredByNpub'] as String?,
      // New format: full AudioEvent object
      // Old format (selectedAudioEventId/selectedAudioRelay) is ignored -
      // user must re-select sound if loading old draft
      selectedSound: json['selectedSound'] != null
          ? AudioEvent.fromJson(json['selectedSound'] as Map<String, dynamic>)
          : null,
      contentWarning: json['contentWarning'] as String?,
      originalAudioVolume:
          (json['originalAudioVolume'] as num?)?.toDouble() ?? 1.0,
      customAudioVolume: (json['customAudioVolume'] as num?)?.toDouble() ?? 1.0,
    );
  }

  factory DivineVideoDraft.fromDriftRow({
    required DraftRow row,
    required List<ClipRow> clipRows,
    required String documentsPath,
  }) {
    final draftJson = json.decode(row.data) as Map<String, dynamic>;

    // Reconstruct clips from clip rows
    final clips = clipRows.map((clipRow) {
      final clipJson = json.decode(clipRow.data) as Map<String, dynamic>;
      return DivineVideoClip.fromJson(clipJson, documentsPath);
    }).toList();

    final draft = DivineVideoDraft.fromJson(draftJson, documentsPath);
    return draft.copyWith(clips: clips, skipUpdateLastModified: true);
  }

  final List<DivineVideoClip> clips;
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
  final DivineVideoClip? finalRenderedClip;

  /// Pubkeys of collaborators tagged in this video.
  final Set<String> collaboratorPubkeys;

  /// Reference to a specific video that inspired this one (a-tag).
  final InspiredByInfo? inspiredByVideo;

  /// NIP-27 npub reference for general "Inspired By" a creator.
  final String? inspiredByNpub;

  /// Currently selected audio event for the video.
  /// Contains the full AudioEvent data including URL, title, and start offset.
  /// Persisted to drafts so the sound selection survives app restarts.
  final AudioEvent? selectedSound;

  /// Comma-separated NIP-32 content warning labels for this video.
  final String? contentWarning;

  /// Volume level for the original video audio track (0.0 to 1.0).
  final double originalAudioVolume;

  /// Volume level for the custom/added audio track (0.0 to 1.0).
  final double customAudioVolume;

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

  DivineVideoDraft copyWith({
    List<DivineVideoClip>? clips,
    String? id,
    String? title,
    String? description,
    Set<String>? hashtags,
    PublishStatus? publishStatus,
    String? publishError,
    bool clearPublishError = false,
    Duration? expireTime,
    bool? allowAudioReuse,
    int? publishAttempts,
    String? proofManifestJson,
    bool clearProofManifestJson = false,
    Map<String, dynamic>? editorStateHistory,
    Map<String, dynamic>? editorEditingParameters,
    DivineVideoClip? finalRenderedClip,
    bool clearFinalRenderedClip = false,
    Set<String>? collaboratorPubkeys,
    InspiredByInfo? inspiredByVideo,
    String? inspiredByNpub,
    AudioEvent? selectedSound,
    bool clearSelectedSound = false,
    Object? contentWarning = _sentinel,
    double? originalAudioVolume,
    double? customAudioVolume,
    bool skipUpdateLastModified = false,
  }) => DivineVideoDraft(
    id: id ?? this.id,
    clips: clips ?? this.clips,
    title: title ?? this.title,
    description: description ?? this.description,
    hashtags: hashtags ?? this.hashtags,
    selectedApproach: selectedApproach,
    createdAt: createdAt,
    lastModified: skipUpdateLastModified ? lastModified : DateTime.now(),
    expireTime: expireTime ?? this.expireTime,
    allowAudioReuse: allowAudioReuse ?? this.allowAudioReuse,
    publishStatus: publishStatus ?? this.publishStatus,
    publishError: clearPublishError
        ? null
        : (publishError ?? this.publishError),
    publishAttempts: publishAttempts ?? this.publishAttempts,
    proofManifestJson: clearProofManifestJson
        ? null
        : (proofManifestJson ?? this.proofManifestJson),
    editorStateHistory: editorStateHistory ?? this.editorStateHistory,
    editorEditingParameters:
        editorEditingParameters ?? this.editorEditingParameters,
    finalRenderedClip: clearFinalRenderedClip
        ? null
        : (finalRenderedClip ?? this.finalRenderedClip),
    collaboratorPubkeys: collaboratorPubkeys ?? this.collaboratorPubkeys,
    inspiredByVideo: inspiredByVideo ?? this.inspiredByVideo,
    inspiredByNpub: inspiredByNpub ?? this.inspiredByNpub,
    selectedSound: clearSelectedSound
        ? null
        : (selectedSound ?? this.selectedSound),
    contentWarning: contentWarning == _sentinel
        ? this.contentWarning
        : contentWarning as String?,
    originalAudioVolume: originalAudioVolume ?? this.originalAudioVolume,
    customAudioVolume: customAudioVolume ?? this.customAudioVolume,
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
      'collaboratorPubkeys': collaboratorPubkeys.toList(),
    if (inspiredByVideo != null) 'inspiredByVideo': inspiredByVideo!.toJson(),
    if (inspiredByNpub != null) 'inspiredByNpub': inspiredByNpub,
    if (selectedSound != null) 'selectedSound': selectedSound!.toJson(),
    if (contentWarning != null) 'contentWarning': contentWarning,
    if (originalAudioVolume != 1.0) 'originalAudioVolume': originalAudioVolume,
    if (customAudioVolume != 1.0) 'customAudioVolume': customAudioVolume,
  };

  Set<ContentLabel> get contentWarnings => ContentLabel.fromCsv(contentWarning);

  /// Returns a hardcoded English age string.
  ///
  /// Prefer [localizedDisplayDuration] in UI code where
  /// [AppLocalizations] is available.
  @Deprecated('Use localizedDisplayDuration with AppLocalizations instead')
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
