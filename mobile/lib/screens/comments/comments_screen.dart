// ABOUTME: Screen for displaying and posting comments on videos with threaded reply support
// ABOUTME: Uses BLoC pattern with Nostr Kind 1111 (NIP-22) events for comments

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/blocs/comments/comments_bloc.dart';
import 'package:openvine/constants/nip71_migration.dart';
import 'package:openvine/models/video_event.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/overlay_visibility_provider.dart';
import 'package:openvine/screens/comments/widgets/widgets.dart';

/// Maps [CommentsError] to user-facing strings.
/// TODO(l10n): Replace with context.l10n when localization is added.
String _errorToString(CommentsError error) {
  return switch (error) {
    CommentsError.loadFailed => 'Failed to load comments',
    CommentsError.notAuthenticated => 'Please sign in to comment',
    CommentsError.postCommentFailed => 'Failed to post comment',
    CommentsError.postReplyFailed => 'Failed to post reply',
    CommentsError.deleteCommentFailed => 'Failed to delete comment',
  };
}

class CommentsScreen extends ConsumerWidget {
  const CommentsScreen({
    required this.videoEvent,
    required this.sheetScrollController,
    super.key,
  });

  final VideoEvent videoEvent;
  final ScrollController sheetScrollController;

  /// Shows comments as a modal bottom sheet overlay
  static Future<void> show(BuildContext context, VideoEvent video) {
    final container = ProviderScope.containerOf(context, listen: false);
    final overlayNotifier = container.read(overlayVisibilityProvider.notifier);
    overlayNotifier.setModalOpen(true);

    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        builder: (context, scrollController) => DecoratedBox(
          decoration: const BoxDecoration(
            color: Colors.black87,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: CommentsScreen(
            videoEvent: video,
            sheetScrollController: scrollController,
          ),
        ),
      ),
    ).whenComplete(() {
      overlayNotifier.setModalOpen(false);
    });
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final commentsRepository = ref.watch(commentsRepositoryProvider);
    final authService = ref.watch(authServiceProvider);

    return BlocProvider<CommentsBloc>(
      create: (_) => CommentsBloc(
        commentsRepository: commentsRepository,
        authService: authService,
        rootEventId: videoEvent.id,
        rootEventKind: NIP71VideoKinds.addressableShortVideo,
        rootAuthorPubkey: videoEvent.pubkey,
      )..add(const CommentsLoadRequested()),
      child: _CommentsScreenBody(
        videoEvent: videoEvent,
        sheetScrollController: sheetScrollController,
      ),
    );
  }
}

/// Body widget with error listener
class _CommentsScreenBody extends StatelessWidget {
  const _CommentsScreenBody({
    required this.videoEvent,
    required this.sheetScrollController,
  });

  final VideoEvent videoEvent;
  final ScrollController sheetScrollController;

  @override
  Widget build(BuildContext context) {
    return BlocListener<CommentsBloc, CommentsState>(
      listenWhen: (prev, next) =>
          prev.error != next.error && next.error != null,
      listener: (context, state) {
        if (state.error != null) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(_errorToString(state.error!))));
          context.read<CommentsBloc>().add(const CommentErrorCleared());
        }
      },
      child: Column(
        children: [
          const CommentsDragHandle(),
          CommentsHeader(onClose: () => Navigator.pop(context)),
          const Divider(color: Colors.white24, height: 1),
          Expanded(
            child: CommentsList(
              isOriginalVine: videoEvent.isOriginalVine,
              scrollController: sheetScrollController,
            ),
          ),
          const _MainCommentInput(),
        ],
      ),
    );
  }
}

/// Main comment input widget that reads from CommentsBloc state
class _MainCommentInput extends StatefulWidget {
  const _MainCommentInput();

  @override
  State<_MainCommentInput> createState() => _MainCommentInputState();
}

class _MainCommentInputState extends State<_MainCommentInput> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    final state = context.read<CommentsBloc>().state;
    _controller = TextEditingController(text: state.mainInputText);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CommentsBloc, CommentsState>(
      buildWhen: (prev, next) =>
          prev.mainInputText != next.mainInputText ||
          prev.isPosting != next.isPosting,
      builder: (context, state) {
        // Sync controller with state (for when state changes externally,
        // e.g., after post clears the text)
        if (_controller.text != state.mainInputText) {
          _controller.text = state.mainInputText;
          _controller.selection = TextSelection.collapsed(
            offset: state.mainInputText.length,
          );
        }

        return CommentInput(
          controller: _controller,
          isPosting: state.isPosting && state.activeReplyCommentId == null,
          onChanged: (text) {
            context.read<CommentsBloc>().add(CommentTextChanged(text));
          },
          onSubmit: () {
            context.read<CommentsBloc>().add(const CommentSubmitted());
          },
        );
      },
    );
  }
}
