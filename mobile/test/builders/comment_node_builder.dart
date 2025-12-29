// ABOUTME: Fluent builder for creating CommentNode instances in tests
// ABOUTME: Supports building nested comment trees for testing threaded displays

import 'package:comments_repository/comments_repository.dart' as repo;

import 'comment_builder.dart';

/// Fluent builder for creating [repo.CommentNode] instances in tests.
///
/// Uses [repo.CommentNode] from the comments_repository package,
/// following clean architecture separation.
///
/// Usage:
/// ```dart
/// final node = CommentNodeBuilder()
///     .withComment(CommentBuilder().withContent('Parent').build())
///     .withReplies([replyNode1, replyNode2])
///     .build();
/// ```
class CommentNodeBuilder {
  repo.Comment? _comment;
  List<repo.CommentNode> _replies = [];

  /// Set the comment for this node.
  CommentNodeBuilder withComment(repo.Comment comment) {
    _comment = comment;
    return this;
  }

  /// Build a comment using a builder and set it.
  CommentNodeBuilder withCommentBuilder(CommentBuilder builder) {
    _comment = builder.build();
    return this;
  }

  /// Set the list of reply nodes.
  CommentNodeBuilder withReplies(List<repo.CommentNode> replies) {
    _replies = replies;
    return this;
  }

  /// Add a single reply node.
  CommentNodeBuilder addReply(repo.CommentNode reply) {
    _replies.add(reply);
    return this;
  }

  /// Add a reply using a builder.
  CommentNodeBuilder addReplyFromBuilder(CommentNodeBuilder builder) {
    _replies.add(builder.build());
    return this;
  }

  /// Build the [repo.CommentNode] instance.
  repo.CommentNode build() {
    if (_comment == null) {
      throw StateError(
        'Comment must be set before building CommentNode. '
        'Use withComment() or withCommentBuilder().',
      );
    }
    return repo.CommentNode(comment: _comment!, replies: _replies);
  }
}

/// Helper class for building comment trees for tests.
///
/// Uses [repo.CommentNode] from the repository layer.
class CommentTreeBuilder {
  final List<repo.CommentNode> _topLevelComments = [];

  /// Add a top-level comment node.
  CommentTreeBuilder addTopLevel(repo.CommentNode node) {
    _topLevelComments.add(node);
    return this;
  }

  /// Add a top-level comment using builders.
  CommentTreeBuilder addTopLevelFromBuilder(CommentNodeBuilder builder) {
    _topLevelComments.add(builder.build());
    return this;
  }

  /// Build a simple tree with one top-level comment.
  static List<repo.CommentNode> singleComment({
    String content = 'Test comment',
    String? authorPubkey,
  }) => [
    CommentNodeBuilder()
        .withComment(
          CommentBuilder()
              .withContent(content)
              .withAuthorPubkey(authorPubkey ?? TestCommentIds.author1Pubkey)
              .build(),
        )
        .build(),
  ];

  /// Build a tree with a parent and one reply.
  static List<repo.CommentNode> parentWithReply({
    String parentContent = 'Parent comment',
    String replyContent = 'Reply comment',
  }) {
    final parentComment = CommentBuilder()
        .withId(TestCommentIds.comment1Id)
        .withContent(parentContent)
        .withAuthorPubkey(TestCommentIds.author1Pubkey)
        .build();

    final replyComment = CommentBuilder()
        .withId(TestCommentIds.comment2Id)
        .withContent(replyContent)
        .withAuthorPubkey(TestCommentIds.author2Pubkey)
        .asReplyTo(
          parentEventId: TestCommentIds.comment1Id,
          parentAuthorPubkey: TestCommentIds.author1Pubkey,
        )
        .build();

    return [
      CommentNodeBuilder()
          .withComment(parentComment)
          .addReply(CommentNodeBuilder().withComment(replyComment).build())
          .build(),
    ];
  }

  /// Build the list of top-level comment nodes.
  List<repo.CommentNode> build() => List.unmodifiable(_topLevelComments);
}
