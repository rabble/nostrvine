// ABOUTME: Comments list widget with loading, error, and empty states
// ABOUTME: Renders comments in a flat list using CommentItem widget

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/blocs/comments/comments_bloc.dart';
import 'package:openvine/screens/comments/widgets/widgets.dart';

class CommentsList extends StatelessWidget {
  const CommentsList({
    required this.isOriginalVine,
    required this.scrollController,
    super.key,
  });

  final bool isOriginalVine;
  final ScrollController scrollController;

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

        if (state.comments.isEmpty) {
          return CommentsEmptyState(isClassicVine: isOriginalVine);
        }

        return ListView.builder(
          controller: scrollController,
          itemCount: state.comments.length,

          itemBuilder: (context, index) =>
              CommentItem(comment: state.comments[index]),
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
