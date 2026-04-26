// ABOUTME: Data model for a recorded video segment in the Clip Manager
// ABOUTME: Supports ordering, thumbnails, crop metadata, and JSON serialization

import 'dart:async';

import 'package:divine_camera/divine_camera.dart'
    show CameraLensMetadata, DivineCameraLens;
import 'package:models/models.dart' as model show AspectRatio;
import 'package:openvine/utils/path_resolver.dart';
import 'package:path/path.dart' as p;
import 'package:pro_video_editor/pro_video_editor.dart';

class DivineVideoClip {
  DivineVideoClip({
    required this.id,
    required this.video,
    required this.duration,
    required this.recordedAt,
    required this.targetAspectRatio,
    required double? originalAspectRatio,
    this.thumbnailPath,
    Duration? thumbnailTimestamp,
    this.processingCompleter,
    this.lensMetadata,
    this.ghostFramePath,
    this.trimStart = Duration.zero,
    this.trimEnd = Duration.zero,
    this.volume = 1,
    this.proofManifestJson,
  }) : _thumbnailTimestamp = thumbnailTimestamp,
       _originalAspectRatio = originalAspectRatio;

  final String id;
  final EditorVideo video;
  final Duration duration;
  final DateTime recordedAt;
  final String? thumbnailPath;

  /// Video position where the thumbnail was extracted from (raw value, may be null)
  final Duration? _thumbnailTimestamp;

  /// Original aspect ratio from the recorded video (raw value, may be null)
  final double? _originalAspectRatio;

  final Completer<bool>? processingCompleter;

  /// The target aspect ratio for this clip (used for deferred cropping)
  final model.AspectRatio targetAspectRatio;

  /// Camera lens metadata at the time of recording (focal length, aperture, etc.)
  final CameraLensMetadata? lensMetadata;

  /// File path to the last frame of this clip (used for ghost frame overlay).
  final String? ghostFramePath;

  /// How much has been trimmed from the start of the clip.
  final Duration trimStart;

  /// How much has been trimmed from the end of the clip.
  final Duration trimEnd;

  /// Playback volume for this clip, between 0 (muted) and 1 (full volume).
  final double volume;

  /// JSON-encoded ProofMode / C2PA attestation data for this individual clip.
  final String? proofManifestJson;

  double get durationInSeconds => duration.inMilliseconds / 1000.0;

  /// Effective duration after trimming (clamped to zero).
  Duration get trimmedDuration {
    final result = duration - trimStart - trimEnd;
    return result.isNegative ? Duration.zero : result;
  }

  /// Effective duration in seconds after trimming.
  double get trimmedDurationInSeconds =>
      trimmedDuration.inMilliseconds / 1000.0;
  bool get isProcessing =>
      processingCompleter != null && !processingCompleter!.isCompleted;

  /// Whether this clip was recorded with a front-facing camera.
  bool get isFrontCameraLens =>
      DivineCameraLens.isFrontCameraLens(lensMetadata?.lensType);

  /// Returns the thumbnail timestamp, or a fallback of 210ms or half the
  /// video duration (whichever is smaller) if not set.
  Duration get thumbnailTimestamp {
    if (_thumbnailTimestamp != null) return _thumbnailTimestamp;
    final halfDuration = Duration(milliseconds: duration.inMilliseconds ~/ 2);
    const fallback = Duration(milliseconds: 210);
    return halfDuration < fallback ? halfDuration : fallback;
  }

  /// Returns the original aspect ratio, or 9/16 as fallback if not set.
  double get originalAspectRatio => _originalAspectRatio ?? 9 / 16;

  DivineVideoClip copyWith({
    String? id,
    EditorVideo? video,
    Duration? duration,
    DateTime? recordedAt,
    String? thumbnailPath,
    Duration? thumbnailTimestamp,
    double? originalAspectRatio,
    model.AspectRatio? targetAspectRatio,
    Completer<bool>? processingCompleter,
    CameraLensMetadata? lensMetadata,
    String? ghostFramePath,
    Duration? trimStart,
    Duration? trimEnd,
    double? volume,
    String? proofManifestJson,
    bool clearProofManifestJson = false,
  }) {
    return DivineVideoClip(
      id: id ?? this.id,
      video: video ?? this.video,
      duration: duration ?? this.duration,
      recordedAt: recordedAt ?? this.recordedAt,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      thumbnailTimestamp: thumbnailTimestamp ?? _thumbnailTimestamp,
      originalAspectRatio: originalAspectRatio ?? _originalAspectRatio,
      targetAspectRatio: targetAspectRatio ?? this.targetAspectRatio,
      processingCompleter: processingCompleter ?? this.processingCompleter,
      lensMetadata: lensMetadata ?? this.lensMetadata,
      ghostFramePath: ghostFramePath ?? this.ghostFramePath,
      trimStart: trimStart ?? this.trimStart,
      trimEnd: trimEnd ?? this.trimEnd,
      volume: volume ?? this.volume,
      proofManifestJson: clearProofManifestJson
          ? null
          : (proofManifestJson ?? this.proofManifestJson),
    );
  }

  Map<String, dynamic> toJson() {
    // Store only filenames (relative paths) for iOS compatibility
    // iOS changes the container path on app updates, so absolute paths break
    final videoPath = video.file?.path;
    return {
      'id': id,
      'filePath': videoPath != null ? p.basename(videoPath) : null,
      'durationMs': duration.inMilliseconds,
      'recordedAt': recordedAt.toIso8601String(),
      'thumbnailPath': thumbnailPath != null
          ? p.basename(thumbnailPath!)
          : null,
      'thumbnailTimestampMs': _thumbnailTimestamp?.inMilliseconds,
      'originalAspectRatio': _originalAspectRatio,
      'targetAspectRatio': targetAspectRatio.name,
      'lensMetadata': lensMetadata?.toMap(),
      'ghostFramePath': ghostFramePath != null
          ? p.basename(ghostFramePath!)
          : null,
      'trimStartMs': trimStart.inMilliseconds,
      'trimEndMs': trimEnd.inMilliseconds,
      'volume': volume,
      if (proofManifestJson != null) 'proofManifestJson': proofManifestJson,
    };
  }

  factory DivineVideoClip.fromJson(
    Map<String, dynamic> json,
    String documentsPath, {
    bool useOriginalPath = false,
  }) {
    final aspectRatioName =
        (json['targetAspectRatio'] ?? json['aspectRatio']) as String?;
    final thumbnailTimestampMs = json['thumbnailTimestampMs'] as int?;

    return DivineVideoClip(
      id: json['id'] as String,
      video: EditorVideo.file(
        resolvePath(
          json['filePath'] as String,
          documentsPath,
          useOriginalPath: useOriginalPath,
        ),
      ),
      duration: Duration(milliseconds: json['durationMs'] as int),
      recordedAt: DateTime.parse(
        (json['recordedAt'] ?? json['createdAt']) as String,
      ),
      thumbnailPath: resolvePath(
        json['thumbnailPath'] as String?,
        documentsPath,
        useOriginalPath: useOriginalPath,
      ),
      thumbnailTimestamp: thumbnailTimestampMs != null
          ? Duration(milliseconds: thumbnailTimestampMs)
          : null,
      originalAspectRatio: json['originalAspectRatio'] as double?,
      targetAspectRatio: model.AspectRatio.values.firstWhere(
        (e) => e.name == aspectRatioName,
        orElse: () => model.AspectRatio.square,
      ),
      lensMetadata: json['lensMetadata'] != null
          ? CameraLensMetadata.fromMap(
              json['lensMetadata'] as Map<String, dynamic>,
            )
          : null,
      ghostFramePath: resolvePath(
        json['ghostFramePath'] as String?,
        documentsPath,
        useOriginalPath: useOriginalPath,
      ),
      trimStart: Duration(milliseconds: (json['trimStartMs'] as int?) ?? 0),
      trimEnd: Duration(milliseconds: (json['trimEndMs'] as int?) ?? 0),
      volume: (json['volume'] as num?)?.toDouble() ?? 1,
      proofManifestJson: json['proofManifestJson'] as String?,
    );
  }

  @override
  String toString() {
    return 'RecordingClip(id: $id, duration: ${durationInSeconds}s)';
  }
}
