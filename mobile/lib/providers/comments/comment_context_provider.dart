// ABOUTME: Scoped provider holding the current comment context (video ID and author pubkey)
// ABOUTME: Override at CommentsScreen level so children can access without prop drilling

import 'package:openvine/providers/comments/comment_input_provider.dart';
import 'package:openvine/providers/comments/comments_provider.dart';
import 'package:openvine/state/comment_input_state.dart';
import 'package:openvine/state/comments_state.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'comment_context_provider.g.dart';

/// Record type for comment context
typedef CommentContext = ({String eventId, String pubkey});

/// Scoped provider for comment context.
///
/// Must be overridden with actual values at the CommentsScreen level.
/// Children can then read the context without needing props.
@Riverpod(keepAlive: true)
CommentContext commentContext(Ref ref) {
  throw UnimplementedError(
    'commentContextProvider must be overridden with actual values',
  );
}

/// Derived provider for current comment input state.
///
/// Automatically uses the scoped [commentContextProvider] to get the
/// correct [CommentInputState] without needing to pass parameters.
///
/// Usage:
/// ```dart
/// // Watch state
/// final inputState = ref.watch(currentCommentInputProvider);
///
/// // Access notifier for actions
/// ref.read(currentCommentInputProvider.notifier).postMainComment();
/// ```
@riverpod
class CurrentCommentInput extends _$CurrentCommentInput {
  @override
  CommentInputState build() {
    final ctx = ref.watch(commentContextProvider);
    return ref.watch(commentInputProvider(ctx.eventId, ctx.pubkey));
  }

  /// Get the underlying notifier for the current context
  CommentInputNotifier get _notifier {
    final ctx = ref.read(commentContextProvider);
    return ref.read(commentInputProvider(ctx.eventId, ctx.pubkey).notifier);
  }

  // Delegate all methods to the underlying notifier
  void updateMainText(String text) => _notifier.updateMainText(text);
  void updateReplyText(String commentId, String text) =>
      _notifier.updateReplyText(commentId, text);
  void toggleReply(String commentId) => _notifier.toggleReply(commentId);
  Future<void> postMainComment() => _notifier.postMainComment();
  Future<void> postReply(String parentCommentId, String? parentAuthorPubkey) =>
      _notifier.postReply(parentCommentId, parentAuthorPubkey);
  void clearError() => _notifier.clearError();
}

/// Derived provider for current comments state.
///
/// Automatically uses the scoped [commentContextProvider] to get the
/// correct [CommentsState] without needing to pass parameters.
@riverpod
CommentsState currentComments(Ref ref) {
  final ctx = ref.watch(commentContextProvider);
  return ref.watch(commentsProvider(ctx.eventId, ctx.pubkey));
}
