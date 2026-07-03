// ABOUTME: Cubit for the in-player reel reply composer (text replies that
// ABOUTME: thread under a reel shared into a DM). Reactions use the reactions
// ABOUTME: cubit; this owns only the text-reply publish lifecycle.

import 'dart:async';

import 'package:dm_repository/dm_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/blocs/dm/inline_reel_reply/reportable_sites.dart';
import 'package:openvine/observability/reportable_error.dart';
import 'package:openvine/screens/feed/dm_reply_context.dart';
import 'package:unified_logger/unified_logger.dart';

part 'inline_reel_reply_state.dart';

/// Owns the publish flow for a text reply sent from the in-player reel reply
/// bar. The reply is an ordinary kind-14 DM threaded under the shared-reel
/// message (1:1 or group). Holds only a lifecycle status — the composed text
/// lives in the View's [TextEditingController].
class InlineReelReplyCubit extends Cubit<InlineReelReplyState> {
  /// Construct the cubit bound to [replyContext] (the DM the reel came from).
  InlineReelReplyCubit({
    required DmRepository dmRepository,
    required DmReplyContext replyContext,
  }) : _dmRepository = dmRepository,
       _replyContext = replyContext,
       super(const InlineReelReplyState());

  final DmRepository _dmRepository;
  final DmReplyContext _replyContext;

  /// Send [content] as a reply threaded under the shared reel.
  ///
  /// Trims/validates locally; empty submissions are a no-op. A send already
  /// in flight is dropped (double-send guard). Failures surface via a status
  /// enum + [addError]; the durable outgoing-DM queue owns the actual retry.
  Future<void> submit(String content) async {
    final trimmed = content.trim();
    if (trimmed.isEmpty) return;
    if (state.status == InlineReelReplyStatus.sending) return;

    emit(state.copyWith(status: InlineReelReplyStatus.sending));

    try {
      final bool ok;
      // When the reel has a structured video ref, the reply self-carries the
      // NIP-18 `q` citation so it stays linked to the video across devices and
      // other Nostr clients; otherwise it threads as a plain reply.
      final videoRef = _replyContext.sharedVideoRef;
      if (_replyContext.isGroup) {
        final results = videoRef != null
            ? await _dmRepository.sendSharedVideoGroup(
                recipientPubkeys: _replyContext.participantPubkeys,
                baseContent: trimmed,
                videoKind: videoRef.videoKind.kind,
                videoAuthorPubkey: videoRef.authorPubkey ?? '',
                videoDTag: videoRef.dTag,
                videoEventId: videoRef.eventId,
                relayHint: videoRef.relayHint,
                replyToId: _replyContext.sharedReelMessageId,
              )
            : await _dmRepository.sendGroupMessage(
                recipientPubkeys: _replyContext.participantPubkeys,
                content: trimmed,
                replyToId: _replyContext.sharedReelMessageId,
              );
        ok = results.any((r) => r.success);
      } else {
        final result = videoRef != null
            ? await _dmRepository.sendSharedVideo(
                recipientPubkey: _replyContext.participantPubkeys.single,
                baseContent: trimmed,
                videoKind: videoRef.videoKind.kind,
                videoAuthorPubkey: videoRef.authorPubkey ?? '',
                videoDTag: videoRef.dTag,
                videoEventId: videoRef.eventId,
                relayHint: videoRef.relayHint,
                replyToId: _replyContext.sharedReelMessageId,
              )
            : await _dmRepository.sendMessage(
                recipientPubkey: _replyContext.participantPubkeys.single,
                content: trimmed,
                replyToId: _replyContext.sharedReelMessageId,
              );
        ok = result.success;
      }
      if (!isClosed) {
        emit(
          state.copyWith(
            status: ok
                ? InlineReelReplyStatus.success
                : InlineReelReplyStatus.failure,
          ),
        );
      }
    } catch (error, stackTrace) {
      Log.error(
        'Reel reply send failed',
        name: 'InlineReelReplyCubit',
        category: LogCategory.ui,
        error: error,
        stackTrace: stackTrace,
      );
      // Programming-invariant violations (StateError/TypeError — e.g. the
      // repository wasn't initialized) are Reportable; network / IO /
      // validation failures are expected domain errors and are NOT.
      if (error is Error) {
        addError(
          Reportable(error, context: InlineReelReplyReportableSites.submit),
          stackTrace,
        );
      } else {
        addError(error, stackTrace);
      }
      if (!isClosed) {
        emit(state.copyWith(status: InlineReelReplyStatus.failure));
      }
    }
  }

  /// Reset to [InlineReelReplyStatus.initial] after the View shows the
  /// success/failure confirmation, so the next send starts clean.
  void acknowledge() {
    if (state.status == InlineReelReplyStatus.initial) return;
    emit(state.copyWith(status: InlineReelReplyStatus.initial));
  }
}
