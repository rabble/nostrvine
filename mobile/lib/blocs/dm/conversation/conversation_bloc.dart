// ABOUTME: BLoC for a single DM conversation.
// ABOUTME: Manages loading messages, sending new messages,
// ABOUTME: and real-time message streaming.

import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:db_client/db_client.dart';
import 'package:dm_repository/dm_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:models/models.dart';
import 'package:openvine/observability/reportable_error.dart';
import 'package:rxdart/rxdart.dart';

part 'conversation_event.dart';
part 'conversation_state.dart';

/// Tuple emitted by the dual-stream subscription in [_onStarted]. Carries
/// both reactive slices through a single [emit.forEach] so the
/// `restartable()` transformer keeps lifecycle handling identical to the
/// previous single-stream shape.
class _ConversationTick extends Equatable {
  const _ConversationTick(this.messages, this.pendingOutgoing);

  final List<DmMessage> messages;
  final List<OutgoingDm> pendingOutgoing;

  @override
  List<Object?> get props => [messages, pendingOutgoing];
}

class ConversationBloc extends Bloc<ConversationEvent, ConversationState> {
  ConversationBloc({
    required DmRepository dmRepository,
    required String conversationId,
  }) : _dmRepository = dmRepository,
       _conversationId = conversationId,
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

  Future<void> _onStarted(
    ConversationStarted event,
    Emitter<ConversationState> emit,
  ) async {
    emit(state.copyWith(status: ConversationStatus.loading));

    // Mark as read when opening
    await _dmRepository.markConversationAsRead(_conversationId);

    // Dual-stream projection (#3909). `watchMessages` carries persisted
    // truth; `watchOutgoing` carries the durable in-flight queue. The
    // repository's `sendMessage` enqueues a queue row before any signer
    // round-trip, so the in-flight bubble survives both the watch-stream
    // race that #4193 patched AND an app kill mid-send (the latter is
    // the epic #3912 acceptance criterion the previous in-memory slice
    // could not meet).
    final ticks =
        Rx.combineLatest2<List<DmMessage>, List<OutgoingDm>, _ConversationTick>(
          _dmRepository.watchMessages(_conversationId),
          _dmRepository.watchOutgoing(_conversationId),
          _ConversationTick.new,
        );

    await emit.forEach(
      ticks,
      onData: (tick) {
        // Mark as read whenever new messages arrive while the user is
        // viewing this conversation. This ensures incoming messages are
        // immediately marked as read rather than only on initial open.
        unawaited(_dmRepository.markConversationAsRead(_conversationId));
        return state.copyWith(
          status: ConversationStatus.loaded,
          messages: tick.messages,
          pendingOutgoing: tick.pendingOutgoing,
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
    // The in-flight bubble lives in `state.pendingOutgoing`, sourced
    // from `DmRepository.watchOutgoing`. `sendMessage` enqueues the row
    // before any signer round-trip, so the watch tick that carries the
    // optimistic lands within microseconds of dispatch — without any
    // bloc-side in-memory tracking. This handler is responsible only
    // for transient `sendStatus` transitions and the SnackBar
    // affordance state (`lastFailedSend` / `lastPartialSend`).
    emit(
      state.copyWith(
        sendStatus: SendStatus.sending,
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
      // to the recipient. [lastPartialSend.rumorIds] carries the
      // per-recipient rumor ids whose self-wrap publish failed, so
      // retrying republishes only those self-wraps via
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
          lastFailedSend: FailedSend(
            content: event.content,
            recipientPubkeys: event.recipientPubkeys,
          ),
        ),
      );
    }
    // Note: the in-flight queue row remains in `state.pendingOutgoing`
    // on failure/partial. The retry service (`OutgoingDmRetryService`)
    // sweeps it independently. The user-facing SnackBar still offers
    // a manual retry for fast-fail (`lastFailedSend`) and self-wrap
    // recovery (`lastPartialSend`) — same UX as #3908.
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
        if (e is ArgumentError) {
          // The row was already removed or is no longer valid for this
          // account. Treat it as terminal and drop it from the retry set.
          continue;
        }

        // Missing DAO wiring is an invariant failure; any other throw
        // is unexpected. Preserve retryability and surface it for
        // telemetry.
        stillFailing.add(rumorId);
        lastError = e;
        lastStackTrace = stackTrace;
      }
    }

    if (lastError != null) {
      addError(
        Reportable(lastError, context: '_onSelfWrapRecoveryRequested'),
        lastStackTrace,
      );
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
