// ABOUTME: BLoC for a single DM conversation.
// ABOUTME: Manages loading messages, sending new messages,
// ABOUTME: and real-time message streaming.

import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:dm_repository/dm_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:meta/meta.dart';
import 'package:models/models.dart';
import 'package:uuid/uuid.dart';

part 'conversation_event.dart';
part 'conversation_state.dart';

class ConversationBloc extends Bloc<ConversationEvent, ConversationState> {
  ConversationBloc({
    required DmRepository dmRepository,
    required String conversationId,
    required String currentUserPubkey,
    @visibleForTesting String Function()? pendingIdFactory,
  }) : _dmRepository = dmRepository,
       _conversationId = conversationId,
       _currentUserPubkey = currentUserPubkey,
       _pendingIdFactory = pendingIdFactory ?? _defaultPendingIdFactory,
       super(const ConversationState()) {
    on<ConversationStarted>(_onStarted, transformer: restartable());
    on<ConversationMessageSent>(_onMessageSent, transformer: sequential());
    on<ConversationMessageDeleted>(_onMessageDeleted, transformer: droppable());
  }

  final DmRepository _dmRepository;
  final String _conversationId;
  final String _currentUserPubkey;
  final String Function() _pendingIdFactory;

  static const _uuid = Uuid();
  static String _defaultPendingIdFactory() => 'pending-${_uuid.v4()}';

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
        return state.copyWith(status: ConversationStatus.error);
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
    // round-trip. On success, the stream from watchMessages replaces this
    // with the persisted version. On failure we strip the optimistic row
    // ourselves — the watch stream cannot do it because no DB write
    // happened, and a phantom optimistic that lingers until the bloc is
    // disposed reproduces as "looks sent, then disappeared" once the user
    // navigates away and back.
    //
    // [pendingId] must be unique per attempt. The failure cleanup strips by
    // `m.id != pendingId`, so any two coincident pending rows that share an
    // id would both be removed when one fails. Second-resolution timestamps
    // collide on rapid sends; a UUID does not.
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final pendingId = _pendingIdFactory();
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
        clearLastFailedSend: true,
      ),
    );

    try {
      // Partial-delivery: recipient got the message and DmRepository
      // persisted it locally, but the self-addressed gift wrap did not
      // reach relays. The sender's other devices will not see this
      // message on relay-only restore. Surface as a distinct status so
      // the UI can offer a retry-sync path without claiming the send
      // failed (the optimistic stays — the message *was* sent).
      //
      // Retrying redispatches the full send via [lastFailedSend], which
      // double-delivers to the recipient on success. That tradeoff is
      // accepted here: silent loss of cross-device sync is worse than a
      // duplicate bubble. The principled fix — a durable outgoing queue
      // that retries the self-wrap only — is tracked in #3909.
      var selfWrapPublished = true;
      if (event.recipientPubkeys.length == 1) {
        final result = await _dmRepository.sendMessage(
          recipientPubkey: event.recipientPubkeys.first,
          content: event.content,
        );
        if (!result.success) {
          throw Exception(result.error ?? 'Failed to send message');
        }
        selfWrapPublished = result.selfWrapPublished;
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
        // For groups, "self-wrap" is per-recipient. We treat the send as
        // partial if any successful per-recipient send had its self-wrap
        // fail, because that recipient's copy will not sync to the
        // sender's other devices.
        selfWrapPublished = results
            .where((r) => r.success)
            .every((r) => r.selfWrapPublished);
      }
      if (!selfWrapPublished) {
        emit(
          state.copyWith(
            sendStatus: SendStatus.sentPartial,
            lastFailedSend: FailedSend(
              content: event.content,
              recipientPubkeys: event.recipientPubkeys,
            ),
          ),
        );
        return;
      }
      emit(state.copyWith(sendStatus: SendStatus.sent));
    } catch (e, stackTrace) {
      addError(e, stackTrace);
      emit(
        state.copyWith(
          sendStatus: SendStatus.failed,
          messages: state.messages
              .where((m) => m.id != pendingId)
              .toList(growable: false),
          lastFailedSend: FailedSend(
            content: event.content,
            recipientPubkeys: event.recipientPubkeys,
          ),
        ),
      );
    }
  }
}
