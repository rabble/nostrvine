// ABOUTME: Events for the ProfileCommentsBloc.
// ABOUTME: Supports initial load and pagination of a user's comments.

part of 'profile_comments_bloc.dart';

/// Events for loading a user's comments across all videos.
sealed class ProfileCommentsEvent {
  const ProfileCommentsEvent();
}

/// Requests the initial sync of comments for the target user.
final class ProfileCommentsSyncRequested extends ProfileCommentsEvent {
  const ProfileCommentsSyncRequested({this.completer});

  /// Optional completion signal for UI refresh affordances, completed once the
  /// handler is fully done. See [completeProfileTabSync].
  final Completer<void>? completer;
}

/// Requests loading more comments for pagination.
final class ProfileCommentsLoadMoreRequested extends ProfileCommentsEvent {
  const ProfileCommentsLoadMoreRequested();
}
