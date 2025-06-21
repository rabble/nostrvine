// ABOUTME: Data model for Vine drafts that users save before publishing
// ABOUTME: Includes video file path, metadata, and creation timestamp

import 'dart:io';

class VineDraft {
  final String id;
  final File videoFile;
  final String title;
  final String description;
  final List<String> hashtags;
  final int frameCount;
  final String selectedApproach;
  final DateTime createdAt;
  final DateTime lastModified;

  const VineDraft({
    required this.id,
    required this.videoFile,
    required this.title,
    required this.description,
    required this.hashtags,
    required this.frameCount,
    required this.selectedApproach,
    required this.createdAt,
    required this.lastModified,
  });

  factory VineDraft.create({
    required File videoFile,
    required String title,
    required String description,
    required List<String> hashtags,
    required int frameCount,
    required String selectedApproach,
  }) {
    final now = DateTime.now();
    return VineDraft(
      id: 'draft_${now.millisecondsSinceEpoch}',
      videoFile: videoFile,
      title: title,
      description: description,
      hashtags: hashtags,
      frameCount: frameCount,
      selectedApproach: selectedApproach,
      createdAt: now,
      lastModified: now,
    );
  }

  VineDraft copyWith({
    String? title,
    String? description,
    List<String>? hashtags,
  }) {
    return VineDraft(
      id: id,
      videoFile: videoFile,
      title: title ?? this.title,
      description: description ?? this.description,
      hashtags: hashtags ?? this.hashtags,
      frameCount: frameCount,
      selectedApproach: selectedApproach,
      createdAt: createdAt,
      lastModified: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'videoFilePath': videoFile.path,
      'title': title,
      'description': description,
      'hashtags': hashtags,
      'frameCount': frameCount,
      'selectedApproach': selectedApproach,
      'createdAt': createdAt.toIso8601String(),
      'lastModified': lastModified.toIso8601String(),
    };
  }

  factory VineDraft.fromJson(Map<String, dynamic> json) {
    return VineDraft(
      id: json['id'],
      videoFile: File(json['videoFilePath']),
      title: json['title'],
      description: json['description'],
      hashtags: List<String>.from(json['hashtags']),
      frameCount: json['frameCount'],
      selectedApproach: json['selectedApproach'],
      createdAt: DateTime.parse(json['createdAt']),
      lastModified: DateTime.parse(json['lastModified']),
    );
  }

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
}