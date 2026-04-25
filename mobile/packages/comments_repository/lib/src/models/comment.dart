// ABOUTME: Comment model representing a single comment or reply in a thread.
// ABOUTME: Contains metadata for threading, author info, and Nostr event
// ABOUTME: relationships. Uses Equatable for value-based equality.

import 'package:equatable/equatable.dart';

/// A comment on a Nostr event (Kind 1 text note).
///
/// Comments are threaded using Nostr's NIP-10 reply threading:
/// - `rootEventId`: The original event being commented on (e.g., a video)
/// - `replyToEventId`: The parent comment ID for nested replies
///
/// The `e` tags in the Nostr event use markers:
/// - `root`: Points to the original event
/// - `reply`: Points to the direct parent comment
class Comment extends Equatable {
  /// Creates a new comment.
  const Comment({
    required this.id,
    required this.content,
    required this.authorPubkey,
    required this.createdAt,
    required this.rootEventId,
    required this.rootAuthorPubkey,
    this.replyToEventId,
    this.replyToAuthorPubkey,
    this.videoUrl,
    this.thumbnailUrl,
    this.videoDimensions,
    this.videoDuration,
    this.videoBlurhash,
  });

  /// Unique comment ID (Nostr event ID).
  final String id;

  /// Comment text content.
  final String content;

  /// Author's public key (hex format).
  final String authorPubkey;

  /// When the comment was created.
  final DateTime createdAt;

  /// The root event ID this comment is replying to (e.g., video event).
  final String rootEventId;

  /// Public key of the root event author.
  final String rootAuthorPubkey;

  /// If this is a reply, the ID of the parent comment.
  ///
  /// `null` for top-level comments.
  final String? replyToEventId;

  /// If this is a reply, the public key of the parent comment author.
  final String? replyToAuthorPubkey;

  /// URL of an attached video (NIP-92 imeta).
  final String? videoUrl;

  /// Thumbnail URL for the attached video (NIP-92 imeta `image` field).
  final String? thumbnailUrl;

  /// Video dimensions as "widthxheight" (NIP-92 imeta `dim` field).
  final String? videoDimensions;

  /// Video duration in seconds (NIP-92 imeta `duration` field).
  final int? videoDuration;

  /// Blurhash of the video thumbnail (NIP-92 imeta `blurhash` field).
  final String? videoBlurhash;

  /// Whether this comment has an attached video.
  bool get hasVideo => videoUrl != null && videoUrl!.isNotEmpty;

  /// Creates a copy with updated fields.
  Comment copyWith({
    String? id,
    String? content,
    String? authorPubkey,
    DateTime? createdAt,
    String? rootEventId,
    String? rootAuthorPubkey,
    String? replyToEventId,
    String? replyToAuthorPubkey,
    String? videoUrl,
    String? thumbnailUrl,
    String? videoDimensions,
    int? videoDuration,
    String? videoBlurhash,
  }) => Comment(
    id: id ?? this.id,
    content: content ?? this.content,
    authorPubkey: authorPubkey ?? this.authorPubkey,
    createdAt: createdAt ?? this.createdAt,
    rootEventId: rootEventId ?? this.rootEventId,
    rootAuthorPubkey: rootAuthorPubkey ?? this.rootAuthorPubkey,
    replyToEventId: replyToEventId ?? this.replyToEventId,
    replyToAuthorPubkey: replyToAuthorPubkey ?? this.replyToAuthorPubkey,
    videoUrl: videoUrl ?? this.videoUrl,
    thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
    videoDimensions: videoDimensions ?? this.videoDimensions,
    videoDuration: videoDuration ?? this.videoDuration,
    videoBlurhash: videoBlurhash ?? this.videoBlurhash,
  );

  @override
  List<Object?> get props => [
    id,
    content,
    authorPubkey,
    createdAt,
    rootEventId,
    rootAuthorPubkey,
    replyToEventId,
    replyToAuthorPubkey,
    videoUrl,
    thumbnailUrl,
    videoDimensions,
    videoDuration,
    videoBlurhash,
  ];
}
