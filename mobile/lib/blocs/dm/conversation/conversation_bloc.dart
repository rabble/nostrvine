// ABOUTME: BLoC for a single DM conversation.
// ABOUTME: Manages loading messages, sending new messages,
// ABOUTME: and real-time message streaming.

import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:dm_repository/dm_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:models/models.dart';

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
        return state.copyWith(
          status: ConversationStatus.loaded,
          messages: messages,
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
    final pendingId = 'pending-$now';
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
      ),
    );

    try {
      if (event.recipientPubkeys.length == 1) {
        final result = await _dmRepository.sendMessage(
          recipientPubkey: event.recipientPubkeys.first,
          content: event.content,
        );
        if (!result.success) {
          throw Exception(result.error ?? 'Failed to send message');
        }
      } else {
        final results = await _dmRepository.sendGroupMessage(
          recipientPubkeys: event.recipientPubkeys,
          content: event.content,
        );
        if (!results.any((r) => r.success)) {
          throw Exception(
            results.first.error ?? 'Failed to send group message',
          );
        }
      }
      emit(state.copyWith(sendStatus: SendStatus.sent));
    } catch (e, stackTrace) {
      addError(e, stackTrace);
      emit(state.copyWith(sendStatus: SendStatus.failed));
    }
  }
}
