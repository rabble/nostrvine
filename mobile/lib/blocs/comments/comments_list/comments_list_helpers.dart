import 'dart:math';

import 'package:comments_repository/comments_repository.dart';

/// Computes an engagement score for ranking comments.
///
/// Score = (max(0, netScore) + replies*2) / (ageHours + 2)^1.2
/// where netScore = upvotes - downvotes.
/// Higher scores indicate more engaging, recent content.
double commentEngagementScore({
  required Comment comment,
  required DateTime now,
  required Map<String, int> likeCounts,
  required Map<String, int> replyCounts,
}) {
  final netScore = likeCounts[comment.id] ?? 0;
  final replies = replyCounts[comment.id] ?? 0;
  final engagement = max(0, netScore) + (replies * 2);
  final ageHours = now.difference(comment.createdAt).inMinutes / 60.0;
  return engagement / pow(ageHours + 2, 1.2);
}

/// Prefix shared by every optimistic placeholder in the comments store.
///
/// Load-more cursor selection and the relay-echo swap both key off this prefix
/// (see `CommentsListBloc`), so any new placeholder kind must keep it.
const commentPlaceholderIdPrefix = 'pending_comment_';

const _pendingVideoReplyIdPrefix = '${commentPlaceholderIdPrefix}video_';

/// Placeholder id for an in-flight video reply published from [draftId].
///
/// Encoding the draft id makes removal deterministic: the bridge can drop the
/// exact placeholder when its upload finishes, instead of relying on the
/// author+content match the relay-echo swap uses — a video reply's content is
/// its description and is frequently empty.
String pendingVideoReplyId(String draftId) =>
    '$_pendingVideoReplyIdPrefix$draftId';

/// Whether [commentId] is a pending video-reply placeholder.
bool isPendingVideoReplyId(String commentId) =>
    commentId.startsWith(_pendingVideoReplyIdPrefix);

/// The draft id encoded in [commentId], or `null` if it is not a pending
/// video-reply placeholder.
String? draftIdFromPendingVideoReplyId(String commentId) =>
    isPendingVideoReplyId(commentId)
    ? commentId.substring(_pendingVideoReplyIdPrefix.length)
    : null;

/// Computes reply counts per comment ID from a comments map.
/// Returns a map of comment ID → number of replies targeting it.
Map<String, int> computeReplyCounts(Map<String, Comment> commentsById) {
  final counts = <String, int>{};
  for (final comment in commentsById.values) {
    final parentId = comment.replyToEventId;
    if (parentId != null && parentId.isNotEmpty) {
      counts[parentId] = (counts[parentId] ?? 0) + 1;
    }
  }
  return counts;
}
