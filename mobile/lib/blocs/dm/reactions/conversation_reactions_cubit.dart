// ABOUTME: Cubit for DM reactions in one conversation.
// ABOUTME: Wraps the optimistic publish flow + Drift subscription.
// ABOUTME: Per the error-handling matrix, publish failures call
// ABOUTME: addError without Reportable wrapping (network/IO class).

import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:collection/collection.dart';
import 'package:dm_repository/dm_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:meta/meta.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/dm/reactions/reportable_sites.dart';

part 'conversation_reactions_event.dart';
part 'conversation_reactions_state.dart';

/// Bloc for emoji reactions on DM messages within one conversation.
///
/// Named "cubit" by convention with other DM blocs, but extends [Bloc]
/// so the optimistic publish flow can use `sequential()` to serialize
/// rapid-tap toggle events without dropping any.
class ConversationReactionsCubit
    extends Bloc<ConversationReactionsEvent, ConversationReactionsState> {
  /// Construct a cubit. [ownerPubkey] is the account viewing this
  /// conversation; it's used to detect own reactions for the toggle-off
  /// path and for the `pending` map's local-status semantics.
  ConversationReactionsCubit({
    required DmReactionsRepository reactionsRepository,
    required String ownerPubkey,
  }) : _reactionsRepository = reactionsRepository,
       _ownerPubkey = ownerPubkey,
       super(const ConversationReactionsState()) {
    on<ConversationReactionsStarted>(_onStarted, transformer: restartable());
    on<ConversationReactionToggled>(_onToggled, transformer: sequential());
    on<ConversationReactionSet>(_onSet, transformer: sequential());
    on<ConversationReactionRetryRequested>(
      _onRetryRequested,
      transformer: sequential(),
    );
    on<_ConversationReactionsSubscriptionTicked>(_onSubscriptionTicked);
  }

  final DmReactionsRepository _reactionsRepository;
  final String _ownerPubkey;
  StreamSubscription<List<DmReaction>>? _subscription;
  String? _conversationId;

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }

  Future<void> _onStarted(
    ConversationReactionsStarted event,
    Emitter<ConversationReactionsState> emit,
  ) async {
    if (_conversationId == event.conversationId &&
        state.status == ConversationReactionsStatus.loaded) {
      return;
    }
    _conversationId = event.conversationId;
    emit(state.copyWith(status: ConversationReactionsStatus.loading));
    await _subscription?.cancel();
    _subscription = _reactionsRepository
        .watchForConversation(event.conversationId)
        .listen(
          (reactions) =>
              add(_ConversationReactionsSubscriptionTicked(reactions)),
        );
  }

  Future<void> _onToggled(
    ConversationReactionToggled event,
    Emitter<ConversationReactionsState> emit,
  ) async {
    // Toggle-off: if we already have a live matching reaction, remove it.
    final existing = _ownLiveReaction(event.messageId, event.emoji);
    if (existing != null) {
      try {
        await _reactionsRepository.removeOwn(
          rumorId: existing.id,
          targetMessageAuthor: event.messageAuthorPubkey,
        );
      } on Object catch (e, st) {
        addError(e, st);
      }
      return;
    }

    await _publishReaction(
      conversationId: event.conversationId,
      messageId: event.messageId,
      messageAuthorPubkey: event.messageAuthorPubkey,
      emoji: event.emoji,
      emit: emit,
    );
  }

  Future<void> _onSet(
    ConversationReactionSet event,
    Emitter<ConversationReactionsState> emit,
  ) async {
    // Set-not-toggle: re-selecting the active emoji is a no-op (keep it);
    // a different emoji supersedes the prior one in the repository.
    if (_ownLiveReaction(event.messageId, event.emoji) != null) return;

    await _publishReaction(
      conversationId: event.conversationId,
      messageId: event.messageId,
      messageAuthorPubkey: event.messageAuthorPubkey,
      emoji: event.emoji,
      emit: emit,
    );
  }

  /// The current account's live reaction with [emoji] on [messageId], or null.
  DmReaction? _ownLiveReaction(String messageId, String emoji) {
    final list = state.reactionsByMessageId[messageId];
    return list?.firstWhereOrNull(
      (r) => r.reactorPubkey == _ownerPubkey && r.emoji == emoji,
    );
  }

  /// Optimistically mark the publish pending, send, then settle the pending
  /// map by outcome. Shared by the toggle and set paths.
  Future<void> _publishReaction({
    required String conversationId,
    required String messageId,
    required String messageAuthorPubkey,
    required String emoji,
    required Emitter<ConversationReactionsState> emit,
  }) async {
    final key = ReactionPublishKey(messageId: messageId, emoji: emoji);
    final nextPending =
        Map<ReactionPublishKey, ReactionPublishLocalStatus>.from(state.pending)
          ..[key] = ReactionPublishLocalStatus.sending;
    emit(state.copyWith(pending: nextPending));

    try {
      final result = await _reactionsRepository.publish(
        conversationId: conversationId,
        targetMessageId: messageId,
        targetMessageAuthor: messageAuthorPubkey,
        emoji: emoji,
      );
      final newPending =
          Map<ReactionPublishKey, ReactionPublishLocalStatus>.from(
            state.pending,
          );
      if (result.success) {
        newPending[key] = ReactionPublishLocalStatus.succeeded;
        // Best-effort cleanup: drop the key on the next tick. The DAO
        // stream re-emits with the persisted `sent` row so the chip's
        // truth source becomes the row itself.
        newPending.remove(key);
      } else {
        newPending[key] = ReactionPublishLocalStatus.failed;
      }
      emit(state.copyWith(pending: newPending));
    } on Object catch (e, st) {
      // Network/IO class per error-handling matrix — addError without
      // Reportable wrap. Site identifier carried for log triage.
      addError(
        _ReactionPublishException(
          e,
          site: ConversationReactionsReportableSites.publishThrew,
        ),
        st,
      );
      final newPending =
          Map<ReactionPublishKey, ReactionPublishLocalStatus>.from(
            state.pending,
          )..[key] = ReactionPublishLocalStatus.failed;
      emit(state.copyWith(pending: newPending));
    }
  }

  Future<void> _onRetryRequested(
    ConversationReactionRetryRequested event,
    Emitter<ConversationReactionsState> emit,
  ) async {
    final key = ReactionPublishKey(
      messageId: event.messageId,
      emoji: event.emoji,
    );
    final nextPending =
        Map<ReactionPublishKey, ReactionPublishLocalStatus>.from(state.pending)
          ..[key] = ReactionPublishLocalStatus.sending;
    emit(state.copyWith(pending: nextPending));

    try {
      final result = await _reactionsRepository.retry(
        rumorId: event.rumorId,
        targetMessageAuthor: event.messageAuthorPubkey,
      );
      final newPending =
          Map<ReactionPublishKey, ReactionPublishLocalStatus>.from(
            state.pending,
          );
      if (result.success) {
        newPending.remove(key);
      } else {
        newPending[key] = ReactionPublishLocalStatus.failed;
      }
      emit(state.copyWith(pending: newPending));
    } on Object catch (e, st) {
      addError(
        _ReactionPublishException(
          e,
          site: ConversationReactionsReportableSites.retryThrew,
        ),
        st,
      );
      final newPending =
          Map<ReactionPublishKey, ReactionPublishLocalStatus>.from(
            state.pending,
          )..[key] = ReactionPublishLocalStatus.failed;
      emit(state.copyWith(pending: newPending));
    }
  }

  void _onSubscriptionTicked(
    _ConversationReactionsSubscriptionTicked event,
    Emitter<ConversationReactionsState> emit,
  ) {
    final grouped = <String, List<DmReaction>>{};
    for (final reaction in event.reactions) {
      grouped
          .putIfAbsent(reaction.targetMessageId, () => <DmReaction>[])
          .add(reaction);
    }
    emit(
      state.copyWith(
        status: ConversationReactionsStatus.loaded,
        reactionsByMessageId: grouped,
      ),
    );
  }
}

/// Wraps the inner publish exception with a triage site identifier.
/// Not a [ReportableError] — Crashlytics does NOT receive these.
@immutable
class _ReactionPublishException implements Exception {
  const _ReactionPublishException(this.inner, {required this.site});

  final Object inner;
  final String site;

  @override
  String toString() => 'ReactionPublishException($site): $inner';
}
