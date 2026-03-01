// ABOUTME: Context model for video reply recording flow.
// ABOUTME: Holds parent comment/video info so the recorder knows
// ABOUTME: to post as a comment instead of a standalone video.

import 'package:equatable/equatable.dart';

/// Context for a video reply being recorded.
///
/// Set before navigating to the video recorder. After recording
/// and editing completes, the presence of this context tells the
/// flow to skip the metadata screen and publish as a Kind 1111
/// comment with NIP-92 imeta instead of a Kind 34236 video.
class VideoReplyContext extends Equatable {
  const VideoReplyContext({
    required this.rootEventId,
    required this.rootEventKind,
    required this.rootAuthorPubkey,
    this.rootAddressableId,
    this.parentCommentId,
    this.parentAuthorPubkey,
  });

  /// The root event (video) being commented on.
  final String rootEventId;

  /// Kind of the root event (e.g. 34236).
  final int rootEventKind;

  /// Author pubkey of the root event.
  final String rootAuthorPubkey;

  /// Optional addressable ID for NIP-71 videos.
  final String? rootAddressableId;

  /// Parent comment ID if replying to a specific comment.
  final String? parentCommentId;

  /// Parent comment author pubkey for threading.
  final String? parentAuthorPubkey;

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
