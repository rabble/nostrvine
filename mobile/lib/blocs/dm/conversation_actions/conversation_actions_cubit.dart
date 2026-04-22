// ABOUTME: Cubit for DM conversation actions (report, block, remove).
// ABOUTME: Constructor-injected services, no Riverpod at action time.

import 'package:bloc/bloc.dart';
import 'package:content_blocklist_repository/content_blocklist_repository.dart';
import 'package:dm_repository/dm_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:openvine/services/content_moderation_service.dart';
import 'package:openvine/services/content_reporting_service.dart';

enum ConversationActionsStatus { idle, processing, success, failure }

class ConversationActionsState extends Equatable {
  const ConversationActionsState({
    this.status = ConversationActionsStatus.idle,
  });

  final ConversationActionsStatus status;

  ConversationActionsState copyWith({ConversationActionsStatus? status}) {
    return ConversationActionsState(status: status ?? this.status);
  }

  @override
  List<Object?> get props => [status];
}

/// Handles report, block, and remove actions for DM conversations.
///
/// Services are constructor-injected so the widget layer never reads
/// Riverpod providers at action time.
class ConversationActionsCubit extends Cubit<ConversationActionsState> {
  ConversationActionsCubit({
    required ContentReportingService? contentReportingService,
    required ContentBlocklistRepository contentBlocklistRepository,
    required DmRepository dmRepository,
    required String currentUserPubkey,
  }) : _reportingService = contentReportingService,
       _blocklistRepository = contentBlocklistRepository,
       _dmRepository = dmRepository,
       _currentUserPubkey = currentUserPubkey,
       super(const ConversationActionsState());

  final ContentReportingService? _reportingService;
  final ContentBlocklistRepository _blocklistRepository;
  final DmRepository _dmRepository;
  final String _currentUserPubkey;

  /// Report a user from a DM conversation.
  ///
  /// Returns `true` if the report was submitted successfully.
  Future<bool> reportUser(String pubkey) async {
    final service = _reportingService;
    if (service == null) return false;

    emit(state.copyWith(status: ConversationActionsStatus.processing));
    try {
      final result = await service.reportUser(
        userPubkey: pubkey,
        reason: ContentFilterReason.other,
        details: 'Reported from DM conversation',
      );
      emit(state.copyWith(status: ConversationActionsStatus.idle));
      return result.success;
    } catch (e, stackTrace) {
      addError(e, stackTrace);
      emit(state.copyWith(status: ConversationActionsStatus.idle));
      return false;
    }
  }

  /// Whether [pubkey] is currently on the blocklist.
  bool isBlocked(String pubkey) => _blocklistRepository.isBlocked(pubkey);

  /// Block a user from a DM conversation.
  Future<void> blockUser(String pubkey) async {
    emit(state.copyWith(status: ConversationActionsStatus.processing));
    try {
      await _blocklistRepository.blockUser(
        pubkey,
        ourPubkey: _currentUserPubkey,
      );
      emit(state.copyWith(status: ConversationActionsStatus.success));
    } catch (e, stackTrace) {
      addError(e, stackTrace);
      emit(state.copyWith(status: ConversationActionsStatus.failure));
    }
  }

  /// Unblock a previously blocked user.
  Future<void> unblockUser(String pubkey) async {
    emit(state.copyWith(status: ConversationActionsStatus.processing));
    try {
      await _blocklistRepository.unblockUser(pubkey);
      emit(state.copyWith(status: ConversationActionsStatus.success));
    } catch (e, stackTrace) {
      addError(e, stackTrace);
      emit(state.copyWith(status: ConversationActionsStatus.failure));
    }
  }

  /// Remove a conversation locally.
  ///
  /// Returns `true` if the conversation was removed successfully.
  Future<bool> removeConversation(String conversationId) async {
    emit(state.copyWith(status: ConversationActionsStatus.processing));
    try {
      await _dmRepository.removeConversation(conversationId);
      emit(state.copyWith(status: ConversationActionsStatus.success));
      return true;
    } catch (e, stackTrace) {
      addError(e, stackTrace);
      emit(state.copyWith(status: ConversationActionsStatus.failure));
      return false;
    }
  }
}
