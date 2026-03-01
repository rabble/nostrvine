// ABOUTME: Comments list widget with loading, error, and empty states
// ABOUTME: Renders comments in a flat list using CommentItem widget

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/blocs/comments/comments_bloc.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:openvine/screens/comments/widgets/comment_item.dart';
import 'package:openvine/screens/comments/widgets/widgets.dart';

class CommentsList extends ConsumerStatefulWidget {
  const CommentsList({
    required this.isOriginalVine,
    required this.scrollController,
    super.key,
  });

  final bool isOriginalVine;
  final ScrollController scrollController;

  @override
  ConsumerState<CommentsList> createState() => _CommentsListState();
}

class _CommentsListState extends ConsumerState<CommentsList> {
  final _autoPlayNotifier = ValueNotifier<bool>(false);

  @override
  void initState() {
    super.initState();
    widget.scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    widget.scrollController.removeListener(_onScroll);
    _autoPlayNotifier.dispose();
    super.dispose();
  }

  void _onScroll() {
    // Auto-acknowledge new comments when user scrolls to the top
    if (!widget.scrollController.hasClients) return;
    final bloc = context.read<CommentsBloc>();
    if (widget.scrollController.offset <= 0 && bloc.state.newCommentCount > 0) {
      bloc.add(const NewCommentsAcknowledged());
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CommentsBloc, CommentsState>(
      builder: (context, state) {
        if (state.status == CommentsStatus.loading) {
          return const _LoadingState();
        }

        if (state.status == CommentsStatus.failure) {
          return const _ErrorState();
        }

        final isVideoRepliesEnabled = ref.watch(
          isFeatureEnabledProvider(FeatureFlag.videoReplies),
        );

        // Filter out video-only comments when feature flag is off
        final threaded = isVideoRepliesEnabled
            ? state.threadedComments
            : state.threadedComments
                  .where((node) => !isVideoOnlyComment(node.comment))
                  .toList();

        if (threaded.isEmpty) {
          return CommentsEmptyState(isClassicVine: widget.isOriginalVine);
        }

        return ListView.builder(
          controller: widget.scrollController,
          itemCount: threaded.length,
          itemBuilder: (context, index) {
            final node = threaded[index];
            return CommentItem(
              comment: node.comment,
              depth: node.depth,
              autoPlayNotifier: _autoPlayNotifier,
            );
          },
        );
      },
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
  Widget build(BuildContext context) => const Center(
    child: Text('Failed to load comments', style: TextStyle(color: Colors.red)),
  );
}
