import 'package:openvine/models/vine_draft.dart';

/// Metadata for video editor including title, description, and settings.
class VideoEditorMeta {
  /// Creates video editor metadata.
  VideoEditorMeta({
    required this.title,
    required this.description,
    required this.hashtags,
    this.allowAudioReuse = false,
    this.expireTime,
  });

  /// Creates empty metadata for new draft.
  factory VideoEditorMeta.draft() {
    return VideoEditorMeta(title: '', description: '', hashtags: []);
  }

  /// Creates metadata from existing vine draft.
  factory VideoEditorMeta.fromVineDraft(VineDraft draft) {
    return VideoEditorMeta(
      title: draft.title,
      description: draft.description,
      hashtags: draft.hashtags,
      // TODO(@hm21): Temporary "commented out" create PR with only new files
      // allowAudioReuse: draft.allowAudioReuse,
      // expireTime: draft.expireTime,
    );
  }

  /// Video title.
  final String title;

  /// Video description.
  final String description;

  /// List of hashtags.
  final List<String> hashtags;

  /// Whether audio can be reused by others.
  final bool allowAudioReuse;

  /// Optional expiration time for the video.
  final Duration? expireTime;

  /// Creates a copy with updated fields.
  VideoEditorMeta copyWith({
    String? title,
    String? description,
    List<String>? hashtags,
    bool? allowAudioReuse,
    Duration? expireTime,
  }) {
    return VideoEditorMeta(
      title: title ?? this.title,
      description: description ?? this.description,
      hashtags: hashtags ?? this.hashtags,
      allowAudioReuse: allowAudioReuse ?? this.allowAudioReuse,
      expireTime: expireTime ?? this.expireTime,
    );
  }
}
