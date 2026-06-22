// ABOUTME: Repository for NIP-25 emoji reactions on NIP-17 DMs.
// ABOUTME: Reactions ride the same seal+gift-wrap envelope as DM
// ABOUTME: messages — kind 7 rumor wrapped to recipient + self. Privacy
// ABOUTME: comes from envelope reuse, not a custom kind or scheme.

import 'dart:async';
import 'dart:convert';

import 'package:db_client/db_client.dart';
import 'package:dm_repository/src/dm_reactions_repository_reportable_sites.dart';
import 'package:dm_repository/src/dm_repository.dart';
import 'package:dm_repository/src/nip17_message_service.dart';
import 'package:meta/meta.dart';
import 'package:models/models.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/event_kind.dart';
import 'package:unified_logger/unified_logger.dart';

/// Reporter port for forwarding DAO-layer surprises to Crashlytics.
///
/// Wired in the app layer to `CrashReportingService.instance.recordError`.
/// Network/IO failures from `sendRumor` are NOT routed through this —
/// only DAO surprises are Reportable per the error-handling matrix.
typedef DmReactionsRepositoryErrorReporter =
    void Function(Object error, StackTrace stackTrace, {required String site});

/// Public outcome of an outgoing reaction publish attempt.
@immutable
class DmReactionPublishResult {
  /// Construct a publish result.
  const DmReactionPublishResult({
    required this.success,
    required this.rumorId,
    this.errorMessage,
  });

  /// Whether the gift-wrap publish landed for the recipient.
  final bool success;

  /// The reaction rumor id used. Stable across retries.
  final String rumorId;

  /// One-line summary for logs; never user-facing copy.
  final String? errorMessage;
}

/// Outcome of ingesting an incoming wrapped reaction/deletion rumor, used by
/// `DmRepository` to decide whether to record the gift wrap in the
/// processed-wrap dedup ledger (#5452).
enum DmReactionWrapOutcome {
  /// The wrap reached a terminal state — persisted, or permanently dropped for
  /// a reason that will not change (malformed content/tags, no matching row).
  /// Safe to record so the wrap is never re-decrypted.
  processed,

  /// The wrap could not be applied yet (signer not ready, the reaction's
  /// target message has not synced, or a deletion's target reaction has not
  /// synced). Must NOT be recorded so it re-decrypts on a later launch once the
  /// target exists — preserving eventual consistency.
  deferred,
}

/// Repository for DM emoji reactions.
///
/// Public surface:
/// - `publish` — optimistic insert + wrap + send.
/// - `removeOwn` — NIP-09 kind-5 deletion of an own reaction.
/// - `watchForConversation` — Drift stream for the chip render path.
/// - `persistIncoming` — entry point for the receive pipeline (called
///   from `DmRepository._handleGiftWrapEvent` when `rumor.kind == 7`).
class DmReactionsRepository {
  /// Construct the repository. Most fields are nullable for the legacy
  /// dependency-injection pattern where credentials are bound after
  /// auth via [setCredentials].
  DmReactionsRepository({
    required DmReactionsDao reactionsDao,
    NIP17MessageService? messageService,
    String? userPubkey,
    DmReactionsRepositoryErrorReporter? errorReporter,
    ConversationsDao? conversationsDao,
    DirectMessagesDao? directMessagesDao,
  }) : _reactionsDao = reactionsDao,
       _messageService = messageService,
       _userPubkey = userPubkey ?? '',
       _errorReporter = errorReporter,
       _conversationsDao = conversationsDao,
       _directMessagesDao = directMessagesDao;

  final DmReactionsDao _reactionsDao;
  NIP17MessageService? _messageService;
  String _userPubkey;
  final DmReactionsRepositoryErrorReporter? _errorReporter;

  /// Source of conversation participant sets, used to fan a group reaction's
  /// gift wrap out to every member. Null in legacy/test wiring → 1:1 only.
  final ConversationsDao? _conversationsDao;

  /// Source of the reacted message's stored conversation id, used to resolve
  /// the conversation (1:1 **or** group) for an incoming reaction. Null in
  /// legacy/test wiring → 1:1 inference only.
  final DirectMessagesDao? _directMessagesDao;

  /// Maximum permitted reaction content length. NIP-25 has no hard cap,
  /// but anything over ~128 chars is almost certainly malformed.
  static const int _maxReactionContentLength = 128;

  /// Hard cap on a single publish round-trip. Nostr publishes have no
  /// inherent timeout — a stalled relay socket can leave the await
  /// hanging until the process is restarted. Capping at 15 s lets the
  /// UI surface a retryable failure within a tap-test attention span.
  static const Duration _publishTimeout = Duration(seconds: 15);

  /// Has the repository been wired with auth credentials?
  bool get isInitialized => _messageService != null && _userPubkey.isNotEmpty;

  /// Set the credentials needed for outgoing publishes.
  void setCredentials({
    required String userPubkey,
    required NIP17MessageService messageService,
  }) {
    _userPubkey = userPubkey;
    _messageService = messageService;
  }

  /// Clear credentials (sign-out path).
  void clearCredentials() {
    _userPubkey = '';
    _messageService = null;
  }

  /// Reactive stream of every live reaction in [conversationId] for the
  /// current account, collapsed to at most one reaction per reactor per
  /// target message (the cap-at-one invariant — see [_collapsePerReactor]).
  /// Empty list when uninitialized.
  Stream<List<DmReaction>> watchForConversation(String conversationId) {
    if (_userPubkey.isEmpty) {
      return Stream<List<DmReaction>>.value(const <DmReaction>[]);
    }
    return _reactionsDao
        .watchForConversation(
          conversationId: conversationId,
          ownerPubkey: _userPubkey,
        )
        .map((rows) => _collapsePerReactor(rows.map(_rowToModel).toList()));
  }

  /// Enforce the cap-at-one invariant at the read boundary: keep at most one
  /// live reaction per (targetMessageId, reactorPubkey), the most recent by
  /// `createdAt`.
  ///
  /// The DAO can momentarily hold several live rows for one reactor on one
  /// message — a superseding kind-5 deletion that never arrived (the reactor
  /// was offline, or a remote client switched emoji without deleting the old
  /// reaction), or the dual-cubit optimistic-insert race tracked by #5419.
  /// The render path (pill avatar stack + who-reacted sheet) assumes one row
  /// per reactor; collapsing here keeps it correct regardless of stored
  /// duplicates. Returned in ascending `createdAt` order, matching the DAO's
  /// `ORDER BY created_at ASC` so the pill's "reversed == most-recent-first"
  /// assumption holds.
  static List<DmReaction> _collapsePerReactor(List<DmReaction> reactions) {
    if (reactions.length < 2) return reactions;
    final latestByReactor = <(String, String), DmReaction>{};
    for (final reaction in reactions) {
      final key = (reaction.targetMessageId, reaction.reactorPubkey);
      final existing = latestByReactor[key];
      if (existing == null || reaction.createdAt >= existing.createdAt) {
        latestByReactor[key] = reaction;
      }
    }
    if (latestByReactor.length == reactions.length) return reactions;
    return latestByReactor.values.toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  /// Publish a new reaction. Performs cap-at-one supersede when the
  /// reactor already has a live reaction on this target.
  Future<DmReactionPublishResult> publish({
    required String conversationId,
    required String targetMessageId,
    required String targetMessageAuthor,
    required String emoji,
  }) async {
    final messageService = _messageService;
    if (messageService == null || _userPubkey.isEmpty) {
      return const DmReactionPublishResult(
        success: false,
        rumorId: '',
        errorMessage: 'Repository not initialized',
      );
    }

    final additionalTags = <List<String>>[
      ['e', targetMessageId],
      ['p', targetMessageAuthor],
      ['k', EventKind.privateDirectMessage.toString()],
    ];
    final rumor = messageService.buildRumor(
      recipientPubkey: targetMessageAuthor,
      content: emoji,
      eventKind: EventKind.reaction,
      additionalTags: additionalTags,
    );
    final rumorId = rumor.id;

    final List<String> superseded;
    try {
      // Atomic cap-at-one: soft-deletes any prior live own reaction on this
      // target and inserts the new pending row in one transaction, returning
      // the superseded ids for the wire-side kind-5 below (#5419).
      superseded = await _reactionsDao.insertOwnReactionSuperseding(
        placeholderId: rumorId,
        conversationId: conversationId,
        targetMessageId: targetMessageId,
        targetMessageAuthor: targetMessageAuthor,
        reactorPubkey: _userPubkey,
        emoji: emoji,
        createdAt: rumor.createdAt,
        ownerPubkey: _userPubkey,
        rumorEventJson: jsonEncode(rumor.toJson()),
      );
    } on Object catch (e, st) {
      _errorReporter?.call(
        e,
        st,
        site: DmReactionsRepositoryReportableSites.publishOptimisticInsert,
      );
      return DmReactionPublishResult(
        success: false,
        rumorId: rumorId,
        errorMessage: 'Optimistic insert failed',
      );
    }

    final recipients = await _resolveWrapRecipients(
      conversationId: conversationId,
      targetMessageAuthor: targetMessageAuthor,
    );

    // Emit a NIP-09 kind-5 deletion on the wire for each superseded prior
    // reaction. Fire-and-forget and kept OUTSIDE the DAO transaction — a
    // stalled relay socket must never block the local optimistic write.
    for (final priorId in superseded) {
      unawaited(
        _publishKind5Deletion(
          reactionEventId: priorId,
          recipients: recipients,
          messageService: messageService,
        ),
      );
    }

    try {
      final result = await _fanOutRumor(
        messageService: messageService,
        rumor: rumor,
        recipients: recipients,
      );
      switch (result) {
        case NIP17SendSuccess():
          try {
            await _reactionsDao.swapPlaceholderId(
              placeholderId: rumorId,
              realRumorId: rumorId,
              ownerPubkey: _userPubkey,
            );
          } on Object catch (e, st) {
            _errorReporter?.call(
              e,
              st,
              site: DmReactionsRepositoryReportableSites.publishSwapPlaceholder,
            );
          }
          return DmReactionPublishResult(success: true, rumorId: rumorId);
        case NIP17SendFailure(:final error):
          await _reactionsDao.markFailed(
            placeholderId: rumorId,
            ownerPubkey: _userPubkey,
          );
          return DmReactionPublishResult(
            success: false,
            rumorId: rumorId,
            errorMessage: error,
          );
      }
    } on Object catch (e) {
      Log.warning(
        'DM reaction publish threw: $e',
        category: LogCategory.system,
      );
      await _reactionsDao.markFailed(
        placeholderId: rumorId,
        ownerPubkey: _userPubkey,
      );
      return DmReactionPublishResult(
        success: false,
        rumorId: rumorId,
        errorMessage: e.toString(),
      );
    }
  }

  /// Retry a previously-failed reaction publish by replaying the same
  /// rumor (read from `rumor_event_json`).
  ///
  /// Reliability contract:
  /// 1. Marks the DAO row `'pending'` BEFORE the send so the chip
  ///    reflects in-flight state in the persistent layer — survives a
  ///    cubit rebuild / hot-restart.
  /// 2. Wraps the underlying `sendRumor` in a 15 s timeout so a hung
  ///    relay socket can't lock the user out of further retries.
  /// 3. On any non-success outcome (timeout, NIP17SendFailure, throw)
  ///    flips the DAO row back to `'failed'` so the chip is tappable
  ///    again immediately.
  Future<DmReactionPublishResult> retry({
    required String rumorId,
    required String targetMessageAuthor,
  }) async {
    final messageService = _messageService;
    if (messageService == null || _userPubkey.isEmpty) {
      return DmReactionPublishResult(
        success: false,
        rumorId: rumorId,
        errorMessage: 'Repository not initialized',
      );
    }
    final rumorJson = await _reactionsDao.getRumorJson(
      id: rumorId,
      ownerPubkey: _userPubkey,
    );
    if (rumorJson == null) {
      return DmReactionPublishResult(
        success: false,
        rumorId: rumorId,
        errorMessage: 'No stored rumor to retry',
      );
    }
    final decoded = jsonDecode(rumorJson) as Map<String, dynamic>;
    final rumor = Event.fromJson(decoded);

    final retryRow = await _reactionsDao.getById(
      id: rumorId,
      ownerPubkey: _userPubkey,
    );
    final recipients = retryRow != null
        ? await _resolveWrapRecipients(
            conversationId: retryRow.conversationId,
            targetMessageAuthor: targetMessageAuthor,
          )
        : <String>[targetMessageAuthor];

    // Persist `pending` so the chip surfaces in-flight state across
    // a cubit rebuild. If this DAO write fails, we still attempt the
    // send — the user-visible recovery path is the chip falling back
    // to `failed` via the next branch.
    try {
      await _reactionsDao.markPending(id: rumorId, ownerPubkey: _userPubkey);
    } on Object {
      // best-effort
    }

    try {
      final result = await _fanOutRumor(
        messageService: messageService,
        rumor: rumor,
        recipients: recipients,
      );
      switch (result) {
        case NIP17SendSuccess():
          await _reactionsDao.swapPlaceholderId(
            placeholderId: rumorId,
            realRumorId: rumorId,
            ownerPubkey: _userPubkey,
          );
          return DmReactionPublishResult(success: true, rumorId: rumorId);
        case NIP17SendFailure(:final error):
          await _reactionsDao.markFailed(
            placeholderId: rumorId,
            ownerPubkey: _userPubkey,
          );
          return DmReactionPublishResult(
            success: false,
            rumorId: rumorId,
            errorMessage: error,
          );
      }
    } on Object catch (e) {
      Log.warning('DM reaction retry threw: $e', category: LogCategory.system);
      await _reactionsDao.markFailed(
        placeholderId: rumorId,
        ownerPubkey: _userPubkey,
      );
      return DmReactionPublishResult(
        success: false,
        rumorId: rumorId,
        errorMessage: e.toString(),
      );
    }
  }

  /// Soft-delete an own reaction locally and emit a NIP-09 kind-5
  /// deletion on the wire. Returns after the local update.
  Future<void> removeOwn({
    required String rumorId,
    required String targetMessageAuthor,
  }) async {
    final messageService = _messageService;
    if (messageService == null || _userPubkey.isEmpty) return;
    final row = await _reactionsDao.getById(
      id: rumorId,
      ownerPubkey: _userPubkey,
    );
    try {
      await _reactionsDao.softDelete(id: rumorId, ownerPubkey: _userPubkey);
    } on Object catch (e, st) {
      _errorReporter?.call(
        e,
        st,
        site: DmReactionsRepositoryReportableSites.removeOwnSoftDelete,
      );
      return;
    }
    final recipients = row != null
        ? await _resolveWrapRecipients(
            conversationId: row.conversationId,
            targetMessageAuthor: targetMessageAuthor,
          )
        : <String>[targetMessageAuthor];
    unawaited(
      _publishKind5Deletion(
        reactionEventId: rumorId,
        recipients: recipients,
        messageService: messageService,
      ),
    );
  }

  /// Persist an incoming kind-7 reaction rumor. Called from
  /// `DmRepository._handleGiftWrapEvent` after rumor extraction.
  ///
  /// Returns [DmReactionWrapOutcome.processed] when the wrap reached a terminal
  /// state (persisted, or permanently dropped for malformed content/tags), and
  /// [DmReactionWrapOutcome.deferred] when it could not be applied yet (signer
  /// not ready, or the target message has not synced) so the caller leaves it
  /// out of the dedup ledger and lets it re-decrypt later. See #5452.
  Future<DmReactionWrapOutcome> persistIncoming({
    required Event rumorEvent,
    required String giftWrapId,
  }) async {
    if (_userPubkey.isEmpty) return DmReactionWrapOutcome.deferred;
    if (rumorEvent.kind != EventKind.reaction) {
      return DmReactionWrapOutcome.processed;
    }
    final content = rumorEvent.content;
    if (content.isEmpty || content.length > _maxReactionContentLength) {
      Log.debug(
        'Dropping invalid reaction rumor ${rumorEvent.id} '
        '(content length: ${content.length})',
        category: LogCategory.system,
      );
      return DmReactionWrapOutcome.processed;
    }
    String? targetMessageId;
    String? targetAuthor;
    for (final tag in rumorEvent.tags) {
      if (tag.length >= 2) {
        if (tag[0] == 'e' && targetMessageId == null) {
          targetMessageId = tag[1];
        }
        if (tag[0] == 'p' && targetAuthor == null) targetAuthor = tag[1];
      }
    }
    if (targetMessageId == null ||
        targetMessageId.isEmpty ||
        targetMessageId.length != 64) {
      Log.debug(
        'Dropping reaction rumor ${rumorEvent.id} — missing/invalid e tag',
        category: LogCategory.system,
      );
      return DmReactionWrapOutcome.processed;
    }
    targetAuthor ??= rumorEvent.pubkey;
    final conversationId = await _resolveConversationIdForReaction(
      reactorPubkey: rumorEvent.pubkey,
      targetAuthor: targetAuthor,
      targetMessageId: targetMessageId,
    );
    // Target message not synced yet: leave undecided so a later launch retries
    // and the reaction lands once the message arrives. See #5452 (D4-terminal).
    if (conversationId == null) return DmReactionWrapOutcome.deferred;
    try {
      await _reactionsDao.upsertIncoming(
        id: rumorEvent.id,
        conversationId: conversationId,
        targetMessageId: targetMessageId,
        targetMessageAuthor: targetAuthor,
        reactorPubkey: rumorEvent.pubkey,
        emoji: content,
        createdAt: rumorEvent.createdAt,
        giftWrapId: giftWrapId,
        ownerPubkey: _userPubkey,
      );
      return DmReactionWrapOutcome.processed;
    } on Object catch (e, st) {
      _errorReporter?.call(
        e,
        st,
        site: DmReactionsRepositoryReportableSites.persistIncomingDaoUpsert,
      );
      // Transient DAO failure — let it retry rather than cement a skip.
      return DmReactionWrapOutcome.deferred;
    }
  }

  /// Apply an incoming wrapped NIP-09 kind-5 deletion for a reaction row.
  ///
  /// DM message deletions use the top-level kind-5 path in [DmRepository].
  /// This handler is specifically for wrapped deletions emitted by the
  /// reactions feature, which tag the deleted event with `k=7`.
  ///
  /// Returns [DmReactionWrapOutcome.deferred] — leaving the wrap out of the
  /// dedup ledger so it re-decrypts on a later launch — when the signer is not
  /// ready, when a targeted reaction row has not synced yet, or on a transient
  /// soft-delete failure. Gift wraps carry NIP-59 randomized `created_at`, so a
  /// deletion can drain before the reaction it removes; recording it as
  /// terminal then would let the reaction insert live afterwards and never be
  /// soft-deleted. Otherwise returns [DmReactionWrapOutcome.processed]
  /// (terminal): the deletion applied, the target was already deleted, or the
  /// deletion is invalid (author mismatch). The soft-delete is idempotent, so
  /// re-applying on a benign re-decrypt is safe. #5452.
  Future<DmReactionWrapOutcome> handleIncomingDeletion({
    required Event rumorEvent,
    required String giftWrapId,
  }) async {
    if (_userPubkey.isEmpty) return DmReactionWrapOutcome.deferred;
    if (rumorEvent.kind != EventKind.eventDeletion) {
      return DmReactionWrapOutcome.processed;
    }
    if (!_targetsReactionKind(rumorEvent.tags)) {
      return DmReactionWrapOutcome.processed;
    }

    var outcome = DmReactionWrapOutcome.processed;
    for (final tag in rumorEvent.tags) {
      if (tag.length < 2 || tag[0] != 'e') continue;
      final rumorId = tag[1];
      final row = await _reactionsDao.getById(
        id: rumorId,
        ownerPubkey: _userPubkey,
      );
      // Target reaction not synced yet. Defer so the wrap stays unrecorded and
      // re-decrypts once the reaction lands — otherwise upsertIncoming would
      // insert it live afterwards and it would never be soft-deleted (the
      // deletion-before-reaction drain race; NIP-59 randomizes gift-wrap
      // created_at). Symmetric with persistIncoming's unsynced-target handling.
      // #5452.
      if (row == null) {
        outcome = DmReactionWrapOutcome.deferred;
        continue;
      }
      if (row.isDeleted) continue;

      // NIP-09: only the original reaction author may delete their reaction.
      if (row.reactorPubkey != rumorEvent.pubkey) {
        Log.debug(
          'Ignoring wrapped reaction deletion for $rumorId: author mismatch '
          '(event=${rumorEvent.pubkey}, reactor=${row.reactorPubkey}, '
          'giftWrap=$giftWrapId)',
          category: LogCategory.system,
        );
        continue;
      }

      try {
        await _reactionsDao.softDelete(id: rumorId, ownerPubkey: _userPubkey);
      } on Object catch (e, st) {
        _errorReporter?.call(
          e,
          st,
          site: DmReactionsRepositoryReportableSites
              .handleIncomingDeletionSoftDelete,
        );
        // Transient DAO failure — let it retry rather than cement a skip.
        outcome = DmReactionWrapOutcome.deferred;
      }
    }
    return outcome;
  }

  // -------------------------------------------------------------------------
  // Internals
  // -------------------------------------------------------------------------

  /// Wrap `sendRumor` with a hard timeout. Nostr publishes have no
  /// built-in timeout — a stalled socket can keep the await pending
  /// indefinitely, which (under a `sequential()` event transformer)
  /// quietly swallows every subsequent retry tap. The `_publishTimeout`
  /// cap converts those hangs into surfaced `NIP17SendFailure` results.
  Future<NIP17SendResult> _sendRumorWithTimeout({
    required NIP17MessageService messageService,
    required Event rumor,
    required String recipientPubkey,
  }) {
    return messageService
        .sendRumor(rumorEvent: rumor, recipientPubkey: recipientPubkey)
        .timeout(
          _publishTimeout,
          onTimeout: () => NIP17SendResult.failure(
            'Reaction publish timed out after '
            '${_publishTimeout.inSeconds}s',
          ),
        );
  }

  /// Resolve the gift-wrap recipient set for a reaction in [conversationId].
  ///
  /// For a group conversation, returns every participant except the current
  /// user (the wrap fans out to all members). For a 1:1 (or when the
  /// conversation can't be resolved), returns `[targetMessageAuthor]` so the
  /// behavior is byte-identical to the pre-group path.
  Future<List<String>> _resolveWrapRecipients({
    required String conversationId,
    required String targetMessageAuthor,
  }) async {
    final dao = _conversationsDao;
    if (dao == null) return [targetMessageAuthor];
    try {
      final convo = await dao.getConversation(
        conversationId,
        ownerPubkey: _userPubkey,
      );
      if (convo == null || !convo.isGroup) return [targetMessageAuthor];
      final decoded = jsonDecode(convo.participantPubkeys);
      if (decoded is! List) return [targetMessageAuthor];
      final others = decoded
          .whereType<String>()
          .where((p) => p != _userPubkey)
          .toList();
      return others.isEmpty ? [targetMessageAuthor] : others;
    } on Object {
      return [targetMessageAuthor];
    }
  }

  /// Wrap [rumor] to each of [recipients] (each send also self-wraps for
  /// cross-device recovery; self-wrap copies dedupe on the rumor id at the
  /// receiver). Succeeds if any recipient wrap lands.
  Future<NIP17SendResult> _fanOutRumor({
    required NIP17MessageService messageService,
    required Event rumor,
    required List<String> recipients,
  }) async {
    NIP17SendResult? lastSuccess;
    NIP17SendResult? lastFailure;
    for (final recipient in recipients) {
      final result = await _sendRumorWithTimeout(
        messageService: messageService,
        rumor: rumor,
        recipientPubkey: recipient,
      );
      switch (result) {
        case NIP17SendSuccess():
          lastSuccess = result;
        case NIP17SendFailure():
          lastFailure = result;
      }
    }
    return lastSuccess ??
        lastFailure ??
        const NIP17SendResult.failure('No reaction wrap recipients');
  }

  Future<void> _publishKind5Deletion({
    required String reactionEventId,
    required List<String> recipients,
    required NIP17MessageService messageService,
  }) async {
    if (recipients.isEmpty) return;
    try {
      final deletion = messageService.buildRumor(
        recipientPubkey: recipients.first,
        content: '',
        eventKind: EventKind.eventDeletion,
        additionalTags: [
          ['e', reactionEventId],
          ['k', EventKind.reaction.toString()],
        ],
      );
      await _fanOutRumor(
        messageService: messageService,
        rumor: deletion,
        recipients: recipients,
      );
    } on Object catch (e) {
      Log.warning(
        'DM reaction kind-5 deletion threw: $e',
        category: LogCategory.system,
      );
    }
  }

  /// Resolve the conversation id for an incoming reaction.
  ///
  /// A kind-7 reaction only carries `e`/`p`/`k` tags, never the full group
  /// participant set, so the authoritative source is the reacted message's
  /// stored row (looked up by its rumor id) — this resolves both 1:1 and
  /// group conversations correctly. When the target isn't in the local store
  /// (e.g. a group reaction arriving before the reel message synced — a
  /// narrow window since the reel is persisted at send time), falls back to
  /// 1:1 inference, dropping group reactions rather than mis-attributing them.
  Future<String?> _resolveConversationIdForReaction({
    required String reactorPubkey,
    required String targetAuthor,
    required String targetMessageId,
  }) async {
    final messagesDao = _directMessagesDao;
    if (messagesDao != null) {
      try {
        final targetRow = await messagesDao.getMessageById(
          targetMessageId,
          ownerPubkey: _userPubkey,
        );
        if (targetRow != null) return targetRow.conversationId;
      } on Object {
        // Fall through to 1:1 inference.
      }
    }
    if (reactorPubkey != _userPubkey && targetAuthor != _userPubkey) {
      return null;
    }
    final participants = <String>{reactorPubkey, targetAuthor}.toList();
    if (participants.length != 2) return null;
    return DmRepository.computeConversationId(participants);
  }

  DmReaction _rowToModel(DmReactionRow row) {
    final publishStatus = switch (row.publishStatus) {
      'pending' => DmReactionPublishStatus.pending,
      'failed' => DmReactionPublishStatus.failed,
      'sent' => DmReactionPublishStatus.sent,
      _ => DmReactionPublishStatus.received,
    };
    return DmReaction(
      id: row.id,
      conversationId: row.conversationId,
      targetMessageId: row.targetMessageId,
      targetMessageAuthor: row.targetMessageAuthor,
      reactorPubkey: row.reactorPubkey,
      emoji: row.emoji,
      createdAt: row.createdAt,
      ownerPubkey: row.ownerPubkey,
      publishStatus: publishStatus,
      giftWrapId: row.giftWrapId,
    );
  }

  bool _targetsReactionKind(List<List<String>> tags) {
    for (final tag in tags) {
      if (tag.length >= 2 &&
          tag[0] == 'k' &&
          tag[1] == EventKind.reaction.toString()) {
        return true;
      }
    }
    return false;
  }
}
