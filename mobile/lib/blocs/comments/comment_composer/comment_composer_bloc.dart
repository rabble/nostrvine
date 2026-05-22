// ABOUTME: BLoC owning composer input state, mention search, and the publish
// ABOUTME: + edit flows for one video's comments. Emits ComposerOutbox signals
// ABOUTME: that the UI bridges into CommentsListBloc store mutations.

import 'dart:async';

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:comments_repository/comments_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/blocs/comments/comment_composer/mention_search.dart';
import 'package:openvine/blocs/comments/comment_composer/reportable_sites.dart';
import 'package:openvine/observability/reportable_error.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/mention_resolution_service.dart';
import 'package:profile_repository/profile_repository.dart';
import 'package:unified_logger/unified_logger.dart';

part 'comment_composer_event.dart';
part 'comment_composer_state.dart';

/// BLoC owning composer input state for one video's comments: main / reply /
/// edit text buffers, mention search (`restartable()`), publish + edit flows
/// with optimistic placeholders signalled through [ComposerOutbox], and edit
/// as `delete + repost` preserving the original threading.
class CommentComposerBloc
    extends Bloc<CommentComposerEvent, CommentComposerState> {
  CommentComposerBloc({
    required CommentsRepository commentsRepository,
    required AuthService authService,
    required String rootEventId,
    required int rootEventKind,
    required String rootAuthorPubkey,
    String? rootAddressableId,
    ProfileRepository? profileRepository,
    MentionResolutionService? mentionResolutionService,
    MentionCandidatePubkeysProvider? mentionCandidatePubkeysProvider,
  }) : _commentsRepository = commentsRepository,
       _authService = authService,
       _rootEventId = rootEventId,
       _rootEventKind = rootEventKind,
       _rootAuthorPubkey = rootAuthorPubkey,
       _rootAddressableId = rootAddressableId,
       _profileRepository = profileRepository,
       _mentionResolutionService =
           mentionResolutionService ??
           (profileRepository == null
               ? null
               : MentionResolutionService(
                   profileRepository: profileRepository,
                 )),
       _mentionCandidatePubkeysProvider = mentionCandidatePubkeysProvider,
       super(const CommentComposerState()) {
    on<CommentTextChanged>(_onTextChanged);
    on<CommentReplyToggled>(_onReplyToggled);
    on<CommentSubmitted>(_onSubmitted);
    on<CommentComposerErrorCleared>(_onErrorCleared);
    on<CommentEditModeEntered>(_onEditModeEntered);
    on<CommentEditModeCancelled>(_onEditModeCancelled);
    on<CommentEditSubmitted>(_onEditSubmitted);
    on<MentionSearchRequested>(
      _onMentionSearchRequested,
      transformer: restartable(),
    );
    on<MentionRegistered>(_onMentionRegistered);
    on<MentionSuggestionsCleared>(_onMentionSuggestionsCleared);
    on<ComposerOutboxConsumed>(_onOutboxConsumed);
  }

  final CommentsRepository _commentsRepository;
  final AuthService _authService;
  final ProfileRepository? _profileRepository;
  final MentionResolutionService? _mentionResolutionService;
  final MentionCandidatePubkeysProvider? _mentionCandidatePubkeysProvider;
  final String _rootEventId;
  final int _rootEventKind;
  final String _rootAuthorPubkey;
  final String? _rootAddressableId;

  /// Logs [error] to the unified log and forwards through [addError]. Wraps
  /// with [Reportable] when [error] is **not** a [CommentsRepositoryException]
  /// (i.e. matrix-YES — see `rules/error_handling.md`).
  void _logFailure(
    Object error,
    StackTrace stackTrace,
    String site,
    String operation,
  ) {
    if (error is CommentsRepositoryException) {
      addError(error, stackTrace);
    } else {
      addError(Reportable(error, context: site), stackTrace);
    }
    Log.error(
      '$operation: $error',
      name: 'CommentComposerBloc',
      category: LogCategory.ui,
    );
  }

  void _onTextChanged(
    CommentTextChanged event,
    Emitter<CommentComposerState> emit,
  ) {
    if (state.activeEditCommentId != null) {
      emit(state.copyWith(editInputText: event.text));
    } else if (event.commentId == null) {
      emit(state.copyWith(mainInputText: event.text));
    } else {
      emit(state.copyWith(replyInputText: event.text));
    }
  }

  void _onReplyToggled(
    CommentReplyToggled event,
    Emitter<CommentComposerState> emit,
  ) {
    if (state.activeReplyCommentId == event.commentId) {
      emit(state.clearActiveReply());
    } else {
      emit(
        state.copyWith(
          activeReplyCommentId: event.commentId,
          replyInputText: '',
          activeMentions: const {},
          activeMentionBindings: const [],
        ),
      );
    }
  }

  Future<void> _onSubmitted(
    CommentSubmitted event,
    Emitter<CommentComposerState> emit,
  ) async {
    final isReply = event.parentCommentId != null;
    var text = isReply
        ? state.replyInputText.trim()
        : state.mainInputText.trim();

    if (text.isEmpty) return;

    final myPubkey = _requireAuthenticated(emit);
    if (myPubkey == null) return;

    // Snapshot input fields for rollback if the publish fails.
    final previousMain = state.mainInputText;
    final previousReply = state.replyInputText;
    final previousMentions = state.activeMentions;
    final previousMentionBindings = state.activeMentionBindings;

    final resolvedMentions = await _resolveMentionsForText(
      text,
      currentUserPubkey: myPubkey,
    );
    text = resolvedMentions.canonicalText;

    // 1. Optimistic placeholder — the listener bridges this to ListBloc which
    // inserts it into commentsById before the publish returns. Reconciled on
    // success (confirm), failure (rollback), or relay-echo (NewCommentReceived
    // matches placeholder by author+content and swaps in-place).
    final placeholderId =
        'pending_comment_${DateTime.now().microsecondsSinceEpoch}';
    final placeholder = Comment(
      id: placeholderId,
      content: text,
      authorPubkey: myPubkey,
      createdAt: DateTime.now(),
      rootEventId: _rootEventId,
      rootAuthorPubkey: _rootAuthorPubkey,
      replyToEventId: event.parentCommentId,
      replyToAuthorPubkey: event.parentAuthorPubkey,
    );
    final clearedState = isReply
        ? state.clearActiveReply()
        : state.copyWith(
            mainInputText: '',
            activeMentions: const {},
            activeMentionBindings: const [],
          );
    emit(
      clearedState.copyWith(
        outbox: ComposerOutboxInsertPlaceholder(placeholder),
      ),
    );

    // 2. Publish in background; emit confirm on success, rollback on failure.
    try {
      final postedComment = await _commentsRepository.postComment(
        content: text,
        rootEventId: _rootEventId,
        rootEventKind: _rootEventKind,
        rootEventAuthorPubkey: _rootAuthorPubkey,
        rootAddressableId: _rootAddressableId,
        replyToEventId: event.parentCommentId,
        replyToAuthorPubkey: event.parentAuthorPubkey,
        mentionedPubkeys: resolvedMentions.resolvedPubkeys,
      );
      emit(
        state.copyWith(
          outbox: ComposerOutboxConfirmPlaceholder(
            placeholderId: placeholderId,
            confirmed: postedComment,
          ),
        ),
      );
    } catch (e, stackTrace) {
      // CommentsRepositoryException is matrix-NO; anything else is wrapped
      // with Reportable inside _logFailure.
      _logFailure(
        e,
        stackTrace,
        CommentComposerBlocReportableSites.onSubmitted,
        'Error posting comment',
      );
      _emitSubmitRollback(
        emit,
        placeholderId: placeholderId,
        isReply: isReply,
        previousMain: previousMain,
        previousReply: previousReply,
        previousMentions: previousMentions,
        previousMentionBindings: previousMentionBindings,
      );
    }
  }

  void _emitSubmitRollback(
    Emitter<CommentComposerState> emit, {
    required String placeholderId,
    required bool isReply,
    required String previousMain,
    required String previousReply,
    required Map<String, String> previousMentions,
    required List<MentionBinding> previousMentionBindings,
  }) {
    emit(
      state.copyWith(
        mainInputText: isReply ? state.mainInputText : previousMain,
        replyInputText: isReply ? previousReply : state.replyInputText,
        activeMentions: previousMentions,
        activeMentionBindings: previousMentionBindings,
        error: isReply
            ? ComposerError.postReplyFailed
            : ComposerError.postCommentFailed,
        outbox: ComposerOutboxRollbackPlaceholder(placeholderId),
      ),
    );
  }

  String? _requireAuthenticated(Emitter<CommentComposerState> emit) {
    if (!_authService.isAuthenticated) {
      emit(state.copyWith(error: ComposerError.notAuthenticated));
      return null;
    }
    final myPubkey = _authService.currentPublicKeyHex;
    if (myPubkey == null) {
      emit(state.copyWith(error: ComposerError.notAuthenticated));
      return null;
    }
    return myPubkey;
  }

  Future<({String canonicalText, List<String> resolvedPubkeys})>
  _resolveMentionsForText(
    String text, {
    required String currentUserPubkey,
  }) async {
    final service = _mentionResolutionService;
    if (service == null) {
      return (canonicalText: text, resolvedPubkeys: const <String>[]);
    }

    final selectedMentions = state.activeMentionBindings.isNotEmpty
        ? state.activeMentionBindings
        : state.activeMentions.entries
              .map((e) => MentionBinding(display: e.key, pubkey: e.value))
              .toList();

    try {
      final result = await service.resolveTextMentions(
        rawText: text,
        selectedMentions: selectedMentions,
        currentUserPubkey: currentUserPubkey,
      );
      return (
        canonicalText: result.canonicalText,
        resolvedPubkeys: result.resolvedPubkeys,
      );
    } catch (e, stackTrace) {
      // MentionResolutionService already degrades typed/profile IO failures
      // internally. Anything escaping here is unexpected, but posting should
      // still continue with the raw text.
      _logFailure(
        e,
        stackTrace,
        CommentComposerBlocReportableSites.resolveCommentMentions,
        'Mention resolution failed',
      );
      return (canonicalText: text, resolvedPubkeys: const <String>[]);
    }
  }

  void _onErrorCleared(
    CommentComposerErrorCleared event,
    Emitter<CommentComposerState> emit,
  ) {
    emit(state.copyWith(clearError: true));
  }

  void _onEditModeEntered(
    CommentEditModeEntered event,
    Emitter<CommentComposerState> emit,
  ) {
    // Clear any active reply, then enter edit mode preserving the original
    // threading so the eventual repost retains the same reply target.
    emit(
      state.clearActiveReply().copyWith(
        activeEditCommentId: event.commentId,
        editInputText: event.originalContent,
        activeEditOriginalReplyToEventId: event.originalReplyToEventId,
        activeEditOriginalReplyToAuthorPubkey:
            event.originalReplyToAuthorPubkey,
      ),
    );
  }

  void _onEditModeCancelled(
    CommentEditModeCancelled event,
    Emitter<CommentComposerState> emit,
  ) {
    emit(state.clearEditMode());
  }

  Future<void> _onEditSubmitted(
    CommentEditSubmitted event,
    Emitter<CommentComposerState> emit,
  ) async {
    final editedText = state.editInputText.trim();
    if (editedText.isEmpty) return;

    final myPubkey = _requireAuthenticated(emit);
    if (myPubkey == null) return;

    final originalCommentId = state.activeEditCommentId;
    if (originalCommentId == null) return;

    final replyToEventId = state.activeEditOriginalReplyToEventId;
    final replyToAuthorPubkey = state.activeEditOriginalReplyToAuthorPubkey;

    try {
      final resolvedMentions = await _resolveMentionsForText(
        editedText,
        currentUserPubkey: myPubkey,
      );

      // Delete-then-repost. CommentRepository's #4478 cache fix uses
      // rootAddressableId on both legs to keep the addressable-event count
      // cache in sync.
      await _commentsRepository.deleteComment(
        commentId: originalCommentId,
        rootEventId: _rootEventId,
        rootAddressableId: _rootAddressableId,
      );

      final postedComment = await _commentsRepository.postComment(
        content: resolvedMentions.canonicalText,
        rootEventId: _rootEventId,
        rootEventKind: _rootEventKind,
        rootEventAuthorPubkey: _rootAuthorPubkey,
        rootAddressableId: _rootAddressableId,
        replyToEventId: replyToEventId,
        replyToAuthorPubkey: replyToAuthorPubkey,
        mentionedPubkeys: resolvedMentions.resolvedPubkeys,
      );

      emit(
        state.clearEditMode().copyWith(
          outbox: ComposerOutboxReplaceComment(
            oldId: originalCommentId,
            newComment: postedComment,
          ),
        ),
      );
    } catch (e, stackTrace) {
      // Delete-then-repost flow IO is matrix-NO for the repo exception;
      // anything else is wrapped with Reportable inside _logFailure.
      _logFailure(
        e,
        stackTrace,
        CommentComposerBlocReportableSites.onEditSubmitted,
        'Error editing comment',
      );
      emit(state.copyWith(error: ComposerError.editFailed));
    }
  }

  Future<void> _onMentionSearchRequested(
    MentionSearchRequested event,
    Emitter<CommentComposerState> emit,
  ) async {
    final query = event.query.toLowerCase();
    if (query.isEmpty) {
      emit(state.copyWith(mentionQuery: '', mentionSuggestions: const []));
      return;
    }

    // Tier 1: instant local search.
    final candidates = <String>[];
    if (_rootAuthorPubkey.isNotEmpty) candidates.add(_rootAuthorPubkey);
    if (_mentionCandidatePubkeysProvider != null) {
      candidates.addAll(_mentionCandidatePubkeysProvider());
    }

    final tier1 = await mentionSearchLocal(
      lowercaseQuery: query,
      candidates: candidates,
      profileRepository: _profileRepository,
    );

    emit(
      state.copyWith(
        mentionQuery: query,
        mentionSuggestions: tier1.matches.map(_toSuggestion).toList(),
      ),
    );

    // Tier 2: REST backfill if local results are sparse.
    if (tier1.matches.length < 5 && _profileRepository != null) {
      try {
        final merged = await mentionSearchRemote(
          lowercaseQuery: query,
          profileRepository: _profileRepository,
          previousMatches: tier1.matches,
          previouslySeen: tier1.seen,
        );
        emit(
          state.copyWith(
            mentionQuery: query,
            mentionSuggestions: merged.map(_toSuggestion).toList(),
          ),
        );
      } catch (e, stackTrace) {
        // searchUsersFromApi already returns [] on typed REST failures.
        // Anything escaping here is unexpected; tier-1 results remain visible.
        _logFailure(
          e,
          stackTrace,
          CommentComposerBlocReportableSites.onMentionSearchRequested,
          'Mention search failed',
        );
      }
    }
  }

  MentionSuggestion _toSuggestion(MentionMatch m) => MentionSuggestion(
    pubkey: m.pubkey,
    displayName: m.displayName,
    picture: m.picture,
    nip05: m.nip05,
  );

  void _onMentionRegistered(
    MentionRegistered event,
    Emitter<CommentComposerState> emit,
  ) {
    emit(
      state.copyWith(
        activeMentions: Map<String, String>.from(state.activeMentions)
          ..[event.displayName] = event.pubkey,
        activeMentionBindings: [
          ...state.activeMentionBindings,
          MentionBinding(
            display: event.displayName,
            pubkey: event.pubkey,
            start: event.start,
            end: event.end,
          ),
        ],
      ),
    );
  }

  void _onMentionSuggestionsCleared(
    MentionSuggestionsCleared event,
    Emitter<CommentComposerState> emit,
  ) {
    emit(state.copyWith(mentionQuery: '', mentionSuggestions: const []));
  }

  void _onOutboxConsumed(
    ComposerOutboxConsumed event,
    Emitter<CommentComposerState> emit,
  ) {
    if (state.outbox == null) return;
    emit(state.copyWith(clearOutbox: true));
  }
}
