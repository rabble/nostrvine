// ABOUTME: BLoC for a single DM conversation.
// ABOUTME: Manages loading messages, sending new messages,
// ABOUTME: real-time message streaming, optimistic insertion, and
// ABOUTME: per-message pending/failed status with Retry.

import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:dm_repository/dm_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';

part 'conversation_event.dart';
part 'conversation_state.dart';

class ConversationBloc extends Bloc<ConversationEvent, ConversationState> {
  ConversationBloc({
    required DmRepository dmRepository,
    required String conversationId,
    required String currentUserPubkey,
  }) : _dmRepository = dmRepository,
       _conversationId = conversationId,
       _currentUserPubkey = currentUserPubkey,
       super(const ConversationState()) {
    on<ConversationStarted>(
      _onStarted,
      transformer: restartable(),
    );
    on<ConversationMessageSent>(
      _onMessageSent,
      transformer: sequential(),
    );
    on<ConversationMessageRetried>(
      _onMessageRetried,
      transformer: sequential(),
    );
    on<ConversationMessageDeleted>(
      _onMessageDeleted,
      transformer: droppable(),
    );
  }

  final DmRepository _dmRepository;
  final String _conversationId;
  final String _currentUserPubkey;

  Future<void> _onStarted(
    ConversationStarted event,
    Emitter<ConversationState> emit,
  ) async {
    emit(state.copyWith(status: ConversationStatus.loading));

    // Mark as read when opening
    await _dmRepository.markConversationAsRead(_conversationId);

    await emit.forEach(
      _dmRepository.watchMessages(_conversationId),
      onData: (messages) {
        // Mark as read whenever new messages arrive while the user is
        // viewing this conversation. This ensures incoming messages are
        // immediately marked as read rather than only on initial open.
        unawaited(_dmRepository.markConversationAsRead(_conversationId));
        // Merge optimistic sends with confirmed messages. Confirmed
        // messages come back by their rumor event id, which we stored
        // as the message id when the optimistic row was created, so
        // duplicates are avoided via the same-id check below.
        final merged = _mergeOptimisticWithConfirmed(messages);
        return state.copyWith(
          status: ConversationStatus.loaded,
          messages: merged,
        );
      },
      onError: (error, stackTrace) {
        addError(error, stackTrace);
        return state.copyWith(
          status: ConversationStatus.error,
        );
      },
    );
  }

  /// Preserves optimistic messages (those with an entry in
  /// [ConversationState.sendStatusByMessageId]) that have not yet been
  /// reflected in the confirmed list. Once the repository persists the
  /// real message and the stream emits it with the same id, the
  /// optimistic row is replaced by the confirmed one and its status is
  /// dropped.
  List<DmMessage> _mergeOptimisticWithConfirmed(
    List<DmMessage> confirmed,
  ) {
    final confirmedIds = confirmed.map((m) => m.id).toSet();
    final pending = state.messages.where(
      (m) =>
          state.sendStatusByMessageId.containsKey(m.id) &&
          !confirmedIds.contains(m.id),
    );
    final combined = [...pending, ...confirmed];
    // Keep chronological order (newest-first in UI). Ties broken by id
    // so the order is stable across rebuilds.
    combined.sort((a, b) {
      final byTime = b.createdAt.compareTo(a.createdAt);
      return byTime != 0 ? byTime : b.id.compareTo(a.id);
    });
    return combined;
  }

  Future<void> _onMessageDeleted(
    ConversationMessageDeleted event,
    Emitter<ConversationState> emit,
  ) async {
    try {
      await _dmRepository.deleteMessageForEveryone(event.rumorId);
      // The watchMessages stream automatically excludes deleted messages,
      // so the UI updates reactively — no manual state mutation needed.
    } catch (e, stackTrace) {
      addError(e, stackTrace);
    }
  }

  Future<void> _onMessageSent(
    ConversationMessageSent event,
    Emitter<ConversationState> emit,
  ) async {
    // Optimistic insert: show the message instantly before the network
    // round-trip. The stream from watchMessages will replace this with the
    // persisted version once sendMessage completes and writes to the DB.
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final pendingId = 'pending-$now-${event.content.hashCode}';
    final optimisticMessage = DmMessage(
      id: pendingId,
      conversationId: _conversationId,
      senderPubkey: _currentUserPubkey,
      content: event.content,
      createdAt: now,
      giftWrapId: pendingId,
    );

    emit(
      state.copyWith(
        sendStatus: SendStatus.sending,
        messages: [optimisticMessage, ...state.messages],
        sendStatusByMessageId: {
          ...state.sendStatusByMessageId,
          pendingId: MessageSendStatus.sending,
        },
      ),
    );

    await _sendAndUpdateStatus(
      pendingId: pendingId,
      recipientPubkeys: event.recipientPubkeys,
      content: event.content,
      emit: emit,
    );
  }

  Future<void> _onMessageRetried(
    ConversationMessageRetried event,
    Emitter<ConversationState> emit,
  ) async {
    // Re-mark the existing optimistic message as sending and clear any
    // prior failure feedback so the bubble flips from red alert back
    // to pending clock while the retry is in flight.
    final updatedStatus = {...state.sendStatusByMessageId};
    updatedStatus[event.pendingId] = MessageSendStatus.sending;
    final updatedFeedback = {...state.feedbackByMessageId}
      ..remove(event.pendingId);

    emit(
      state.copyWith(
        sendStatus: SendStatus.sending,
        sendStatusByMessageId: updatedStatus,
        feedbackByMessageId: updatedFeedback,
      ),
    );

    await _sendAndUpdateStatus(
      pendingId: event.pendingId,
      recipientPubkeys: event.recipientPubkeys,
      content: event.content,
      emit: emit,
    );
  }

  Future<void> _sendAndUpdateStatus({
    required String pendingId,
    required List<String> recipientPubkeys,
    required String content,
    required Emitter<ConversationState> emit,
  }) async {
    try {
      final NIP17SendResult result;
      if (recipientPubkeys.length == 1) {
        result = await _dmRepository.sendMessage(
          recipientPubkey: recipientPubkeys.first,
          content: content,
        );
        if (!result.success) {
          _markFailed(pendingId, result.outcome, emit);
          addError(
            Exception(result.error ?? 'Failed to send message'),
            StackTrace.current,
          );
          return;
        }
      } else {
        final results = await _dmRepository.sendGroupMessage(
          recipientPubkeys: recipientPubkeys,
          content: content,
        );
        final failures = results.where((r) => !r.success).toList();
        if (failures.isNotEmpty) {
          final firstFailure = failures.first;
          _markFailed(pendingId, firstFailure.outcome, emit);
          addError(
            Exception(
              firstFailure.error ?? 'Failed to send group message',
            ),
            StackTrace.current,
          );
          return;
        }
        result = results.first;
      }

      // Success — clear the optimistic row's status so the bubble
      // stops rendering the clock icon. The watchMessages stream will
      // replace the pending row with the persisted rumor id on its
      // next tick.
      final updatedStatus = {...state.sendStatusByMessageId}..remove(pendingId);
      final updatedFeedback = {...state.feedbackByMessageId}..remove(pendingId);
      emit(
        state.copyWith(
          sendStatus: SendStatus.sent,
          sendStatusByMessageId: updatedStatus,
          feedbackByMessageId: updatedFeedback,
        ),
      );
    } catch (e, stackTrace) {
      addError(e, stackTrace);
      _markFailed(pendingId, null, emit);
    }
  }

  void _markFailed(
    String pendingId,
    PublishOutcome? outcome,
    Emitter<ConversationState> emit,
  ) {
    final feedback = outcome != null
        ? PublishResultMapper.map(outcome)
        : const PublishUserFeedback(
            severity: PublishSeverity.error,
            messageKey: 'publish_no_relays_available',
            retryable: true,
          );
    emit(
      state.copyWith(
        sendStatus: SendStatus.failed,
        sendStatusByMessageId: {
          ...state.sendStatusByMessageId,
          pendingId: MessageSendStatus.failed,
        },
        feedbackByMessageId: {
          ...state.feedbackByMessageId,
          pendingId: feedback,
        },
      ),
    );
  }
}
