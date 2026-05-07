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
    on<ConversationSelfWrapRecoveryRequested>(
      _onSelfWrapRecoveryRequested,
      transformer: sequential(),
    );
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
        clearLastPartialSend: true,
      ),
    );

    try {
      // Partial-delivery: recipient got the message and DmRepository
      // persisted it locally, but the self-addressed gift wrap did not
      // reach relays. The sender's other devices will not see this
      // message on relay-only restore. Surface as a distinct status so
      // the UI can offer a self-wrap-only retry without re-delivering
      // to the recipient (the optimistic stays — the message *was*
      // sent). [lastPartialSend.rumorIds] carries the per-recipient
      // rumor ids whose self-wrap publish failed, so retrying
      // republishes only those self-wraps via [recoverSelfWrap].
      final partialRumorIds = <String>[];
      if (event.recipientPubkeys.length == 1) {
        final result = await _dmRepository.sendMessage(
          recipientPubkey: event.recipientPubkeys.first,
          content: event.content,
        );
        if (!result.success) {
          throw Exception(result.error ?? 'Failed to send message');
        }
        if (result.selfWrapPublished == false) {
          partialRumorIds.add(result.rumorEventId!);
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
        // For groups, "self-wrap" is per-recipient. We collect the rumor
        // ids of the successful per-recipient sends whose self-wrap
        // failed — only those rumors need a recovery republish.
        for (final result in results) {
          if (result.success && result.selfWrapPublished == false) {
            partialRumorIds.add(result.rumorEventId!);
          }
        }
      }
      if (partialRumorIds.isNotEmpty) {
        emit(
          state.copyWith(
            sendStatus: SendStatus.sentPartial,
            lastPartialSend: PartialSend(rumorIds: partialRumorIds),
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

  Future<void> _onSelfWrapRecoveryRequested(
    ConversationSelfWrapRecoveryRequested event,
    Emitter<ConversationState> emit,
  ) async {
    if (event.rumorIds.isEmpty) return;

    emit(state.copyWith(sendStatus: SendStatus.sending));

    final stillFailing = <String>[];
    Object? lastError;
    StackTrace? lastStackTrace;

    for (final rumorId in event.rumorIds) {
      try {
        final result = await _dmRepository.recoverSelfWrap(rumorId: rumorId);
        if (!result.success) {
          stillFailing.add(rumorId);
        }
      } on Object catch (e, stackTrace) {
        // recoverSelfWrap can throw on missing/foreign queue rows or a
        // missing DAO. Treat each thrown rumor as still-failing so the
        // user can retry — recording the error for telemetry.
        stillFailing.add(rumorId);
        lastError = e;
        lastStackTrace = stackTrace;
      }
    }

    if (lastError != null) {
      addError(lastError, lastStackTrace);
    }

    if (stillFailing.isEmpty) {
      emit(
        state.copyWith(
          sendStatus: SendStatus.sent,
          clearLastPartialSend: true,
        ),
      );
    } else {
      // Reduce lastPartialSend to only the rumors that are still
      // failing, so a second Retry tap targets exactly those — never
      // the ones that already recovered.
      emit(
        state.copyWith(
          sendStatus: SendStatus.sentPartial,
          lastPartialSend: PartialSend(rumorIds: stillFailing),
        ),
      );
    }
  }
}
