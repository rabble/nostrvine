// ABOUTME: Screen for displaying and posting comments on videos with threaded reply support
// ABOUTME: Uses BLoC pattern with Nostr Kind 1111 (NIP-22) events for comments

import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:models/models.dart' hide NIP71VideoKinds;
import 'package:openvine/blocs/comments/comment_composer/comment_composer_bloc.dart';
import 'package:openvine/blocs/comments/comment_reactions/comment_reactions_bloc.dart';
import 'package:openvine/blocs/comments/comments_list/comments_list_bloc.dart';
import 'package:openvine/blocs/comments/comments_surface_performance_telemetry.dart';
import 'package:openvine/constants/nip71_migration.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/video_reply_context.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/providers/video_reply_context_provider.dart';
import 'package:openvine/screens/comments/widgets/widgets.dart';
import 'package:openvine/screens/video_recorder_screen.dart';
import 'package:openvine/utils/pause_aware_modals.dart';
import 'package:openvine/widgets/video_feed_item/live_engagement_counts.dart';

/// Maps any of the three per-bloc errors to a localized user-facing string.
///
/// Kept as plain top-level functions taking [AppLocalizations] so the snackbar
/// `BlocListener` callbacks can dispatch in one line without re-reading
/// `context.l10n` on every emit.
String _listErrorToString(AppLocalizations l10n, CommentsListError error) {
  return switch (error) {
    CommentsListError.loadFailed => l10n.commentsErrorLoadFailed,
  };
}

String _composerErrorToString(AppLocalizations l10n, ComposerError error) {
  return switch (error) {
    ComposerError.notAuthenticated => l10n.commentsErrorNotAuthenticatedComment,
    ComposerError.postCommentFailed => l10n.commentsErrorPostCommentFailed,
    ComposerError.postReplyFailed => l10n.commentsErrorPostReplyFailed,
    ComposerError.editFailed => l10n.commentsErrorEditFailed,
  };
}

String _reactionsErrorToString(AppLocalizations l10n, ReactionsError error) {
  return switch (error) {
    ReactionsError.notAuthenticated =>
      l10n.commentsErrorNotAuthenticatedInteract,
    ReactionsError.voteFailed => l10n.commentsErrorVoteFailed,
    ReactionsError.reportFailed => l10n.commentsErrorReportFailed,
    ReactionsError.blockFailed => l10n.commentsErrorBlockFailed,
    ReactionsError.deleteCommentFailed => l10n.commentsErrorDeleteFailed,
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
    return BlocBuilder<CommentsListBloc, CommentsListState>(
      buildWhen: (prev, next) =>
          prev.commentsById.length != next.commentsById.length ||
          prev.status != next.status ||
          prev.newCommentCount != next.newCommentCount,
      builder: (context, state) {
        // Use loaded count if available, otherwise use initial count.
        final count = state.status == CommentsStatus.success
            ? state.commentsById.length
            : initialCount;

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              context.l10n.commentsHeaderCount(count),
              style: VineTheme.titleMediumFont(color: VineTheme.onSurface),
            ),
            if (state.newCommentCount > 0) ...[
              const SizedBox(width: 8),
              NewCommentsPill(
                count: state.newCommentCount,
                onTap: () {
                  onNewCommentsPillTap();
                  context.read<CommentsListBloc>().add(
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
  /// Wires three BLoCs ([CommentsListBloc], [CommentComposerBloc],
  /// [CommentReactionsBloc]) via [MultiBlocProvider] and adds [BlocListener]s
  /// that bridge composer and reactions outbox signals into list-bloc store
  /// mutations.
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
    final contentReportingServiceFuture = container.read(
      contentReportingServiceProvider.future,
    );
    final profileRepository = container.read(profileRepositoryProvider);
    final followRepository = container.read(followRepositoryProvider);
    final showVideoReplies = container.read(
      isFeatureEnabledProvider(FeatureFlag.videoReplies),
    );
    final seedCommentCount = initialCommentCount ?? liveCommentCountSeed(video);
    final surfaceTelemetry = CommentsSurfacePerformanceTelemetry()
      ..start(
        videoRepliesEnabled: showVideoReplies,
        initialCount: seedCommentCount,
      );

    // The draggable scroll controller is created inside buildScrollBody but
    // is also needed by the title's "new comments" pill (which lives above
    // the scrollable region). Share it through a closure-captured holder.
    ScrollController? activeScrollController;

    return context
        .showVideoPausingVineBottomSheet<void>(
          snap: true,
          snapSizes: const [0.7, 0.93],
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.93,
          // Wrap the whole sheet subtree in a MultiBlocProvider so every slot
          // (title, trailing, bottomInput, buildScrollBody) shares the same
          // three blocs. BlocProvider owns lifecycle — it closes each BLoC
          // automatically when the sheet is disposed, so we don't need a manual
          // try/finally around the await.
          contentWrapper: (context, child) => MultiBlocProvider(
            providers: [
              BlocProvider<CommentsListBloc>(
                create: (_) => CommentsListBloc(
                  commentsRepository: commentsRepository,
                  rootEventId: video.id,
                  rootEventKind: NIP71VideoKinds.addressableShortVideo,
                  rootAuthorPubkey: video.pubkey,
                  rootAddressableId: video.addressableId,
                  initialTotalCount: seedCommentCount,
                  includeVideoReplies: showVideoReplies,
                )..add(const CommentsLoadRequested()),
              ),
              BlocProvider<CommentComposerBloc>(
                create: (innerContext) {
                  // Captured at create-time. CommentsListBloc is provided above
                  // in the same MultiBlocProvider so it's available here via
                  // inheritance; the reference is stable for the sheet's life.
                  // The callback re-reads `state.commentsById` on every search
                  // so suggestions reflect the latest loaded comments.
                  final listBloc = innerContext.read<CommentsListBloc>();
                  return CommentComposerBloc(
                    commentsRepository: commentsRepository,
                    authService: authService,
                    rootEventId: video.id,
                    rootEventKind: NIP71VideoKinds.addressableShortVideo,
                    rootAuthorPubkey: video.pubkey,
                    rootAddressableId: video.addressableId,
                    profileRepository: profileRepository,
                    mentionCandidatePubkeysProvider: () => <String>[
                      // Thread participants first — restored after the split
                      // (pre-split CommentsBloc seeded these from state.commentsById).
                      ...listBloc.state.commentsById.values.map(
                        (c) => c.authorPubkey,
                      ),
                      ...followRepository.followingPubkeys,
                    ],
                  );
                },
              ),
              BlocProvider<CommentReactionsBloc>(
                create: (_) => CommentReactionsBloc(
                  authService: authService,
                  likesRepository: likesRepository,
                  commentsRepository: commentsRepository,
                  contentReportingServiceFuture: contentReportingServiceFuture,
                  contentBlocklistRepository: contentBlocklistRepository,
                  followRepository: followRepository,
                  rootEventId: video.id,
                  rootAddressableId: video.addressableId,
                ),
              ),
            ],
            child: OutboxBridges(
              onCommentCountChanged: onCommentCountChanged,
              child: child,
            ),
          ),
          title: _CommentsTitle(
            initialCount: seedCommentCount ?? 0,
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
            return CommentsSheetLoadTelemetry(
              telemetry: surfaceTelemetry,
              child: _CommentsScreenBody(
                videoEvent: video,
                sheetScrollController: scrollController,
              ),
            );
          },
        )
        .whenComplete(
          surfaceTelemetry.completeDismissed,
        );
  }
}

/// Wires the composer / reactions outbox signals into [CommentsListBloc] store
/// mutations. Also triggers a vote-count batch fetch on the reactions bloc
/// every time the loaded-comment set changes.
///
/// Public-by-test only: it has no callers outside `CommentsScreen.show` but is
/// exposed via [visibleForTesting] so the bridge wiring can be exercised
/// directly with mock blocs.
@visibleForTesting
class OutboxBridges extends StatelessWidget {
  const OutboxBridges({
    required this.onCommentCountChanged,
    required this.child,
    super.key,
  });

  final ValueChanged<int>? onCommentCountChanged;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        // Notify host about comment-count changes for the trailing badge in
        // the parent video feed.
        BlocListener<CommentsListBloc, CommentsListState>(
          listenWhen: (prev, next) =>
              prev.commentsById.length != next.commentsById.length,
          listener: (_, state) {
            onCommentCountChanged?.call(state.commentsById.length);
          },
        ),
        // When new non-placeholder ids appear in the store, fetch their vote
        // counts. Only the DIFF is requested (not the whole set) so a
        // viral-video feed doesn't redundantly hammer the relay with the
        // same N-1 already-known ids on every emit. The handler is
        // restartable, so a slower in-flight fetch can't clobber a fresher
        // one — see CommentReactionsBloc.on<CommentVoteCountsFetchRequested>.
        BlocListener<CommentsListBloc, CommentsListState>(
          listenWhen: (prev, next) =>
              !_idSetsEqual(prev.commentsById, next.commentsById),
          listener: (ctx, state) {
            final prevKeys = ctx
                .read<CommentReactionsBloc>()
                .state
                .commentUpvoteCounts
                .keys
                .toSet();
            final newIds = state.commentsById.keys
                .where(
                  (id) =>
                      !id.startsWith('pending_comment_') &&
                      !prevKeys.contains(id),
                )
                .toList();
            if (newIds.isEmpty) return;
            ctx.read<CommentReactionsBloc>().add(
              CommentVoteCountsFetchRequested(newIds),
            );
          },
        ),
        // Composer → ListBloc outbox bridge.
        BlocListener<CommentComposerBloc, CommentComposerState>(
          listenWhen: (prev, next) =>
              next.outbox != null && prev.outbox != next.outbox,
          listener: _bridgeComposerOutbox,
        ),
        // Reactions → ListBloc outbox bridge.
        BlocListener<CommentReactionsBloc, CommentReactionsState>(
          listenWhen: (prev, next) =>
              next.outbox != null && prev.outbox != next.outbox,
          listener: _bridgeReactionsOutbox,
        ),
      ],
      child: child,
    );
  }

  static bool _idSetsEqual(
    Map<String, Object?> a,
    Map<String, Object?> b,
  ) {
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (!b.containsKey(key)) return false;
    }
    return true;
  }

  static void _bridgeComposerOutbox(
    BuildContext ctx,
    CommentComposerState state,
  ) {
    final outbox = state.outbox;
    if (outbox == null) return;
    final listBloc = ctx.read<CommentsListBloc>();
    switch (outbox) {
      case ComposerOutboxInsertPlaceholder(:final placeholder):
        listBloc.add(OptimisticCommentInserted(placeholder));
      case ComposerOutboxConfirmPlaceholder(
        :final placeholderId,
        :final confirmed,
      ):
        listBloc.add(
          OptimisticCommentConfirmed(
            placeholderId: placeholderId,
            confirmed: confirmed,
          ),
        );
      case ComposerOutboxRollbackPlaceholder(:final placeholderId):
        listBloc.add(OptimisticCommentRolledBack(placeholderId));
      case ComposerOutboxReplaceComment(:final oldId, :final newComment):
        listBloc.add(
          CommentReplacedInStore(oldId: oldId, newComment: newComment),
        );
    }
    ctx.read<CommentComposerBloc>().add(const ComposerOutboxConsumed());
  }

  static void _bridgeReactionsOutbox(
    BuildContext ctx,
    CommentReactionsState state,
  ) {
    final outbox = state.outbox;
    if (outbox == null) return;
    final listBloc = ctx.read<CommentsListBloc>();
    switch (outbox) {
      case ReactionsOutboxRemoveComment(:final commentId):
        listBloc.add(CommentRemovedFromStore(commentId));
      case ReactionsOutboxRemoveByAuthor(:final authorPubkey):
        listBloc.add(CommentsRemovedByAuthorFromStore(authorPubkey));
    }
    ctx.read<CommentReactionsBloc>().add(const ReactionsOutboxConsumed());
  }
}

/// Tracks perceived comments-sheet visibility and initial data completion.
///
/// Public-by-test only: production callers should use [CommentsScreen.show].
@visibleForTesting
class CommentsSheetLoadTelemetry extends StatefulWidget {
  const CommentsSheetLoadTelemetry({
    required this.telemetry,
    required this.child,
    super.key,
  });

  final CommentsSurfacePerformanceTelemetry telemetry;
  final Widget child;

  @override
  State<CommentsSheetLoadTelemetry> createState() =>
      _CommentsSheetLoadTelemetryState();
}

class _CommentsSheetLoadTelemetryState
    extends State<CommentsSheetLoadTelemetry> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.telemetry.markVisible();
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<CommentsListBloc, CommentsListState>(
      listenWhen: (prev, next) =>
          prev.status == CommentsStatus.loading &&
          (next.status == CommentsStatus.success ||
              next.status == CommentsStatus.failure),
      listener: (_, state) {
        switch (state.status) {
          case CommentsStatus.success:
            unawaited(
              widget.telemetry.completeDataLoaded(
                itemCount: state.commentsById.length,
                hasMore: state.hasMoreContent,
                sortMode: state.sortMode.name,
              ),
            );
          case CommentsStatus.failure:
            unawaited(widget.telemetry.completeFailure());
          case CommentsStatus.initial:
          case CommentsStatus.loading:
            break;
        }
      },
      child: widget.child,
    );
  }
}

/// Body widget with per-bloc error listeners that surface snackbars.
class _CommentsScreenBody extends StatelessWidget {
  const _CommentsScreenBody({
    required this.videoEvent,
    required this.sheetScrollController,
  });

  final VideoEvent videoEvent;
  final ScrollController sheetScrollController;

  void _snack(BuildContext ctx, String message) {
    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        final showVideoReplies = ref.watch(
          isFeatureEnabledProvider(FeatureFlag.videoReplies),
        );
        return MultiBlocListener(
          listeners: [
            BlocListener<CommentsListBloc, CommentsListState>(
              listenWhen: (prev, next) =>
                  prev.error != next.error && next.error != null,
              listener: (ctx, state) {
                _snack(ctx, _listErrorToString(ctx.l10n, state.error!));
                ctx.read<CommentsListBloc>().add(
                  const CommentsListErrorCleared(),
                );
              },
            ),
            BlocListener<CommentComposerBloc, CommentComposerState>(
              listenWhen: (prev, next) =>
                  prev.error != next.error && next.error != null,
              listener: (ctx, state) {
                _snack(ctx, _composerErrorToString(ctx.l10n, state.error!));
                ctx.read<CommentComposerBloc>().add(
                  const CommentComposerErrorCleared(),
                );
              },
            ),
            BlocListener<CommentReactionsBloc, CommentReactionsState>(
              listenWhen: (prev, next) =>
                  prev.error != next.error && next.error != null,
              listener: (ctx, state) {
                _snack(ctx, _reactionsErrorToString(ctx.l10n, state.error!));
                ctx.read<CommentReactionsBloc>().add(
                  const CommentReactionsErrorCleared(),
                );
              },
            ),
          ],
          child: SizedBox(
            child: CommentsList(
              showClassicVineNotice: videoEvent.isVintageRecoveredVine,
              scrollController: sheetScrollController,
              showVideoReplies: showVideoReplies,
            ),
          ),
        );
      },
    );
  }
}

/// Main comment input widget that reads from [CommentComposerBloc] state.
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
    final state = context.read<CommentComposerBloc>().state;
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
    return BlocConsumer<CommentComposerBloc, CommentComposerState>(
      listenWhen: (prev, next) =>
          prev.activeReplyCommentId != next.activeReplyCommentId ||
          prev.activeEditCommentId != next.activeEditCommentId,
      listener: (context, state) {
        // Focus input when reply or edit is activated.
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
          prev.mentionSuggestions != next.mentionSuggestions,
      builder: (context, state) {
        final isReplyMode = state.activeReplyCommentId != null;
        final isEditMode = state.activeEditCommentId != null;
        final inputText = isEditMode
            ? state.editInputText
            : isReplyMode
            ? state.replyInputText
            : state.mainInputText;

        // Sync controller with state.
        if (_controller.text != inputText) {
          _controller.text = inputText;
          _controller.selection = TextSelection.collapsed(
            offset: inputText.length,
          );
        }

        // Get display name of user being replied to.
        String? replyToDisplayName;
        String? replyToAuthorPubkey;
        if (isReplyMode) {
          final listState = context.read<CommentsListBloc>().state;
          final replyComment =
              listState.commentsById[state.activeReplyCommentId!];
          if (replyComment != null) {
            replyToAuthorPubkey = replyComment.authorPubkey;
            final profile = ref
                .watch(userProfileReactiveProvider(replyToAuthorPubkey))
                .value;
            replyToDisplayName =
                profile?.displayName ??
                profile?.name ??
                UserProfile.generatedNameFor(replyToAuthorPubkey);
          }
        }

        return CommentInput(
          controller: _controller,
          focusNode: _focusNode,
          replyToDisplayName: replyToDisplayName,
          isEditing: isEditMode,
          mentionSuggestions: state.mentionSuggestions,
          onMentionQuery: (query) {
            if (query.isEmpty) {
              context.read<CommentComposerBloc>().add(
                const MentionSuggestionsCleared(),
              );
            } else {
              context.read<CommentComposerBloc>().add(
                MentionSearchRequested(query),
              );
            }
          },
          onMentionSelected: (pubkey, displayName, start, end) {
            context.read<CommentComposerBloc>()
              ..add(
                MentionRegistered(
                  displayName: displayName,
                  pubkey: pubkey,
                  start: start,
                  end: end,
                ),
              )
              ..add(const MentionSuggestionsCleared());
          },
          onVideoReplyPressed:
              ref.watch(isFeatureEnabledProvider(FeatureFlag.videoReplies))
              ? () => _openVideoReplyCamera(context, state, replyToAuthorPubkey)
              : null,
          onChanged: (text) {
            context.read<CommentComposerBloc>().add(
              CommentTextChanged(text, commentId: state.activeReplyCommentId),
            );
          },
          onSubmit: () {
            final composer = context.read<CommentComposerBloc>();
            if (isEditMode) {
              composer.add(const CommentEditSubmitted());
            } else if (isReplyMode) {
              // Guard against the parent comment having been removed from the
              // store between reply-mode entry and submit (block-by-author
              // cleanup, kind-5 delete, or list still loading). Submitting
              // with parentAuthorPubkey=null produces a malformed NIP-22
              // reply (E tag without matching P tag). Cancel reply mode
              // instead so the user can re-target a still-visible comment.
              if (replyToAuthorPubkey == null) {
                composer.add(
                  CommentReplyToggled(state.activeReplyCommentId!),
                );
                return;
              }
              composer.add(
                CommentSubmitted(
                  parentCommentId: state.activeReplyCommentId,
                  parentAuthorPubkey: replyToAuthorPubkey,
                ),
              );
            } else {
              composer.add(const CommentSubmitted());
            }
          },
          onCancelReply: () {
            context.read<CommentComposerBloc>().add(
              CommentReplyToggled(state.activeReplyCommentId!),
            );
          },
          onCancelEdit: () {
            context.read<CommentComposerBloc>().add(
              const CommentEditModeCancelled(),
            );
          },
        );
      },
    );
  }

  void _openVideoReplyCamera(
    BuildContext context,
    CommentComposerState state,
    String? replyToAuthorPubkey,
  ) {
    final listState = context.read<CommentsListBloc>().state;
    final replyContextNotifier = ref.read(videoReplyContextProvider.notifier);
    replyContextNotifier.set(
      VideoReplyContext(
        rootEventId: listState.rootEventId,
        rootEventKind: listState.rootEventKind,
        rootAuthorPubkey: listState.rootAuthorPubkey,
        rootAddressableId: listState.rootAddressableId,
        parentCommentId: state.activeReplyCommentId,
        parentAuthorPubkey: replyToAuthorPubkey,
      ),
    );
    unawaited(
      context
          .push(VideoRecorderScreen.path)
          .then((_) => replyContextNotifier.clear()),
    );
  }
}

/// Sort toggle button that cycles: New → Top → Old → New.
class _CommentsSortToggle extends StatelessWidget {
  const _CommentsSortToggle();

  @override
  Widget build(BuildContext context) {
    return BlocSelector<CommentsListBloc, CommentsListState, CommentsSortMode>(
      selector: (state) => state.sortMode,
      builder: (context, sortMode) {
        final l10n = context.l10n;
        final (icon, label) = switch (sortMode) {
          CommentsSortMode.newest => (Icons.schedule, l10n.commentsSortNew),
          CommentsSortMode.topEngagement => (
            Icons.local_fire_department,
            l10n.commentsSortTop,
          ),
          CommentsSortMode.oldest => (Icons.history, l10n.commentsSortOld),
        };

        return Semantics(
          identifier: 'comments_sorting',
          button: true,
          label: l10n.commentsSortSemanticLabel,
          child: GestureDetector(
            onTap: () {
              final nextMode = switch (sortMode) {
                CommentsSortMode.newest => CommentsSortMode.topEngagement,
                CommentsSortMode.topEngagement => CommentsSortMode.oldest,
                CommentsSortMode.oldest => CommentsSortMode.newest,
              };
              context.read<CommentsListBloc>().add(
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
