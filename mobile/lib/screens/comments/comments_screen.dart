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
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/screens/comments/widgets/widgets.dart';
import 'package:openvine/utils/pause_aware_modals.dart';

/// Maps [CommentsError] to user-facing strings.
/// TODO(l10n): Replace with context.l10n when localization is added.
String _errorToString(CommentsError error) {
  return switch (error) {
    CommentsError.loadFailed => 'Failed to load comments',
    CommentsError.notAuthenticated => 'Please sign in to comment',
    CommentsError.postCommentFailed => 'Failed to post comment',
    CommentsError.postReplyFailed => 'Failed to post reply',
    CommentsError.deleteCommentFailed => 'Failed to delete comment',
    CommentsError.voteFailed => 'Failed to vote on comment',
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

/// Container for the comments bottom sheet. Not instantiable — use
/// [CommentsScreen.show] to present the sheet.
abstract final class CommentsScreen {
  /// Shows comments as a modal bottom sheet overlay.
  ///
  /// Flows through [VineBottomSheet.show] (via
  /// `showVideoPausingVineBottomSheet`) so the sheet inherits the
  /// tap-outside-to-dismiss behaviour, snap support, and
  /// overlay-visibility integration shared with other Vine bottom sheets.
  static Future<void> show(
    BuildContext context,
    VideoEvent video, {
    int? initialCommentCount,
    ValueChanged<int>? onCommentCountChanged,
  }) {
    final container = ProviderScope.containerOf(context, listen: false);

    // Synchronously available repositories / services.
    final commentsRepository = container.read(commentsRepositoryProvider);
    final authService = container.read(authServiceProvider);
    final likesRepository = container.read(likesRepositoryProvider);
    final contentBlocklistRepository = container.read(
      contentBlocklistRepositoryProvider,
    );
    // Async provider — pass as Future per the established pattern.
    final contentReportingServiceFuture = container.read(
      contentReportingServiceProvider.future,
    );
    final profileRepository = container.read(profileRepositoryProvider);
    final followRepository = container.read(followRepositoryProvider);

    // The draggable scroll controller is created inside buildScrollBody but
    // is also needed by the title's "new comments" pill (which lives above
    // the scrollable region). Share it through a closure-captured holder.
    ScrollController? activeScrollController;

    return context.showVideoPausingVineBottomSheet<void>(
      snap: true,
      snapSizes: const [0.7, 0.93],
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.93,
      // Wrap the whole sheet subtree in a single BlocProvider so every
      // slot (title, trailing, bottomInput, buildScrollBody) shares the
      // same CommentsBloc. BlocProvider owns lifecycle — it closes the
      // BLoC automatically when the sheet is disposed, so we don't need
      // a manual try/finally around the await.
      contentWrapper: (context, child) => BlocProvider<CommentsBloc>(
        create: (_) => CommentsBloc(
          commentsRepository: commentsRepository,
          authService: authService,
          likesRepository: likesRepository,
          contentReportingServiceFuture: contentReportingServiceFuture,
          contentBlocklistRepository: contentBlocklistRepository,
          rootEventId: video.id,
          rootEventKind: NIP71VideoKinds.addressableShortVideo,
          rootAuthorPubkey: video.pubkey,
          rootAddressableId: video.addressableId,
          initialTotalCount: video.originalComments,
          profileRepository: profileRepository,
          followRepository: followRepository,
        )..add(const CommentsLoadRequested()),
        child: BlocListener<CommentsBloc, CommentsState>(
          listenWhen: (prev, next) =>
              prev.commentsById.length != next.commentsById.length,
          listener: (_, state) {
            onCommentCountChanged?.call(state.commentsById.length);
          },
          child: child,
        ),
      ),
      title: _CommentsTitle(
        initialCount: initialCommentCount ?? video.originalComments ?? 0,
        onNewCommentsPillTap: () {
          final controller = activeScrollController;
          if (controller != null && controller.hasClients) {
            controller.animateTo(
              0,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        },
      ),
      trailing: const _CommentsSortToggle(),
      bottomInput: const _MainCommentInput(),
      buildScrollBody: (scrollController) {
        activeScrollController = scrollController;
        return _CommentsScreenBody(
          videoEvent: video,
          sheetScrollController: scrollController,
        );
      },
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
          showClassicVineNotice: videoEvent.isVintageRecoveredVine,
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
          prev.activeReplyCommentId != next.activeReplyCommentId ||
          prev.activeEditCommentId != next.activeEditCommentId,
      listener: (context, state) {
        // Focus input when reply or edit is activated
        if (state.activeReplyCommentId != null ||
            state.activeEditCommentId != null) {
          _focusNode.requestFocus();
        }
      },
      buildWhen: (prev, next) =>
          prev.mainInputText != next.mainInputText ||
          prev.replyInputText != next.replyInputText ||
          prev.activeReplyCommentId != next.activeReplyCommentId ||
          prev.activeEditCommentId != next.activeEditCommentId ||
          prev.editInputText != next.editInputText ||
          prev.isPosting != next.isPosting ||
          prev.mentionSuggestions != next.mentionSuggestions,
      builder: (context, state) {
        final isReplyMode = state.activeReplyCommentId != null;
        final isEditMode = state.activeEditCommentId != null;
        final inputText = isEditMode
            ? state.editInputText
            : isReplyMode
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
          final profile = ref
              .watch(userProfileReactiveProvider(replyToAuthorPubkey))
              .value;

          // Get display name with fallback
          replyToDisplayName =
              profile?.displayName ??
              profile?.name ??
              UserProfile.generatedNameFor(replyToAuthorPubkey);
        }

        return CommentInput(
          controller: _controller,
          focusNode: _focusNode,
          isPosting: state.isPosting,
          replyToDisplayName: replyToDisplayName,
          isEditing: isEditMode,
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
            if (isEditMode) {
              context.read<CommentsBloc>().add(const CommentEditSubmitted());
            } else if (isReplyMode) {
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
          onCancelEdit: () {
            context.read<CommentsBloc>().add(const CommentEditModeCancelled());
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
                    style: VineTheme.labelMediumFont(
                      color: VineTheme.onSurfaceVariant,
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
