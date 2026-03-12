class VideoComment {
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

  final String id;
  final String pubkey;
  final int createdAt;
  final int kind;
  final String content;
  final String sig;
  final List<List<String>> tags;
  final String? authorName;
  final String? authorAvatar;
  final String? replyToEventId;
  final String? replyToPubkey;
}
