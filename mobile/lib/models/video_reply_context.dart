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

  factory VideoReplyContext.fromJson(Map<String, dynamic> json) =>
      VideoReplyContext(
        rootEventId: json['rootEventId'] as String,
        rootEventKind: json['rootEventKind'] as int,
        rootAuthorPubkey: json['rootAuthorPubkey'] as String,
        rootAddressableId: json['rootAddressableId'] as String?,
        parentCommentId: json['parentCommentId'] as String?,
        parentAuthorPubkey: json['parentAuthorPubkey'] as String?,
      );

  Map<String, dynamic> toJson() => {
    'rootEventId': rootEventId,
    'rootEventKind': rootEventKind,
    'rootAuthorPubkey': rootAuthorPubkey,
    if (rootAddressableId != null) 'rootAddressableId': rootAddressableId,
    if (parentCommentId != null) 'parentCommentId': parentCommentId,
    if (parentAuthorPubkey != null) 'parentAuthorPubkey': parentAuthorPubkey,
  };

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
