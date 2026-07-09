// ABOUTME: Cubit for the request preview screen data.
// ABOUTME: Loads message count and resolves participant pubkeys from the DB.

import 'package:bloc/bloc.dart';
import 'package:dm_repository/dm_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/dm/minor_dm_approval.dart';

enum RequestPreviewStatus { loading, loaded, error, denied }

class RequestPreviewState extends Equatable {
  const RequestPreviewState({
    this.status = RequestPreviewStatus.loading,
    this.messageCount = 0,
    this.participantPubkeys = const [],
    this.messages = const [],
  });

  final RequestPreviewStatus status;
  final int messageCount;
  final List<String> participantPubkeys;
  final List<DmMessage> messages;

  RequestPreviewState copyWith({
    RequestPreviewStatus? status,
    int? messageCount,
    List<String>? participantPubkeys,
    List<DmMessage>? messages,
  }) {
    return RequestPreviewState(
      status: status ?? this.status,
      messageCount: messageCount ?? this.messageCount,
      participantPubkeys: participantPubkeys ?? this.participantPubkeys,
      messages: messages ?? this.messages,
    );
  }

  @override
  List<Object?> get props => [
    status,
    messageCount,
    participantPubkeys,
    messages,
  ];
}

class RequestPreviewCubit extends Cubit<RequestPreviewState> {
  RequestPreviewCubit({
    required DmRepository dmRepository,
    required this.conversationId,
    required bool Function() isDmRestricted,
    required bool Function(String) isApprovedRecipient,
    List<String> initialParticipantPubkeys = const [],
  }) : _dmRepository = dmRepository,
       _isDmRestricted = isDmRestricted,
       _isApprovedRecipient = isApprovedRecipient,
       _initialParticipantPubkeys = initialParticipantPubkeys,
       super(const RequestPreviewState());

  final DmRepository _dmRepository;

  /// Whether the current user is DM-restricted (#176), read at load time.
  final bool Function() _isDmRestricted;

  /// Whether a counterparty is an approved official recipient (#176).
  final bool Function(String) _isApprovedRecipient;

  final List<String> _initialParticipantPubkeys;

  /// The conversation ID this preview is for.
  final String conversationId;

  /// Loads message count and resolves participant pubkeys if needed.
  ///
  /// Counterparties are resolved FIRST and checked against the #176 gate: a
  /// DM-restricted user reaching this preview via a stale or direct
  /// `/inbox/message-requests/:id` URL must be denied before any hidden
  /// request metadata (count, messages) is read — the same fail-closed
  /// predicate as the conversation route guard and the inbox list filter.
  Future<void> load() async {
    try {
      // Use provided pubkeys if available, otherwise load from DB.
      final pubkeys = _initialParticipantPubkeys.isNotEmpty
          ? _initialParticipantPubkeys
          : await _resolveParticipants();

      if (_isDmRestricted() &&
          !allParticipantsApprovedForMinor(pubkeys, _isApprovedRecipient)) {
        if (!isClosed) {
          emit(state.copyWith(status: RequestPreviewStatus.denied));
        }
        return;
      }

      final messageCount = await _dmRepository.countMessagesInConversation(
        conversationId,
      );
      final messages = await _dmRepository.getMessages(
        conversationId,
        limit: 10,
      );

      if (!isClosed) {
        emit(
          state.copyWith(
            status: RequestPreviewStatus.loaded,
            messageCount: messageCount,
            participantPubkeys: pubkeys,
            messages: messages,
          ),
        );
      }
    } catch (e, stackTrace) {
      // Drift read failures are expected. Per
      // .claude/rules/error_handling.md they are NOT Reportable.
      addError(e, stackTrace);
      if (!isClosed) {
        emit(state.copyWith(status: RequestPreviewStatus.error));
      }
    }
  }

  Future<List<String>> _resolveParticipants() async {
    final conversation = await _dmRepository.getConversation(conversationId);
    if (conversation == null) return [];
    final userPubkey = _dmRepository.userPubkey;
    return conversation.participantPubkeys
        .where((pk) => pk != userPubkey)
        .toList();
  }
}
