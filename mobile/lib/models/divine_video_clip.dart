// ABOUTME: Data model for a recorded video segment in the Clip Manager
// ABOUTME: Supports ordering, thumbnails, crop metadata, and JSON serialization

import 'dart:async';
import 'dart:io';

import 'package:divine_camera/divine_camera.dart'
    show CameraLensMetadata, DivineCameraLens;
import 'package:models/models.dart' as model show AspectRatio;
import 'package:openvine/utils/path_resolver.dart';
import 'package:path/path.dart' as p;
import 'package:pro_video_editor/pro_video_editor.dart';
import 'package:unified_logger/unified_logger.dart';

class DivineVideoClip {
  DivineVideoClip({
    required this.id,
    required this.video,
    required this.duration,
    required this.recordedAt,
    required this.targetAspectRatio,
    required double? originalAspectRatio,
    this.libraryTitle,
    this.thumbnailPath,
    Duration? thumbnailTimestamp,
    this.processingCompleter,
    this.lensMetadata,
    this.ghostFramePath,
    this.trimStart = Duration.zero,
    this.trimEnd = Duration.zero,
    this.volume = 1,
    this.playbackSpeed,
    this.reversed = false,
    this.forwardVideoPath,
    this.reversedVideoPath,
    this.proofManifestJson,
    this.deletedAt,
    this.transition,
  }) : _thumbnailTimestamp = thumbnailTimestamp,
       _originalAspectRatio = originalAspectRatio;

  final String id;
  final EditorVideo video;
  final String? libraryTitle;
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

  /// Playback speed multiplier for this clip (e.g. 0.5 = half speed, 2.0 = double speed).
  /// Null means normal speed (1.0).
  final double? playbackSpeed;

  /// Whether this clip plays in reverse.
  final bool reversed;

  /// Cached forward file path used to restore the clip after a reverse toggle.
  final String? forwardVideoPath;

  /// Cached reversed file path so repeated reverse toggles can reuse it.
  final String? reversedVideoPath;

  /// JSON-encoded ProofMode / C2PA attestation data for this individual clip.
  final String? proofManifestJson;

  /// When this clip was soft-deleted to the trash bin, or `null` for
  /// active clips. Sourced from the Drift `clips.deleted_at` column and
  /// only populated when the clip is loaded via the trash-bin path.
  final DateTime? deletedAt;

  /// How this clip transitions into the **next** clip on the timeline
  /// (dissolve, fade-to-black, slide, …), or `null` for a hard cut.
  ///
  /// On the **last clip** there is no following clip, so this is the
  /// loop-restart wrap (`pro_video_editor` ≥ 2.5): it blends the last clip's
  /// tail into the first clip's head so a looping player restarts seamlessly.
  /// Drives both the live editor preview and the final rendered composition.
  final ClipTransition? transition;

  double get durationInSeconds => duration.inMilliseconds / 1000.0;

  /// Effective duration after trimming (clamped to zero).
  Duration get trimmedDuration {
    final result = duration - trimStart - trimEnd;
    return result.isNegative ? Duration.zero : result;
  }

  /// Effective duration in seconds after trimming.
  double get trimmedDurationInSeconds =>
      trimmedDuration.inMilliseconds / 1000.0;

  /// Wall-clock duration this clip occupies in the final composition,
  /// i.e. [trimmedDuration] divided by [playbackSpeed].
  ///
  /// A 10 s clip at 2× speed occupies 5 s of playback time.
  Duration get playbackDuration =>
      sourceDurationToPlaybackDuration(trimmedDuration);

  /// Converts a duration measured in this clip's source media time into the
  /// wall-clock duration it occupies after [playbackSpeed] is applied.
  Duration sourceDurationToPlaybackDuration(Duration sourceDuration) {
    final speed = playbackSpeed ?? 1.0;
    if (speed <= 0 || speed == 1.0) return sourceDuration;
    return Duration(
      microseconds: (sourceDuration.inMicroseconds / speed).round(),
    );
  }

  /// Inverse of [sourceDurationToPlaybackDuration]: converts a wall-clock
  /// (playback) duration into the span of this clip's source media it covers
  /// once [playbackSpeed] is applied.
  ///
  /// A 1 s wall-clock span on a 2× clip maps to 2 s of source media.
  Duration playbackDurationToSourceDuration(Duration playbackDuration) {
    final speed = playbackSpeed ?? 1.0;
    if (speed <= 0 || speed == 1.0) return playbackDuration;
    return Duration(
      microseconds: (playbackDuration.inMicroseconds * speed).round(),
    );
  }

  /// [playbackDuration] expressed as fractional seconds.
  double get playbackDurationInSeconds =>
      playbackDuration.inMilliseconds / 1000.0;
  bool get isProcessing =>
      processingCompleter != null && !processingCompleter!.isCompleted;

  /// Whether this clip's source video file currently exists on disk.
  ///
  /// A clip can outlive its media: when a clip is removed, [FileCleanupService]
  /// deletes its source file as soon as no clip/draft row references it — but
  /// the editor's undo history (and any draft that persisted that history) can
  /// still resurrect the clip. Handing a clip whose file is gone to the native
  /// preview player makes the whole composition fail with `COMPOSITION_ERROR`
  /// and freezes the editor, so restore/undo paths use this to drop orphaned
  /// clips. See `restoreDraft` and `VideoEditorCanvas._syncMainCapabilities`.
  bool get hasResolvableVideoFile {
    final path = video.file?.path;
    return path != null && File(path).existsSync();
  }

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
    String? libraryTitle,
    bool clearLibraryTitle = false,
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
    double? playbackSpeed,
    bool clearPlaybackSpeed = false,
    bool? reversed,
    String? forwardVideoPath,
    bool clearForwardVideoPath = false,
    String? reversedVideoPath,
    bool clearReversedVideoPath = false,
    String? proofManifestJson,
    bool clearProofManifestJson = false,
    DateTime? deletedAt,
    ClipTransition? transition,
    bool clearTransition = false,
  }) {
    final isNewLogicalClip = id != null && id != this.id;

    return DivineVideoClip(
      id: id ?? this.id,
      video: video ?? this.video,
      libraryTitle: clearLibraryTitle
          ? null
          : (libraryTitle ?? this.libraryTitle),
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
      playbackSpeed: clearPlaybackSpeed
          ? null
          : (playbackSpeed ?? this.playbackSpeed),
      reversed: reversed ?? this.reversed,
      forwardVideoPath: isNewLogicalClip
          ? null
          : clearForwardVideoPath
          ? null
          : (forwardVideoPath ?? this.forwardVideoPath),
      reversedVideoPath: isNewLogicalClip
          ? null
          : clearReversedVideoPath
          ? null
          : (reversedVideoPath ?? this.reversedVideoPath),
      proofManifestJson: clearProofManifestJson
          ? null
          : (proofManifestJson ?? this.proofManifestJson),
      deletedAt: deletedAt ?? this.deletedAt,
      transition: clearTransition ? null : (transition ?? this.transition),
    );
  }

  Map<String, dynamic> toJson() {
    // Store only filenames (relative paths) for iOS compatibility
    // iOS changes the container path on app updates, so absolute paths break
    final videoPath = video.file?.path;
    return {
      'id': id,
      'filePath': videoPath != null ? p.basename(videoPath) : null,
      if (libraryTitle != null) 'libraryTitle': libraryTitle,
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
      if (playbackSpeed != null) 'playbackSpeed': playbackSpeed,
      if (reversed) 'reversed': true,
      if (forwardVideoPath != null)
        'forwardVideoPath': p.basename(forwardVideoPath!),
      if (reversedVideoPath != null)
        'reversedVideoPath': p.basename(reversedVideoPath!),
      if (proofManifestJson != null) 'proofManifestJson': proofManifestJson,
      if (transition != null) 'transition': transition!.toMap(),
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

    // A clip's only persisted video source is its file path; without it the
    // clip can't be reconstructed (`EditorVideo` requires a non-null source).
    // Validate the required fields up front and throw a typed error so the
    // loader can skip this single corrupt row instead of a cryptic
    // `Null is not a subtype of String` cast aborting the whole library/draft
    // load.
    final id = json['id'] as String?;
    final filePath = json['filePath'] as String?;
    final rawRecordedAt = (json['recordedAt'] ?? json['createdAt']) as String?;
    final durationMs = json['durationMs'] as int?;
    if (id == null ||
        filePath == null ||
        rawRecordedAt == null ||
        durationMs == null) {
      throw const FormatException(
        'DivineVideoClip JSON is missing a required field '
        '(id, filePath, recordedAt, or durationMs); cannot reconstruct '
        'the clip.',
      );
    }

    return DivineVideoClip(
      id: id,
      video: EditorVideo.file(
        resolvePath(
          filePath,
          documentsPath,
          useOriginalPath: useOriginalPath,
        ),
      ),
      libraryTitle: json['libraryTitle'] as String?,
      duration: Duration(milliseconds: durationMs),
      recordedAt: DateTime.parse(rawRecordedAt),
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
      playbackSpeed: (json['playbackSpeed'] as num?)?.toDouble(),
      reversed: (json['reversed'] as bool?) ?? false,
      forwardVideoPath: resolvePath(
        json['forwardVideoPath'] as String?,
        documentsPath,
        useOriginalPath: useOriginalPath,
      ),
      reversedVideoPath: resolvePath(
        json['reversedVideoPath'] as String?,
        documentsPath,
        useOriginalPath: useOriginalPath,
      ),
      proofManifestJson: json['proofManifestJson'] as String?,
      transition: _transitionFromJson(json['transition']),
    );
  }

  /// Parses a persisted [ClipTransition], degrading to `null` (a hard cut) when
  /// the stored type/curve/direction names can't be resolved — e.g. a
  /// forward-incompatible draft written by a newer build, or partial
  /// corruption. `ClipTransition.fromMap` resolves enums via `byName`, which
  /// throws on an unknown name; since a draft deserializes every clip through
  /// `fromJson`, an unguarded throw here would abort the *whole* draft load.
  /// Mirrors the `targetAspectRatio` `orElse` fallback above.
  static ClipTransition? _transitionFromJson(Object? raw) {
    if (raw is! Map) return null;
    try {
      return ClipTransition.fromMap(raw.cast<String, dynamic>());
    } catch (error, stackTrace) {
      Log.error(
        'Dropping unparseable clip transition; falling back to a hard cut',
        name: 'DivineVideoClip',
        error: error,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  @override
  String toString() {
    return 'RecordingClip(id: $id, duration: ${durationInSeconds}s)';
  }
}
