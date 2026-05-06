// ABOUTME: Navigation-scoped context for publishing a recorded clip as a comment.
// ABOUTME: Carries the NIP-22 root and optional parent comment metadata.

import 'package:equatable/equatable.dart';

class VideoReplyContext extends Equatable {
  const VideoReplyContext({
    required this.rootEventId,
    required this.rootEventKind,
    required this.rootAuthorPubkey,
    this.rootAddressableId,
    this.parentCommentId,
    this.parentAuthorPubkey,
  });

  final String rootEventId;
  final int rootEventKind;
  final String rootAuthorPubkey;
  final String? rootAddressableId;
  final String? parentCommentId;
  final String? parentAuthorPubkey;

  bool get isReplyToComment => parentCommentId != null;

  @override
  List<Object?> get props => [
    rootEventId,
    rootEventKind,
    rootAuthorPubkey,
    rootAddressableId,
    parentCommentId,
    parentAuthorPubkey,
  ];
}
