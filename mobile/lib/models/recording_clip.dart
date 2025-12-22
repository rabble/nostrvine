// ABOUTME: Data model for a recorded video segment in the Clip Manager
// ABOUTME: Supports ordering, thumbnails, crop metadata, and JSON serialization

import 'package:models/models.dart' as model show AspectRatio;

class RecordingClip {
  RecordingClip({
    required this.id,
    required this.filePath,
    required this.duration,
    required this.orderIndex,
    required this.recordedAt,
    this.thumbnailPath,
    this.aspectRatio,
    this.needsCrop = false,
  });

  final String id;
  final String filePath;
  final Duration duration;
  final int orderIndex;
  final DateTime recordedAt;
  final String? thumbnailPath;

  /// The target aspect ratio for this clip (used for deferred cropping)
  final model.AspectRatio? aspectRatio;

  /// Whether this clip needs cropping applied at export time
  /// On Android, we defer cropping to avoid slow re-encoding during capture
  final bool needsCrop;

  double get durationInSeconds => duration.inMilliseconds / 1000.0;

  RecordingClip copyWith({
    String? id,
    String? filePath,
    Duration? duration,
    int? orderIndex,
    DateTime? recordedAt,
    String? thumbnailPath,
    model.AspectRatio? aspectRatio,
    bool? needsCrop,
  }) {
    return RecordingClip(
      id: id ?? this.id,
      filePath: filePath ?? this.filePath,
      duration: duration ?? this.duration,
      orderIndex: orderIndex ?? this.orderIndex,
      recordedAt: recordedAt ?? this.recordedAt,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      aspectRatio: aspectRatio ?? this.aspectRatio,
      needsCrop: needsCrop ?? this.needsCrop,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'filePath': filePath,
      'durationMs': duration.inMilliseconds,
      'orderIndex': orderIndex,
      'recordedAt': recordedAt.toIso8601String(),
      'thumbnailPath': thumbnailPath,
      'aspectRatio': aspectRatio?.name,
      'needsCrop': needsCrop,
    };
  }

  factory RecordingClip.fromJson(Map<String, dynamic> json) {
    final aspectRatioName = json['aspectRatio'] as String?;
    return RecordingClip(
      id: json['id'] as String,
      filePath: json['filePath'] as String,
      duration: Duration(milliseconds: json['durationMs'] as int),
      orderIndex: json['orderIndex'] as int,
      recordedAt: DateTime.parse(json['recordedAt'] as String),
      thumbnailPath: json['thumbnailPath'] as String?,
      aspectRatio: aspectRatioName != null
          ? model.AspectRatio.values.firstWhere(
              (e) => e.name == aspectRatioName,
              orElse: () => model.AspectRatio.square,
            )
          : null,
      needsCrop: json['needsCrop'] as bool? ?? false,
    );
  }

  @override
  String toString() {
    return 'RecordingClip(id: $id, duration: ${durationInSeconds}s, order: $orderIndex)';
  }
}
