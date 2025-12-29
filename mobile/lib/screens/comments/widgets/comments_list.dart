// ABOUTME: Comments list widget with loading, error, and empty states
// ABOUTME: Renders threaded comments using CommentThread widget

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

        if (state.topLevelComments.isEmpty) {
          return CommentsEmptyState(isClassicVine: isOriginalVine);
        }

        return ListView.builder(
          controller: scrollController,
          padding: const EdgeInsets.only(bottom: 80),
          itemCount: state.topLevelComments.length,
          itemBuilder: (context, index) =>
              CommentThread(node: state.topLevelComments[index]),
        );
      },
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) => Center(
    child: Semantics(
      identifier: 'comments_loading_indicator',
      label: 'Loading comments',
      child: const CircularProgressIndicator(color: Colors.white),
    ),
  );
}

class _ErrorState extends StatelessWidget {
  const _ErrorState();

  @override
  Widget build(BuildContext context) => const Center(
    child: Text('Failed to load comments', style: TextStyle(color: Colors.red)),
  );
}
