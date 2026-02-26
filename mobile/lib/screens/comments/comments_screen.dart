// ABOUTME: Screen for displaying and posting comments on videos with threaded reply support
// ABOUTME: Uses BLoC pattern with Nostr Kind 1111 (NIP-22) events for comments

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:models/models.dart' hide NIP71VideoKinds;
import 'package:openvine/blocs/comments/comments_bloc.dart';
import 'package:openvine/constants/nip71_migration.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/overlay_visibility_provider.dart';
import 'package:openvine/screens/comments/widgets/widgets.dart';
import 'package:openvine/utils/nostr_key_utils.dart';

/// Maps [CommentsError] to user-facing strings.
/// TODO(l10n): Replace with context.l10n when localization is added.
String _errorToString(CommentsError error) {
  return switch (error) {
    CommentsError.loadFailed => 'Failed to load comments',
    CommentsError.notAuthenticated => 'Please sign in to comment',
    CommentsError.postCommentFailed => 'Failed to post comment',
    CommentsError.postReplyFailed => 'Failed to post reply',
    CommentsError.deleteCommentFailed => 'Failed to delete comment',
    CommentsError.likeFailed => 'Failed to like comment',
    CommentsError.reportFailed => 'Failed to report comment',
    CommentsError.blockFailed => 'Failed to block user',
  };
}

/// Dynamic title widget that shows comment count and a "# new" pill
/// when real-time comments arrive.
/// Initially shows the count from video metadata, then updates to loaded count.
class _CommentsTitle extends StatelessWidget {
  const _CommentsTitle({
    required this.initialCount,
    required this.onNewCommentsPillTap,
  });

  final int initialCount;

  /// Called when the user taps the "# new" pill.
  final VoidCallback onNewCommentsPillTap;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CommentsBloc, CommentsState>(
      buildWhen: (prev, next) =>
          prev.comments.length != next.comments.length ||
          prev.status != next.status ||
          prev.newCommentCount != next.newCommentCount,
      builder: (context, state) {
        // Use loaded count if available, otherwise use initial count
        final count = state.status == CommentsStatus.success
            ? state.comments.length
            : initialCount;

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$count ${count == 1 ? 'Comment' : 'Comments'}',
              style: GoogleFonts.bricolageGrotesque(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                height: 32 / 24,
                letterSpacing: 0.15,
                color: VineTheme.onSurface,
              ),
            ),
            if (state.newCommentCount > 0) ...[
              const SizedBox(width: 8),
              NewCommentsPill(
                count: state.newCommentCount,
                onTap: () {
                  onNewCommentsPillTap();
                  context.read<CommentsBloc>().add(
                    const NewCommentsAcknowledged(),
                  );
                },
              ),
            ],
          ],
        );
      },
    );
  }
}

class CommentsScreen extends ConsumerWidget {
  const CommentsScreen({
    required this.videoEvent,
    required this.sheetScrollController,
    this.initialCommentCount,
    this.onCommentCountChanged,
    super.key,
  });

  final VideoEvent videoEvent;
  final ScrollController sheetScrollController;

  /// Optional live comment count from the caller (e.g. from
  /// [VideoInteractionsBloc]).  When provided this value is shown in the
  /// header while comments are still loading, avoiding the stale count
  /// stored in the video event metadata.
  final int? initialCommentCount;

  /// Called whenever the total comment count changes (initial load or
  /// real-time updates).  The caller can use this to keep external state
  /// (e.g. the video feed sidebar count) in sync.
  final ValueChanged<int>? onCommentCountChanged;

  /// Shows comments as a modal bottom sheet overlay
  static Future<void> show(
    BuildContext context,
    VideoEvent video, {
    int? initialCommentCount,
    ValueChanged<int>? onCommentCountChanged,
  }) {
    final container = ProviderScope.containerOf(context, listen: false);
    final overlayNotifier = container.read(overlayVisibilityProvider.notifier);
    overlayNotifier.setModalOpen(true);

    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      builder: (builderContext) {
        final keyboardHeight = MediaQuery.of(builderContext).viewInsets.bottom;
        final isKeyboardOpen = keyboardHeight > 0;

        return DraggableScrollableSheet(
          initialChildSize: isKeyboardOpen ? 0.93 : 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.93,
          snap: true,
          snapSizes: const [0.7, 0.93],
          builder: (context, scrollController) => CommentsScreen(
            videoEvent: video,
            sheetScrollController: scrollController,
            initialCommentCount: initialCommentCount,
            onCommentCountChanged: onCommentCountChanged,
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

    // Sync providers — watch normally
    final likesRepository = ref.watch(likesRepositoryProvider);
    final contentBlocklistService = ref.watch(contentBlocklistServiceProvider);

    // Async providers — pass as Future (per Critical Review Issue 1)
    // Pattern from share_video_menu.dart:2065
    final contentReportingServiceFuture = ref.read(
      contentReportingServiceProvider.future,
    );
    final muteServiceFuture = ref.read(muteServiceProvider.future);

    // Mention search dependencies
    final userProfileService = ref.watch(userProfileServiceProvider);
    final followRepository = ref.watch(followRepositoryProvider);

    // Use original comments count for pagination hint
    // This helps determine hasMoreContent more accurately than page size heuristic
    final initialCount = videoEvent.originalComments;

    return BlocProvider<CommentsBloc>(
      create: (_) => CommentsBloc(
        commentsRepository: commentsRepository,
        authService: authService,
        likesRepository: likesRepository,
        contentReportingServiceFuture: contentReportingServiceFuture,
        muteServiceFuture: muteServiceFuture,
        contentBlocklistService: contentBlocklistService,
        rootEventId: videoEvent.id,
        rootEventKind: NIP71VideoKinds.addressableShortVideo,
        rootAuthorPubkey: videoEvent.pubkey,
        rootAddressableId: videoEvent.addressableId,
        initialTotalCount: initialCount,
        userProfileService: userProfileService,
        followRepository: followRepository,
      )..add(const CommentsLoadRequested()),
      child: BlocListener<CommentsBloc, CommentsState>(
        listenWhen: (prev, next) =>
            prev.commentsById.length != next.commentsById.length,
        listener: (context, state) {
          onCommentCountChanged?.call(state.commentsById.length);
        },
        child: VineBottomSheet(
          title: _CommentsTitle(
            initialCount:
                initialCommentCount ?? videoEvent.originalComments ?? 0,
            onNewCommentsPillTap: () {
              // Scroll to top and acknowledge new comments.
              // The sheetScrollController drives the DraggableScrollableSheet's
              // inner list, so animating to 0 scrolls the comments list to top.
              if (sheetScrollController.hasClients) {
                sheetScrollController.animateTo(
                  0,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOut,
                );
              }
            },
          ),
          trailing: const _CommentsSortToggle(),
          body: _CommentsScreenBody(
            videoEvent: videoEvent,
            sheetScrollController: sheetScrollController,
          ),
          bottomInput: const _MainCommentInput(),
        ),
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
          prev.isPosting != next.isPosting ||
          prev.mentionSuggestions != next.mentionSuggestions,
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
          mentionSuggestions: state.mentionSuggestions,
          onMentionQuery: (query) {
            if (query.isEmpty) {
              context.read<CommentsBloc>().add(
                const MentionSuggestionsCleared(),
              );
            } else {
              context.read<CommentsBloc>().add(MentionSearchRequested(query));
            }
          },
          onMentionSelected: (npub, displayName) {
            context.read<CommentsBloc>()
              ..add(MentionRegistered(displayName: displayName, npub: npub))
              ..add(const MentionSuggestionsCleared());
          },
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

/// Sort toggle button that cycles: New → Top → Old → New
class _CommentsSortToggle extends StatelessWidget {
  const _CommentsSortToggle();

  @override
  Widget build(BuildContext context) {
    return BlocSelector<CommentsBloc, CommentsState, CommentsSortMode>(
      selector: (state) => state.sortMode,
      builder: (context, sortMode) {
        final (icon, label) = switch (sortMode) {
          CommentsSortMode.newest => (Icons.schedule, 'New'),
          CommentsSortMode.topEngagement => (
            Icons.local_fire_department,
            'Top',
          ),
          CommentsSortMode.oldest => (Icons.history, 'Old'),
        };

        return Semantics(
          identifier: 'comments_sorting',
          button: true,
          label: 'Comments sorting',
          child: GestureDetector(
            onTap: () {
              final nextMode = switch (sortMode) {
                CommentsSortMode.newest => CommentsSortMode.topEngagement,
                CommentsSortMode.topEngagement => CommentsSortMode.oldest,
                CommentsSortMode.oldest => CommentsSortMode.newest,
              };
              context.read<CommentsBloc>().add(
                CommentsSortModeChanged(nextMode),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: VineTheme.containerLow,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 14, color: VineTheme.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Text(
                    label,
                    style: VineTheme.bodyFont(
                      fontSize: 12,
                      color: VineTheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
