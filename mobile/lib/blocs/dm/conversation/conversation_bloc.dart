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
    // Optimistic insert lives in [state.pendingOptimistic], not
    // [state.messages]. Keeping the two slices disjoint is what fixes
    // #4193: the watchMessages stream's `onData` replaces `state.messages`
    // verbatim on every tick, and on a freshly-searched conversation the
    // first tick is `[]` — which previously wiped the optimistic before
    // `sendMessage`'s persistence transaction had a chance to commit.
    // The UI reads [state.displayedMessages], which merges the two on the
    // way to the bubble list.
    //
    // On success / sentPartial: strip the pending key — the watch tick
    // that brings the persisted row will land moments later, and
    // displayedMessages already prefers the persisted version when the
    // ids collide.
    //
    // On failure: strip the pending key — no DB write happened, so the
    // watch stream cannot do it for us.
    //
    // [pendingId] must be unique per attempt. Strip-by-key fails closed:
    // two coincident pending rows that shared an id would interfere with
    // each other, so a UUID is mandatory (second-resolution timestamps
    // collide on rapid sends).
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
        pendingOptimistic: {
          ...state.pendingOptimistic,
          pendingId: optimisticMessage,
        },
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
      // to the recipient (the message *was* sent — the persisted row
      // shows up via the watch stream). [lastPartialSend.rumorIds]
      // carries the per-recipient rumor ids whose self-wrap publish
      // failed, so retrying republishes only those self-wraps via
      // [recoverSelfWrap].
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
      final stripped = Map.of(state.pendingOptimistic)..remove(pendingId);
      if (partialRumorIds.isNotEmpty) {
        emit(
          state.copyWith(
            sendStatus: SendStatus.sentPartial,
            lastPartialSend: PartialSend(rumorIds: partialRumorIds),
            pendingOptimistic: stripped,
          ),
        );
        return;
      }
      emit(
        state.copyWith(
          sendStatus: SendStatus.sent,
          pendingOptimistic: stripped,
        ),
      );
    } catch (e, stackTrace) {
      addError(e, stackTrace);
      emit(
        state.copyWith(
          sendStatus: SendStatus.failed,
          pendingOptimistic: Map.of(state.pendingOptimistic)..remove(pendingId),
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
