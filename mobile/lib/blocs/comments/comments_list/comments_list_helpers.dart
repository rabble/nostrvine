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
