// ABOUTME: Data model for a recorded video segment in the Clip Manager
// ABOUTME: Supports ordering, thumbnails, crop metadata, and JSON serialization

import 'dart:async';

import 'package:models/models.dart' as model show AspectRatio;
import 'package:pro_video_editor/pro_video_editor.dart';

class RecordingClip {
  RecordingClip({
    required this.id,
    required this.video,
    required this.duration,
    required this.recordedAt,
    required this.aspectRatio,
    this.thumbnailPath,
    this.processingCompleter,
  });

  final String id;
  final EditorVideo video;
  final Duration duration;
  final DateTime recordedAt;
  final String? thumbnailPath;
  final Completer<bool>? processingCompleter;

  /// The target aspect ratio for this clip (used for deferred cropping)
  final model.AspectRatio aspectRatio;

  double get durationInSeconds => duration.inMilliseconds / 1000.0;
  bool get isProcessing =>
      processingCompleter != null && !processingCompleter!.isCompleted;

  RecordingClip copyWith({
    String? id,
    EditorVideo? video,
    Duration? duration,
    DateTime? recordedAt,
    String? thumbnailPath,
    model.AspectRatio? aspectRatio,
    Completer<bool>? processingCompleter,
  }) {
    return RecordingClip(
      id: id ?? this.id,
      video: video ?? this.video,
      duration: duration ?? this.duration,
      recordedAt: recordedAt ?? this.recordedAt,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      aspectRatio: aspectRatio ?? this.aspectRatio,
      processingCompleter: processingCompleter ?? this.processingCompleter,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'filePath': video.file?.path,
      'durationMs': duration.inMilliseconds,
      'recordedAt': recordedAt.toIso8601String(),
      'thumbnailPath': thumbnailPath,
      'aspectRatio': aspectRatio.name,
    };
  }

  factory RecordingClip.fromJson(Map<String, dynamic> json) {
    final aspectRatioName = json['aspectRatio'] as String?;
    return RecordingClip(
      id: json['id'] as String,
      video: EditorVideo.file(json['filePath'] as String),
      duration: Duration(milliseconds: json['durationMs'] as int),
      recordedAt: DateTime.parse(json['recordedAt'] as String),
      thumbnailPath: json['thumbnailPath'] as String?,
      aspectRatio: model.AspectRatio.values.firstWhere(
        (e) => e.name == aspectRatioName,
        orElse: () => model.AspectRatio.square,
      ),
    );
  }

  @override
  String toString() {
    return 'RecordingClip(id: $id, duration: ${durationInSeconds}s)';
  }
}
