// ABOUTME: Data model for a saved video clip in the clip library
// ABOUTME: Supports JSON serialization, thumbnails, and display formatting

import 'package:openvine/utils/path_resolver.dart';
import 'package:path/path.dart' as p;

class SavedClip {
  const SavedClip({
    required this.id,
    required this.filePath,
    required this.thumbnailPath,
    required this.duration,
    required this.createdAt,
    required this.aspectRatio,
    this.sessionId,
  });

  final String id;
  final String filePath;
  final String? thumbnailPath;
  final Duration duration;
  final DateTime createdAt;
  final String aspectRatio;
  final String? sessionId;

  double get durationInSeconds => duration.inMilliseconds / 1000.0;
  double get aspectRatioValue => aspectRatio == 'vertical' ? 9 / 16 : 1.0;

  String get displayDuration {
    final elapsed = DateTime.now().difference(createdAt);
    if (elapsed.inDays > 0) {
      return '${elapsed.inDays}d ago';
    } else if (elapsed.inHours > 0) {
      return '${elapsed.inHours}h ago';
    } else if (elapsed.inMinutes > 0) {
      return '${elapsed.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  SavedClip copyWith({
    String? id,
    String? filePath,
    String? thumbnailPath,
    Duration? duration,
    DateTime? createdAt,
    String? aspectRatio,
    String? sessionId,
  }) {
    return SavedClip(
      id: id ?? this.id,
      filePath: filePath ?? this.filePath,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      duration: duration ?? this.duration,
      createdAt: createdAt ?? this.createdAt,
      aspectRatio: aspectRatio ?? this.aspectRatio,
      sessionId: sessionId ?? this.sessionId,
    );
  }

  Map<String, dynamic> toJson() {
    // Store only filenames (relative paths) for iOS compatibility
    // iOS changes the container path on app updates, so absolute paths break
    return {
      'id': id,
      'filePath': p.basename(filePath),
      'thumbnailPath': thumbnailPath != null
          ? p.basename(thumbnailPath!)
          : null,
      'durationMs': duration.inMilliseconds,
      'createdAt': createdAt.toIso8601String(),
      'aspectRatio': aspectRatio,
      'sessionId': sessionId,
    };
  }

  factory SavedClip.fromJson(
    Map<String, dynamic> json,
    String documentsPath, {
    bool useOriginalPath = false,
  }) {
    return SavedClip(
      id: json['id'] as String,
      filePath: resolvePath(
        json['filePath'] as String,
        documentsPath,
        useOriginalPath: useOriginalPath,
      )!,
      thumbnailPath: resolvePath(
        json['thumbnailPath'] as String?,
        documentsPath,
        useOriginalPath: useOriginalPath,
      ),
      duration: Duration(milliseconds: json['durationMs'] as int),
      createdAt: DateTime.parse(json['createdAt'] as String),
      aspectRatio: json['aspectRatio'] as String,
      sessionId: json['sessionId'] as String?,
    );
  }

  @override
  String toString() {
    return 'SavedClip(id: $id, duration: ${durationInSeconds}s, aspectRatio: $aspectRatio)';
  }
}
