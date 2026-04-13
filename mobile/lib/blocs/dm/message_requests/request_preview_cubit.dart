// ABOUTME: Cubit for the request preview screen data.
// ABOUTME: Loads message count and resolves participant pubkeys from the DB.

import 'package:bloc/bloc.dart';
import 'package:dm_repository/dm_repository.dart';
import 'package:equatable/equatable.dart';

enum RequestPreviewStatus { loading, loaded, error }

class RequestPreviewState extends Equatable {
  const RequestPreviewState({
    this.status = RequestPreviewStatus.loading,
    this.messageCount = 0,
    this.participantPubkeys = const [],
  });

  final RequestPreviewStatus status;
  final int messageCount;
  final List<String> participantPubkeys;

  RequestPreviewState copyWith({
    RequestPreviewStatus? status,
    int? messageCount,
    List<String>? participantPubkeys,
  }) {
    return RequestPreviewState(
      status: status ?? this.status,
      messageCount: messageCount ?? this.messageCount,
      participantPubkeys: participantPubkeys ?? this.participantPubkeys,
    );
  }

  @override
  List<Object?> get props => [status, messageCount, participantPubkeys];
}

class RequestPreviewCubit extends Cubit<RequestPreviewState> {
  RequestPreviewCubit({
    required DmRepository dmRepository,
    required this.conversationId,
    List<String> initialParticipantPubkeys = const [],
  }) : _dmRepository = dmRepository,
       _initialParticipantPubkeys = initialParticipantPubkeys,
       super(const RequestPreviewState());

  final DmRepository _dmRepository;
  final List<String> _initialParticipantPubkeys;

  /// The conversation ID this preview is for.
  final String conversationId;

  /// Loads message count and resolves participant pubkeys if needed.
  Future<void> load() async {
    try {
      final messageCount = await _dmRepository.countMessagesInConversation(
        conversationId,
      );

      // Use provided pubkeys if available, otherwise load from DB.
      final pubkeys = _initialParticipantPubkeys.isNotEmpty
          ? _initialParticipantPubkeys
          : await _resolveParticipants();

      emit(
        state.copyWith(
          status: RequestPreviewStatus.loaded,
          messageCount: messageCount,
          participantPubkeys: pubkeys,
        ),
      );
    } catch (e, stackTrace) {
      addError(e, stackTrace);
      emit(state.copyWith(status: RequestPreviewStatus.error));
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
