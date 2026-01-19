// ABOUTME: Screen for displaying and posting comments on videos with threaded reply support
// ABOUTME: Uses BLoC pattern with Nostr Kind 1111 (NIP-22) events for comments

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:openvine/blocs/comments/comments_bloc.dart';
import 'package:openvine/constants/nip71_migration.dart';
import 'package:models/models.dart' hide NIP71VideoKinds;
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/overlay_visibility_provider.dart';
import 'package:openvine/screens/comments/widgets/widgets.dart';
import 'package:openvine/theme/vine_theme.dart';
import 'package:openvine/utils/nostr_key_utils.dart';
import 'package:openvine/widgets/bottom_sheets/vine_bottom_sheet.dart';

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

/// Dynamic title widget that shows comment count
/// Initially shows the count from video metadata, then updates to loaded count
class _CommentsTitle extends StatelessWidget {
  const _CommentsTitle({required this.initialCount});

  final int initialCount;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CommentsBloc, CommentsState>(
      buildWhen: (prev, next) =>
          prev.comments.length != next.comments.length ||
          prev.status != next.status,
      builder: (context, state) {
        // Use loaded count if available, otherwise use initial count
        final count = state.status == CommentsStatus.success
            ? state.comments.length
            : initialCount;

        return Text(
          '$count ${count == 1 ? 'Comment' : 'Comments'}',
          style: GoogleFonts.bricolageGrotesque(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            height: 32 / 24,
            letterSpacing: 0.15,
            color: VineTheme.onSurface,
          ),
        );
      },
    );
  }
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
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (builderContext) {
        final keyboardHeight = MediaQuery.of(builderContext).viewInsets.bottom;
        final isKeyboardOpen = keyboardHeight > 0;

        return DraggableScrollableSheet(
          initialChildSize: isKeyboardOpen ? 0.93 : 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.93,
          snap: true,
          snapSizes: [0.7, 0.93],
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
        );
      },
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
      child: VineBottomSheet(
        title: _CommentsTitle(initialCount: videoEvent.originalComments ?? 0),
        body: _CommentsScreenBody(
          videoEvent: videoEvent,
          sheetScrollController: sheetScrollController,
        ),
        bottomInput: const _MainCommentInput(),
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
      child: SizedBox(
        child: CommentsList(
          isOriginalVine: videoEvent.isOriginalVine,
          scrollController: sheetScrollController,
        ),
      ),
    );
  }
}

/// Main comment input widget that reads from CommentsBloc state
class _MainCommentInput extends ConsumerStatefulWidget {
  const _MainCommentInput();

  @override
  ConsumerState<_MainCommentInput> createState() => _MainCommentInputState();
}

class _MainCommentInputState extends ConsumerState<_MainCommentInput> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    final state = context.read<CommentsBloc>().state;
    _controller = TextEditingController(text: state.mainInputText);
    _focusNode = FocusNode();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<CommentsBloc, CommentsState>(
      listenWhen: (prev, next) =>
          prev.activeReplyCommentId != next.activeReplyCommentId,
      listener: (context, state) {
        // Focus input when reply is activated
        if (state.activeReplyCommentId != null) {
          _focusNode.requestFocus();
        }
      },
      buildWhen: (prev, next) =>
          prev.mainInputText != next.mainInputText ||
          prev.replyInputText != next.replyInputText ||
          prev.activeReplyCommentId != next.activeReplyCommentId ||
          prev.isPosting != next.isPosting,
      builder: (context, state) {
        final isReplyMode = state.activeReplyCommentId != null;
        final inputText = isReplyMode
            ? state.replyInputText
            : state.mainInputText;

        // Sync controller with state
        if (_controller.text != inputText) {
          _controller.text = inputText;
          _controller.selection = TextSelection.collapsed(
            offset: inputText.length,
          );
        }

        // Get display name of user being replied to
        String? replyToDisplayName;
        String? replyToAuthorPubkey;
        if (isReplyMode) {
          // Find the comment being replied to
          final replyComment = state.comments.firstWhere(
            (c) => c.id == state.activeReplyCommentId,
            orElse: () => throw StateError('Reply comment not found'),
          );
          replyToAuthorPubkey = replyComment.authorPubkey;

          // Fetch profile for display name
          final userProfileService = ref.watch(userProfileServiceProvider);
          final profile = userProfileService.getCachedProfile(
            replyToAuthorPubkey,
          );

          // Get display name with fallback
          replyToDisplayName =
              profile?.displayName ??
              profile?.name ??
              NostrKeyUtils.encodePubKey(replyToAuthorPubkey);
        }

        return CommentInput(
          controller: _controller,
          focusNode: _focusNode,
          isPosting: state.isPosting,
          replyToDisplayName: replyToDisplayName,
          onChanged: (text) {
            context.read<CommentsBloc>().add(
              CommentTextChanged(text, commentId: state.activeReplyCommentId),
            );
          },
          onSubmit: () {
            if (isReplyMode) {
              context.read<CommentsBloc>().add(
                CommentSubmitted(
                  parentCommentId: state.activeReplyCommentId,
                  parentAuthorPubkey: replyToAuthorPubkey,
                ),
              );
            } else {
              context.read<CommentsBloc>().add(const CommentSubmitted());
            }
          },
          onCancelReply: () {
            context.read<CommentsBloc>().add(
              CommentReplyToggled(state.activeReplyCommentId!),
            );
          },
        );
      },
    );
  }
}
