// ABOUTME: Fluent builder for creating Comment instances in tests
// ABOUTME: Provides sensible defaults and allows customization for test scenarios

import 'package:comments_repository/comments_repository.dart';

/// Fluent builder for creating Comment instances in tests.
///
/// Usage:
/// ```dart
/// final comment = CommentBuilder()
///     .withContent('Test comment')
///     .withAuthorPubkey(testPubkey)
///     .build();
/// ```
class CommentBuilder {
  // Default values using full 64-character hex IDs (required by project standards)
  String _id =
      'a1b2c3d4e5f6789012345678901234567890abcdef123456789012345678901234';
  String _content = 'Test comment content';
  String _authorPubkey =
      'b2c3d4e5f6789012345678901234567890abcdef123456789012345678901234a';
  DateTime _createdAt = DateTime.now();
  String _rootEventId =
      'c3d4e5f6789012345678901234567890abcdef123456789012345678901234ab';
  String _rootAuthorPubkey =
      'd4e5f6789012345678901234567890abcdef123456789012345678901234abc';
  String? _replyToEventId;
  String? _replyToAuthorPubkey;

  /// Set the comment ID.
  CommentBuilder withId(String id) {
    _id = id;
    return this;
  }

  /// Set the comment content.
  CommentBuilder withContent(String content) {
    _content = content;
    return this;
  }

  /// Set the author's public key.
  CommentBuilder withAuthorPubkey(String pubkey) {
    _authorPubkey = pubkey;
    return this;
  }

  /// Set the creation timestamp.
  CommentBuilder withCreatedAt(DateTime createdAt) {
    _createdAt = createdAt;
    return this;
  }

  /// Set the root event ID (video being commented on).
  CommentBuilder withRootEventId(String rootEventId) {
    _rootEventId = rootEventId;
    return this;
  }

  /// Set the root author's public key.
  CommentBuilder withRootAuthorPubkey(String pubkey) {
    _rootAuthorPubkey = pubkey;
    return this;
  }

  /// Set the reply-to event ID (for replies to other comments).
  CommentBuilder withReplyToEventId(String? replyToEventId) {
    _replyToEventId = replyToEventId;
    return this;
  }

  /// Set the reply-to author's public key.
  CommentBuilder withReplyToAuthorPubkey(String? pubkey) {
    _replyToAuthorPubkey = pubkey;
    return this;
  }

  /// Make this comment a reply to another comment.
  CommentBuilder asReplyTo({
    required String parentEventId,
    required String parentAuthorPubkey,
  }) {
    _replyToEventId = parentEventId;
    _replyToAuthorPubkey = parentAuthorPubkey;
    return this;
  }

  /// Create a comment that was posted "now" (for testing relative time display).
  CommentBuilder postedNow() {
    _createdAt = DateTime.now();
    return this;
  }

  /// Create a comment posted a specific duration ago.
  CommentBuilder postedAgo(Duration duration) {
    _createdAt = DateTime.now().subtract(duration);
    return this;
  }

  /// Build the Comment instance.
  Comment build() => Comment(
    id: _id,
    content: _content,
    authorPubkey: _authorPubkey,
    createdAt: _createdAt,
    rootEventId: _rootEventId,
    rootAuthorPubkey: _rootAuthorPubkey,
    replyToEventId: _replyToEventId,
    replyToAuthorPubkey: _replyToAuthorPubkey,
  );
}

/// Standard test IDs for consistent testing (full 64-character hex format).
class TestCommentIds {
  static const comment1Id =
      'a1b2c3d4e5f6789012345678901234567890abcdef123456789012345678901234';
  static const comment2Id =
      'e5f6789012345678901234567890abcdef123456789012345678901234abcdef01';
  static const comment3Id =
      'f6789012345678901234567890abcdef123456789012345678901234abcdef012';

  static const author1Pubkey =
      'b2c3d4e5f6789012345678901234567890abcdef123456789012345678901234a';
  static const author2Pubkey =
      '789012345678901234567890abcdef123456789012345678901234abcdef01234';
  static const author3Pubkey =
      '89012345678901234567890abcdef123456789012345678901234abcdef012345';

  static const videoEventId =
      'c3d4e5f6789012345678901234567890abcdef123456789012345678901234ab';
  static const videoAuthorPubkey =
      'd4e5f6789012345678901234567890abcdef123456789012345678901234abc';
}
