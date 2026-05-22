// ABOUTME: Comments list widget with loading, error, and empty states
// ABOUTME: Renders comments in a flat list using CommentItem widget

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/blocs/comments/comment_reactions/comment_reactions_bloc.dart';
import 'package:openvine/blocs/comments/comments_list/comments_list_bloc.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/screens/comments/widgets/widgets.dart';

class CommentsList extends StatefulWidget {
  const CommentsList({
    required this.showClassicVineNotice,
    required this.scrollController,
    this.showVideoReplies = true,
    super.key,
  });

  final bool showClassicVineNotice;
  final ScrollController scrollController;
  final bool showVideoReplies;

  @override
  State<CommentsList> createState() => _CommentsListState();
}

class _CommentsListState extends State<CommentsList> {
  @override
  void initState() {
    super.initState();
    widget.scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    widget.scrollController.removeListener(_onScroll);
    super.dispose();
  }

  void _onScroll() {
    // Auto-acknowledge new comments when user scrolls to the top.
    if (!widget.scrollController.hasClients) return;
    final bloc = context.read<CommentsListBloc>();
    if (widget.scrollController.offset <= 0 && bloc.state.newCommentCount > 0) {
      bloc.add(const NewCommentsAcknowledged());
    }
  }

  @override
  Widget build(BuildContext context) {
    // Match TikTok / Instagram Reels: any interaction with the comments
    // area (tap on a comment, drag to scroll) dismisses the keyboard so
    // the user can read other comments unobstructed. Draft text in the
    // input is retained — re-tapping the input restores focus.
    //
    // The Listener catches taps anywhere in the list (including dead
    // space and on comment items themselves) without competing in the
    // gesture arena, so existing tap handlers (reply, vote, navigate to
    // profile) still run normally afterwards. The ListView's
    // [ScrollViewKeyboardDismissBehavior.onDrag] covers the scroll case
    // idiomatically.
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => FocusManager.instance.primaryFocus?.unfocus(),
      child: BlocBuilder<CommentsListBloc, CommentsListState>(
        builder: (context, state) {
          if (state.status == CommentsStatus.loading) {
            return const _LoadingState();
          }

          if (state.status == CommentsStatus.failure) {
            return const _ErrorState();
          }

          // Engagement sort consumes upvote counts from CommentReactionsBloc,
          // so cross-bloc the threaded list build via a nested BlocSelector.
          return BlocSelector<
            CommentReactionsBloc,
            CommentReactionsState,
            Map<String, int>
          >(
            selector: (s) => s.commentUpvoteCounts,
            builder: (context, upvoteCounts) {
              final all = state.threadedCommentsWith(
                upvoteCounts: upvoteCounts,
              );
              final threaded = widget.showVideoReplies
                  ? all
                  : all.where((node) => !node.comment.hasVideo).toList();

              if (threaded.isEmpty) {
                return CommentsEmptyState(
                  isClassicVine: widget.showClassicVineNotice,
                );
              }

              return ListView.builder(
                controller: widget.scrollController,
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                itemCount: threaded.length,
                itemBuilder: (context, index) {
                  final node = threaded[index];
                  return CommentItem(comment: node.comment, depth: node.depth);
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) => const CommentsSkeletonLoader();
}

class _ErrorState extends StatelessWidget {
  const _ErrorState();

  @override
  Widget build(BuildContext context) => Center(
    child: Text(
      context.l10n.commentsErrorLoadFailed,
      style: VineTheme.bodyMediumFont(color: VineTheme.error),
    ),
  );
}
