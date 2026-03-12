// ABOUTME: BLoC for a single DM conversation.
// ABOUTME: Manages loading messages, sending new messages,
// ABOUTME: and real-time message streaming.

import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:models/models.dart';
import 'package:openvine/repositories/dm_repository.dart';

part 'conversation_event.dart';
part 'conversation_state.dart';

class ConversationBloc extends Bloc<ConversationEvent, ConversationState> {
  ConversationBloc({
    required DmRepository dmRepository,
    required String conversationId,
  }) : _dmRepository = dmRepository,
       _conversationId = conversationId,
       super(const ConversationState()) {
    on<ConversationStarted>(
      _onStarted,
      transformer: restartable(),
    );
    on<ConversationMessageSent>(
      _onMessageSent,
      transformer: sequential(),
    );
  }

  final DmRepository _dmRepository;
  final String _conversationId;

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

  Future<void> _onMessageSent(
    ConversationMessageSent event,
    Emitter<ConversationState> emit,
  ) async {
    emit(state.copyWith(sendStatus: SendStatus.sending));

    try {
      if (event.recipientPubkeys.length == 1) {
        final result = await _dmRepository.sendMessage(
          recipientPubkey: event.recipientPubkeys.first,
          content: event.content,
        );
        if (result.success) {
          emit(state.copyWith(sendStatus: SendStatus.sent));
        } else {
          addError(
            Exception(result.error ?? 'Failed to send message'),
            StackTrace.current,
          );
          emit(state.copyWith(sendStatus: SendStatus.failed));
        }
      } else {
        final results = await _dmRepository.sendGroupMessage(
          recipientPubkeys: event.recipientPubkeys,
          content: event.content,
        );
        if (results.any((r) => r.success)) {
          emit(state.copyWith(sendStatus: SendStatus.sent));
        } else {
          addError(
            Exception(results.first.error ?? 'Failed to send group message'),
            StackTrace.current,
          );
          emit(state.copyWith(sendStatus: SendStatus.failed));
        }
      }
    } catch (e, stackTrace) {
      addError(e, stackTrace);
      emit(state.copyWith(sendStatus: SendStatus.failed));
    }
  }
}
