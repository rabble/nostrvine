/// A single comment returned by the FunnelCake video comments endpoint.
class VideoComment {
  /// Creates a parsed video comment model.
  const VideoComment({
    required this.id,
    required this.pubkey,
    required this.createdAt,
    required this.kind,
    required this.content,
    required this.sig,
    required this.tags,
    this.authorName,
    this.authorAvatar,
    this.replyToEventId,
    this.replyToPubkey,
  });

  /// Parses a comment payload from the FunnelCake API.
  factory VideoComment.fromJson(Map<String, dynamic> json) {
    final rawTags = json['tags'] as List<dynamic>? ?? const [];
    return VideoComment(
      id: json['id'] as String? ?? '',
      pubkey: json['pubkey'] as String? ?? '',
      createdAt: (json['created_at'] as num?)?.toInt() ?? 0,
      kind: (json['kind'] as num?)?.toInt() ?? 0,
      content: json['content'] as String? ?? '',
      sig: json['sig'] as String? ?? '',
      tags: rawTags
          .whereType<List<dynamic>>()
          .map((tag) => tag.map((value) => value.toString()).toList())
          .toList(),
      authorName: json['author_name'] as String?,
      authorAvatar: json['author_avatar'] as String?,
      replyToEventId: json['reply_to_event_id'] as String?,
      replyToPubkey: json['reply_to_pubkey'] as String?,
    );
  }

  /// The Nostr event ID for the comment.
  final String id;

  /// The comment author's public key.
  final String pubkey;

  /// The Unix timestamp when the comment event was created.
  final int createdAt;

  /// The Nostr kind for the comment event.
  final int kind;

  /// The raw comment body.
  final String content;

  /// The event signature.
  final String sig;

  /// The raw Nostr tags attached to the comment event.
  final List<List<String>> tags;

  /// The resolved display name for the author when available.
  final String? authorName;

  /// The resolved avatar URL for the author when available.
  final String? authorAvatar;

  /// The parent event ID when this comment is a reply.
  final String? replyToEventId;

  /// The parent author's public key when this comment is a reply.
  final String? replyToPubkey;
}
