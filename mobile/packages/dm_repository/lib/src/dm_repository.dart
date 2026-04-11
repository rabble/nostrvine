// ABOUTME: Repository for NIP-17 and NIP-04 direct message management.
// ABOUTME: Handles subscribing to gift-wrapped (NIP-17) and legacy encrypted
// ABOUTME: (NIP-04) events, decrypting messages, persisting to the database,
// ABOUTME: and providing reactive streams.
// ABOUTME: Supports Kind 14 (text), Kind 15 (file), and Kind 4 (NIP-04 DM).
// ABOUTME: Works with any NostrSigner (local keys, Keycast RPC, Amber, etc.)

import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:db_client/db_client.dart';
import 'package:dm_repository/src/dm_decryption_worker.dart';
import 'package:dm_repository/src/dm_sync_state.dart';
import 'package:dm_repository/src/nip17_message_service.dart';
import 'package:flutter/foundation.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/event_kind.dart';
import 'package:nostr_sdk/filter.dart' as nostr_filter;
import 'package:nostr_sdk/nip59/gift_wrap_util.dart';
import 'package:nostr_sdk/nostr.dart';
import 'package:nostr_sdk/signer/isolate_decrypt_signer.dart';
import 'package:nostr_sdk/signer/nostr_signer.dart';
import 'package:unified_logger/unified_logger.dart';

/// Decrypts a gift-wrapped event (kind 1059) through the NIP-17 layers
/// (gift wrap → seal → rumor) and returns the inner rumor event.
///
/// Returns `null` if decryption fails at any layer.
typedef RumorDecryptor = Future<Event?> Function(Nostr nostr, Event giftWrap);

/// Decrypts a NIP-04 encrypted direct message (kind 4).
///
/// [peerPubkey] is the other party's pubkey (the counterpart in the
/// conversation, NOT the current user's pubkey).
/// [ciphertext] is the NIP-04 ciphertext from the event content.
///
/// Returns the decrypted plaintext, or `null` if decryption fails.
typedef Nip04Decryptor =
    Future<String?> Function(
      String peerPubkey,
      String ciphertext,
    );

/// Supported NIP-17 rumor event kinds.
const Set<int> _supportedDmKinds = {
  EventKind.privateDirectMessage, // 14
  EventKind.fileMessage, // 15
};

/// Repository for NIP-17 direct message operations.
///
/// Manages the full DM lifecycle:
/// - **Receiving**: Subscribes to kind 1059 gift-wrap events, decrypts
///   through the three-layer encryption, and persists decrypted messages.
///   Supports both kind 14 (text) and kind 15 (file) messages.
/// - **Sending**: Delegates to [NIP17MessageService] for encryption and
///   publishing.
/// - **Querying**: Provides reactive streams for conversation lists and
///   individual conversation messages via Drift DAOs.
///
/// Accepts any [NostrSigner] implementation (local keys, Keycast RPC,
/// Amber, etc.) for NIP-17 gift-wrap decryption. The signer is held for
/// the lifetime of this object; callers should ensure the repository is
/// disposed when the user logs out.
class DmRepository {
  /// Creates a [DmRepository] with the given dependencies.
  DmRepository({
    required NostrClient nostrClient,
    required DirectMessagesDao directMessagesDao,
    required ConversationsDao conversationsDao,
    DmSyncState? syncState,
    NIP17MessageService? messageService,
    String? userPubkey,
    NostrSigner? signer,
    RumorDecryptor? rumorDecryptor,
    Nip04Decryptor? nip04Decryptor,
  }) : _nostrClient = nostrClient,
       _directMessagesDao = directMessagesDao,
       _conversationsDao = conversationsDao,
       _syncState = syncState,
       _messageService = messageService,
       _userPubkey = userPubkey ?? '',
       _signer = signer,
       _rumorDecryptor = rumorDecryptor ?? GiftWrapUtil.getRumorEvent,
       _nip04Decryptor = nip04Decryptor;

  final NostrClient _nostrClient;
  final DirectMessagesDao _directMessagesDao;
  final ConversationsDao _conversationsDao;
  final DmSyncState? _syncState;
  NIP17MessageService? _messageService;
  String _userPubkey;
  NostrSigner? _signer;
  RumorDecryptor _rumorDecryptor;
  Nip04Decryptor? _nip04Decryptor;

  StreamSubscription<Event>? _giftWrapSubscription;
  Timer? _reconnectTimer;
  late bool _disposed = false;

  /// Serializes event processing so concurrent subscription events
  /// never race into the dedup/insert path.
  Future<void>? _eventLock;

  /// User-scoped subscription ID to prevent collision when the provider
  /// rebuilds during auth transitions (old unsubscribe won't kill new sub).
  String _subscriptionId = 'dm_inbox';

  /// The current user's pubkey for DAO scoping, or `null` if uninitialized.
  ///
  /// Passes through to `_ownedOrLegacy` in DAO queries, where `null` means
  /// "return all rows" (legacy/unscoped mode).
  String? get _ownerPubkey => _userPubkey.isEmpty ? null : _userPubkey;

  /// Whether the repository has been initialized with auth credentials.
  ///
  /// Read-only operations (watchConversations, watchMessages, etc.) work
  /// regardless of initialization. Write operations (send) and the relay
  /// subscription require initialization.
  bool get isInitialized => _signer != null && _userPubkey.isNotEmpty;

  /// Set auth credentials on the repository.
  ///
  /// Called by `dmRepositoryProvider` when the user's keys become
  /// available. Read methods work before this; send requires it.
  ///
  /// This wires credentials only — the gift-wrap subscription is opened
  /// separately by the provider via [startListening] right after this
  /// returns, so DM ingestion runs for the whole authenticated session.
  /// Cold-start cost stays bounded thanks to the count-based windowing
  /// (`since: newestSyncedAt - 2d`) and the isolate decryption worker.
  /// See docs/plans/2026-04-05-dm-scaling-fix-design.md and #2931.
  ///
  /// Safe to call multiple times — subsequent calls for the same user are
  /// no-ops. If called with a different user, resets and re-initializes.
  void setCredentials({
    required String userPubkey,
    required NostrSigner signer,
    required NIP17MessageService messageService,
    RumorDecryptor? rumorDecryptor,
    Nip04Decryptor? nip04Decryptor,
  }) {
    if (isInitialized && _userPubkey == userPubkey) return;

    // If switching users, stop the old subscription first.
    if (isInitialized && _userPubkey != userPubkey) {
      Log.info(
        'DmRepository: switching user from $_userPubkey to $userPubkey',
        category: LogCategory.system,
      );
      _resetState();
    }

    _userPubkey = userPubkey;
    _signer = signer;
    _messageService = messageService;
    if (rumorDecryptor != null) _rumorDecryptor = rumorDecryptor;
    if (nip04Decryptor != null) _nip04Decryptor = nip04Decryptor;

    // Run post-auth maintenance sequentially so each step operates on the
    // final state of the previous one (e.g. backfill runs after merge).
    unawaited(_runPostAuthMaintenance());
  }

  /// Reset internal state so the repository can be re-initialized for a
  /// different user. Stops the relay subscription and clears credentials.
  ///
  /// Synchronous so [setCredentials] can call it inline. Subscription cancel
  /// is fire-and-forget — the old subscription filtered by the old pubkey
  /// so any late arrivals are harmless (dedup rejects them).
  void _resetState() {
    _disposed = true;
    _eventLock = null;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    unawaited(_giftWrapSubscription?.cancel());
    _giftWrapSubscription = null;
    final subId = _subscriptionId;
    try {
      unawaited(_nostrClient.unsubscribe(subId));
    } on Object {
      // Ignore if subscription doesn't exist
    }
    _userPubkey = '';
    _signer = null;
    _messageService = null;
    _disposed = false;
    _subscriptionId = 'dm_inbox';
  }

  /// Delay before attempting to re-subscribe after stream closure.
  static const _reconnectDelay = Duration(seconds: 2);

  /// Schedule a single reconnect attempt, cancelling any pending one.
  ///
  /// Using a [Timer] (not `Future.delayed`) keeps the reconnect cancellable
  /// from [stopListening] / [_resetState], preventing leaked async work from
  /// firing after the repository has been torn down (e.g. in tests or user
  /// switch flows).
  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(_reconnectDelay, startListening);
  }

  // -------------------------------------------------------------------------
  // Subscription lifecycle
  // -------------------------------------------------------------------------

  /// Start listening for incoming gift-wrapped DMs.
  ///
  /// Subscribes to kind 1059 events p-tagged to the current user.
  /// Each received event is decrypted and persisted automatically.
  ///
  /// Uses count-based windowing to avoid replaying the full event history:
  /// - First open (no messages in DB): fetches the most recent 50 events.
  /// - Subsequent opens: fetches events since the newest synced timestamp
  ///   minus a 2-day overlap (absorbs NIP-17 randomized timestamps).
  ///
  /// If the relay stream closes unexpectedly (e.g. relay disconnect,
  /// NostrClient rebuild), automatically re-subscribes after a brief delay.
  Future<void> startListening() async {
    // Reset _disposed so that the subscription can restart after a prior
    // stopListening() call (e.g. tab switch away and back). The flag is
    // only meant to suppress the onDone reconnect during intentional stop;
    // a new explicit startListening() should always be honored.
    _disposed = false;
    // A pending reconnect is made stale by this call — cancel it so the
    // timer doesn't fire later and try to re-subscribe on top of the
    // fresh subscription we're about to establish.
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    if (_giftWrapSubscription != null || !isInitialized) return;

    // Count-based windowing: first open fetches a bounded backlog
    // (limit:50), later opens fetch only recent events via a `since:`
    // filter. The 2-day overlap absorbs NIP-17 randomized created_at
    // jitter (gift wraps tweak their outer created_at within a ~2 day
    // window). See docs/plans/2026-04-05-dm-scaling-fix-design.md.
    final newest = _syncState?.newestSyncedAt(_userPubkey);
    final isFirstOpen = newest == null;
    final filter = nostr_filter.Filter(
      kinds: [
        EventKind.giftWrap,
        EventKind.directMessage,
        EventKind.eventDeletion,
      ],
      p: [_userPubkey],
      limit: isFirstOpen ? 50 : null,
      since: isFirstOpen ? null : (newest - 2 * 86400),
    );

    Log.info(
      'Starting DM subscription for pubkey $_userPubkey '
      '(connected relays: '
      '${_nostrClient.connectedRelayCount}/'
      '${_nostrClient.configuredRelayCount}, '
      'filter: ${filter.toJson()})',
      category: LogCategory.system,
    );

    _subscriptionId = 'dm_inbox_$_userPubkey';
    final stream = _nostrClient.subscribe(
      [filter],
      subscriptionId: _subscriptionId,
    );

    _giftWrapSubscription = stream.listen(
      _handleIncomingEvent,
      onError: (Object error) {
        Log.error(
          'DM subscription error: $error',
          category: LogCategory.system,
        );
        // Cancel the failed subscription so its onDone callback never fires
        // after a later stopListening() call (which leaves _disposed false).
        // Without this, the orphaned subscription's onDone would schedule a
        // reconnect timer that leaks past the current lifecycle.
        unawaited(_giftWrapSubscription?.cancel());
        _giftWrapSubscription = null;
        if (!_disposed) {
          _scheduleReconnect();
        }
      },
      onDone: () {
        // Stream closed (relay disconnect, NostrClient rebuild, etc.)
        // Clear the subscription so startListening() can re-subscribe.
        _giftWrapSubscription = null;
        if (!_disposed) {
          Log.info(
            'DM subscription stream closed, re-subscribing '
            'in ${_reconnectDelay.inSeconds}s',
            category: LogCategory.system,
          );
          _scheduleReconnect();
        }
      },
    );

    // No poll timer: the live WebSocket subscription is the sole event
    // source for the entire authenticated session. Poller was removed
    // because it re-fetched duplicate events every 10s forever on the UI
    // isolate. See docs/plans/2026-04-05-dm-scaling-fix-design.md and #2931.
  }

  /// Fetches an older page of DM events (gift wraps, NIP-04, deletions)
  /// from the relay, bounded above by [DmSyncState.oldestSyncedAt]. The
  /// filter uses `until:` so the relay returns events *older* than the
  /// current pagination boundary, capped to 50 by `limit`.
  ///
  /// No-op if [DmSyncState] is unset or no sync has happened yet — in
  /// that case the caller should invoke [startListening] instead to
  /// establish a baseline.
  ///
  /// Events flow through [_handleIncomingEvent] so dedup, transaction
  /// integrity, and sync-boundary tracking apply automatically.
  Future<void> loadOlderMessages() async {
    if (!isInitialized) return;
    final oldest = _syncState?.oldestSyncedAt(_userPubkey);
    if (oldest == null) return;

    final filter = nostr_filter.Filter(
      kinds: [
        EventKind.giftWrap,
        EventKind.directMessage,
        EventKind.eventDeletion,
      ],
      p: [_userPubkey],
      until: oldest,
      limit: 50,
    );

    final events = await _nostrClient.queryEvents(
      [filter],
      subscriptionId: 'dm_older_${DateTime.now().millisecondsSinceEpoch}',
      useCache: false,
    );

    for (final event in events) {
      await _handleIncomingEvent(event);
    }
  }

  /// Stop listening for incoming DMs and clean up resources.
  Future<void> stopListening() async {
    // Don't set _disposed = true here — _disposed is reserved for
    // _resetState() (user switch). Setting it would make a subsequent
    // startListening() call a silent no-op, breaking re-open flows such
    // as the post-signOut cleanup in UserDataCleanupService that may be
    // followed by a fresh sign-in on the same repository instance.
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _eventLock = null;
    await _giftWrapSubscription?.cancel();
    _giftWrapSubscription = null;
    try {
      await _nostrClient.unsubscribe(_subscriptionId);
    } on Object {
      // Ignore if subscription doesn't exist
    }
  }

  // -------------------------------------------------------------------------
  // Receive pipeline
  // -------------------------------------------------------------------------

  /// Routes an incoming event to the correct handler based on kind.
  ///
  /// Serialized via [_eventLock] so that subscription events never race
  /// into the dedup/insert path concurrently.
  Future<void> _handleIncomingEvent(Event event) async {
    // Wait for any in-flight event processing to complete.
    while (_eventLock != null) {
      await _eventLock;
    }
    final completer = Completer<void>();
    _eventLock = completer.future;
    try {
      if (event.kind == EventKind.eventDeletion) {
        await _handleDeletionEvent(event);
      } else if (event.kind == EventKind.directMessage) {
        await _handleNip04Event(event);
      } else {
        await _handleGiftWrapEvent(event);
      }
    } finally {
      _eventLock = null;
      completer.complete();
    }
  }

  /// Handles an incoming NIP-09 kind 5 deletion event.
  ///
  /// For each `e` tag, validates that the event author matches the original
  /// message sender (NIP-09 requirement) before soft-deleting.
  Future<void> _handleDeletionEvent(Event deletionEvent) async {
    try {
      for (final tag in deletionEvent.tags) {
        if (tag.length < 2 || tag[0] != 'e') continue;
        final rumorId = tag[1];

        final row = await _directMessagesDao.getMessageById(
          rumorId,
          ownerPubkey: _ownerPubkey,
        );
        if (row == null) continue;

        // NIP-09: only the original author may delete.
        if (row.senderPubkey != deletionEvent.pubkey) {
          Log.debug(
            'Ignoring kind 5 for $rumorId: author mismatch '
            '(event=${deletionEvent.pubkey}, '
            'sender=${row.senderPubkey})',
            category: LogCategory.system,
          );
          continue;
        }

        if (row.isDeleted) continue; // Already processed.

        await _directMessagesDao.markMessageDeleted(
          rumorId,
          ownerPubkey: _ownerPubkey,
        );
        await _refreshConversationPreview(row.conversationId);

        Log.debug(
          'Applied kind 5 deletion for message $rumorId',
          category: LogCategory.system,
        );
      }
    } on Object catch (e, stackTrace) {
      Log.error(
        'Failed to process kind 5 event: $e',
        category: LogCategory.system,
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _handleGiftWrapEvent(Event giftWrapEvent) async {
    try {
      // Dedup: skip if already processed
      if (await _directMessagesDao.hasGiftWrap(giftWrapEvent.id)) {
        return;
      }

      // Decrypt: gift wrap → seal → rumor
      final signer = _signer;
      if (signer == null) return;
      final nostr = Nostr(signer, [], _dummyRelay);
      await nostr.refreshPublicKey();

      final rumorEvent = await _decryptRumor(nostr, giftWrapEvent);
      if (rumorEvent == null) {
        Log.debug(
          'Failed to decrypt gift wrap event ${giftWrapEvent.id}',
          category: LogCategory.system,
        );
        return;
      }

      // Accept kind 14 (text) and kind 15 (file)
      if (!_supportedDmKinds.contains(rumorEvent.kind)) return;

      // Extract conversation participants from pubkey + p tags, then
      // resolve against existing conversations to prevent duplicates
      // from non-compliant clients that add extra p-tags.
      final rawParticipants = _extractParticipants(rumorEvent);
      if (rawParticipants.length < 2) return;

      final participants = await _resolveConversationParticipants(
        rawParticipants,
        rumorEvent.pubkey,
      );

      // Reject self-conversations (all participants are the same pubkey).
      // Defense-in-depth: should not happen after the self-wrap fix above,
      // but guards against any future code path producing degenerate lists.
      if (participants.toSet().length < 2) return;

      final conversationId = computeConversationId(participants);

      // Extract common tags
      String? replyToId;
      String? subject;
      for (final tag in rumorEvent.tags) {
        if (tag.length >= 2) {
          if (tag[0] == 'e') replyToId = tag[1];
          if (tag[0] == 'subject') subject = tag[1];
        }
      }

      // Extract file metadata for kind 15
      final fileMetadata = rumorEvent.kind == EventKind.fileMessage
          ? _extractFileMetadata(rumorEvent)
          : null;

      // Cross-protocol dedup: if a NIP-04 copy of this message was
      // processed first (network reordering), skip the duplicate.
      final isDuplicate = await _directMessagesDao.hasMatchingMessage(
        conversationId: conversationId,
        senderPubkey: rumorEvent.pubkey,
        content: rumorEvent.content,
        createdAt: rumorEvent.createdAt,
        ownerPubkey: _userPubkey,
      );
      if (isDuplicate) {
        return;
      }

      // Persist message + conversation atomically inside a transaction.
      // The inner hasGiftWrap re-check guards against TOCTOU races where
      // a poll and subscription event both pass the outer fast-path check.
      final isGroup = participants.length > 2;
      final isSentByMe = rumorEvent.pubkey == _userPubkey;
      final previewContent = rumorEvent.kind == EventKind.fileMessage
          ? _filePreviewText(fileMetadata?.fileType)
          : rumorEvent.content;

      await _conversationsDao.runInTransaction(() async {
        // Re-check dedup inside transaction (TOCTOU protection).
        if (await _directMessagesDao.hasGiftWrap(giftWrapEvent.id)) return;

        await _directMessagesDao.insertMessage(
          id: rumorEvent.id,
          conversationId: conversationId,
          senderPubkey: rumorEvent.pubkey,
          content: rumorEvent.content,
          createdAt: rumorEvent.createdAt,
          giftWrapId: giftWrapEvent.id,
          messageKind: rumorEvent.kind,
          replyToId: replyToId,
          subject: subject,
          fileType: fileMetadata?.fileType,
          encryptionAlgorithm: fileMetadata?.encryptionAlgorithm,
          decryptionKey: fileMetadata?.decryptionKey,
          decryptionNonce: fileMetadata?.decryptionNonce,
          fileHash: fileMetadata?.fileHash,
          originalFileHash: fileMetadata?.originalFileHash,
          fileSize: fileMetadata?.fileSize,
          dimensions: fileMetadata?.dimensions,
          blurhash: fileMetadata?.blurhash,
          thumbnailUrl: fileMetadata?.thumbnailUrl,
          ownerPubkey: _userPubkey,
        );

        final existing = await _conversationsDao.getConversation(
          conversationId,
          ownerPubkey: _userPubkey,
        );

        await _conversationsDao.upsertConversation(
          id: conversationId,
          participantPubkeys: jsonEncode(participants),
          isGroup: isGroup,
          createdAt: existing?.createdAt ?? rumorEvent.createdAt,
          lastMessageContent: previewContent,
          lastMessageTimestamp: rumorEvent.createdAt,
          lastMessageSenderPubkey: rumorEvent.pubkey,
          subject: subject,
          isRead: isSentByMe,
          currentUserHasSent:
              isSentByMe || (existing?.currentUserHasSent ?? false),
          ownerPubkey: _userPubkey,
          dmProtocol: 'nip17',
        );
      });

      // Advance sync boundaries using the rumor's REAL created_at. The
      // outer gift wrap randomizes its own created_at within a ~2 day
      // window (NIP-17) so it must not be used for boundary tracking.
      await _syncState?.recordSeen(
        _userPubkey,
        createdAt: rumorEvent.createdAt,
      );

      Log.debug(
        'Persisted DM (kind ${rumorEvent.kind}) in conversation '
        '$conversationId',
        category: LogCategory.system,
      );
    } on Object catch (e, stackTrace) {
      Log.error(
        'Failed to process gift wrap event: $e',
        category: LogCategory.system,
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Decrypts a single gift-wrap rumor, routing through a [compute]
  /// isolate for local signers that can safely expose their private key
  /// bytes, and falling back to the injected [_rumorDecryptor] on the
  /// main isolate for remote signers (Amber, Keycast RPC, NIP-46) and
  /// test-injected decryptors.
  ///
  /// Single-element isolate batches are intentional for v1: the
  /// subscription pipeline processes gift wraps one at a time, and the
  /// goal is to keep the expensive NIP-44 crypto off the UI thread.
  /// Real backlog batching can come later.
  Future<Event?> _decryptRumor(Nostr nostr, Event giftWrapEvent) async {
    final signer = _signer;
    if (signer is IsolateDecryptSigner && signer.canDecryptInIsolate) {
      try {
        final hex = signer.withPrivateKeyHex((k) => k);
        final results = await compute(
          decryptGiftWrapBatch,
          DecryptBatchRequest(
            events: [giftWrapEvent.toJson()],
            privateKeyHex: hex,
          ),
        );
        final result = results.single;
        if (result.isSuccess) {
          return Event.fromJson(result.rumor!);
        }
        Log.debug(
          'Isolate decrypt returned failure for ${giftWrapEvent.id}: '
          '${result.error}; falling back to main-isolate decryptor',
          category: LogCategory.system,
        );
      } on Object catch (e, stackTrace) {
        Log.error(
          'Isolate decrypt threw for ${giftWrapEvent.id}: $e',
          category: LogCategory.system,
          error: e,
          stackTrace: stackTrace,
        );
        // Fall through to main-isolate decryptor.
      }
    }
    return _rumorDecryptor(nostr, giftWrapEvent);
  }

  Future<void> _handleNip04Event(Event nip04Event) async {
    try {
      // Dedup: use event ID as giftWrapId for the unique index.
      if (await _directMessagesDao.hasGiftWrap(nip04Event.id)) return;

      // Extract recipient from p tag
      String? recipientPubkey;
      for (final tag in nip04Event.tags) {
        if (tag.length >= 2 && tag[0] == 'p') {
          recipientPubkey = tag[1];
          break;
        }
      }
      if (recipientPubkey == null) return;

      // Determine sender and the other party's pubkey for decryption
      final senderPubkey = nip04Event.pubkey;
      final isSentByMe = senderPubkey == _userPubkey;
      final peerPubkey = isSentByMe ? recipientPubkey : senderPubkey;

      // Decrypt using injected decryptor or signer fallback
      final signer = _signer;
      if (signer == null && _nip04Decryptor == null) return;
      final decryptor =
          _nip04Decryptor ??
          (String pubkey, String ciphertext) =>
              signer!.decrypt(pubkey, ciphertext);
      final plaintext = await decryptor(peerPubkey, nip04Event.content);
      if (plaintext == null) {
        Log.debug(
          'Failed to decrypt NIP-04 event ${nip04Event.id}',
          category: LogCategory.system,
        );
        return;
      }

      // Build participants and conversation ID
      final participants = [senderPubkey, recipientPubkey]..sort();
      final conversationId = computeConversationId(participants);

      // Cross-protocol dedup: when a Divine user sends a message, the
      // dual-send fires both NIP-17 and NIP-04 copies. The receiver (also
      // Divine) will process the NIP-17 first, then see the NIP-04 copy.
      // Since the two events have different IDs, hasGiftWrap won't catch it.
      // Match on sender+content only (no createdAt) because the NIP-17 rumor
      // and NIP-04 event may have slightly different timestamps.
      final isDuplicate = await _directMessagesDao.hasMatchingMessage(
        conversationId: conversationId,
        senderPubkey: senderPubkey,
        content: plaintext,
        createdAt: nip04Event.createdAt,
        ownerPubkey: _userPubkey,
      );
      if (isDuplicate) {
        Log.debug(
          'Skipping NIP-04 duplicate (NIP-17 copy already stored) '
          '${nip04Event.id}',
          category: LogCategory.system,
        );
        return;
      }

      // Persist message + conversation atomically inside a transaction.
      await _conversationsDao.runInTransaction(() async {
        // Re-check dedup inside transaction (TOCTOU protection).
        if (await _directMessagesDao.hasGiftWrap(nip04Event.id)) return;

        await _directMessagesDao.insertMessage(
          id: nip04Event.id,
          conversationId: conversationId,
          senderPubkey: senderPubkey,
          content: plaintext,
          createdAt: nip04Event.createdAt,
          giftWrapId: nip04Event.id,
          messageKind: EventKind.directMessage,
          ownerPubkey: _userPubkey,
        );

        final existing = await _conversationsDao.getConversation(
          conversationId,
          ownerPubkey: _userPubkey,
        );

        await _conversationsDao.upsertConversation(
          id: conversationId,
          participantPubkeys: jsonEncode(participants),
          isGroup: false,
          createdAt: existing?.createdAt ?? nip04Event.createdAt,
          lastMessageContent: plaintext,
          lastMessageTimestamp: nip04Event.createdAt,
          lastMessageSenderPubkey: senderPubkey,
          isRead: isSentByMe,
          currentUserHasSent:
              isSentByMe || (existing?.currentUserHasSent ?? false),
          ownerPubkey: _userPubkey,
          dmProtocol: existing?.dmProtocol ?? 'nip04',
        );
      });

      // NIP-04 created_at values are not randomized (unlike NIP-17 gift
      // wraps) so the event timestamp is safe to use directly.
      await _syncState?.recordSeen(
        _userPubkey,
        createdAt: nip04Event.createdAt,
      );

      Log.debug(
        'Persisted NIP-04 DM in conversation $conversationId',
        category: LogCategory.system,
      );
    } on Object catch (e, stackTrace) {
      Log.error(
        'Failed to process NIP-04 event: $e',
        category: LogCategory.system,
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  // -------------------------------------------------------------------------
  // Send - Text (Kind 14)
  // -------------------------------------------------------------------------

  /// Send a text message to a 1:1 conversation.
  ///
  /// Throws [StateError] if the repository has not been initialized.
  /// Throws [ArgumentError] if [recipientPubkey] is not a 64-character
  /// hex string or if [content] is empty.
  Future<NIP17SendResult> sendMessage({
    required String recipientPubkey,
    required String content,
    String? replyToId,
  }) async {
    _assertInitialized();
    validatePubkey(recipientPubkey);
    if (content.trim().isEmpty) {
      throw ArgumentError.value(content, 'content', 'must not be empty');
    }

    final additionalTags = <List<String>>[
      if (replyToId != null) ['e', replyToId],
    ];

    final result = await _messageService!.sendPrivateMessage(
      recipientPubkey: recipientPubkey,
      content: content,
      additionalTags: additionalTags,
    );

    if (result.success) {
      // Persist our own sent message locally so it appears immediately
      // without waiting for a relay round-trip.
      try {
        final participants = [_userPubkey, recipientPubkey]..sort();
        final conversationId = computeConversationId(participants);
        final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

        // Persist message + conversation atomically.
        String? protocol;
        await _conversationsDao.runInTransaction(() async {
          await _directMessagesDao.insertMessage(
            id: result.rumorEventId!,
            conversationId: conversationId,
            senderPubkey: _userPubkey,
            content: content,
            createdAt: now,
            giftWrapId: result.messageEventId!,
            replyToId: replyToId,
            ownerPubkey: _userPubkey,
          );

          final existingSend = await _conversationsDao.getConversation(
            conversationId,
            ownerPubkey: _userPubkey,
          );
          protocol = existingSend?.dmProtocol;
          await _conversationsDao.upsertConversation(
            id: conversationId,
            participantPubkeys: jsonEncode(participants),
            isGroup: false,
            createdAt: existingSend?.createdAt ?? now,
            lastMessageContent: content,
            lastMessageTimestamp: now,
            lastMessageSenderPubkey: _userPubkey,
            currentUserHasSent: true,
            ownerPubkey: _userPubkey,
            dmProtocol: protocol,
          );
        });

        Log.debug(
          'Persisted sent message locally in conversation '
          '$conversationId',
          category: LogCategory.system,
        );

        // Fire NIP-04 fallback for interop with legacy clients.
        // Skip when the conversation is known to be NIP-17-only.
        if (protocol != 'nip17') {
          unawaited(
            _sendNip04Message(
              recipientPubkey: recipientPubkey,
              content: content,
            ).catchError((Object e) {
              Log.error(
                'NIP-04 fallback failed: $e',
                category: LogCategory.system,
              );
              // Reuse NIP17SendResult for simplicity
              return NIP17SendResult.failure(
                'NIP-04 fallback failed: $e',
              );
            }),
          );
        }
      } on Object catch (e, stackTrace) {
        Log.error(
          'Failed to persist sent message locally: $e',
          category: LogCategory.system,
          error: e,
          stackTrace: stackTrace,
        );
        // Don't rethrow — the message was published successfully.
        // Local persistence failure is a degraded state, not a send failure.
      }
    }

    return result;
  }

  /// Send a text message to a group conversation.
  ///
  /// Throws [StateError] if the repository has not been initialized.
  /// Throws [ArgumentError] if any pubkey in [recipientPubkeys] is not
  /// a 64-character hex string, if [content] is empty, or if
  /// [recipientPubkeys] is empty.
  Future<List<NIP17SendResult>> sendGroupMessage({
    required List<String> recipientPubkeys,
    required String content,
    String? replyToId,
  }) async {
    _assertInitialized();
    if (recipientPubkeys.isEmpty) {
      throw ArgumentError.value(
        recipientPubkeys,
        'recipientPubkeys',
        'must not be empty',
      );
    }
    recipientPubkeys.forEach(validatePubkey);
    if (content.trim().isEmpty) {
      throw ArgumentError.value(content, 'content', 'must not be empty');
    }

    final results = <NIP17SendResult>[];

    for (final pubkey in recipientPubkeys) {
      final additionalTags = <List<String>>[
        // Include all recipients as p tags per NIP-17
        for (final pk in recipientPubkeys)
          if (pk != pubkey) ['p', pk],
        if (replyToId != null) ['e', replyToId],
      ];

      final result = await _messageService!.sendPrivateMessage(
        recipientPubkey: pubkey,
        content: content,
        additionalTags: additionalTags,
      );
      results.add(result);
    }

    // If at least one send succeeded, persist locally (atomically).
    if (results.any((r) => r.success)) {
      final participants = [_userPubkey, ...recipientPubkeys]..sort();
      final conversationId = computeConversationId(participants);
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final firstSuccess = results.firstWhere((r) => r.success);

      await _conversationsDao.runInTransaction(() async {
        await _directMessagesDao.insertMessage(
          id: firstSuccess.rumorEventId!,
          conversationId: conversationId,
          senderPubkey: _userPubkey,
          content: content,
          createdAt: now,
          giftWrapId: firstSuccess.messageEventId!,
          replyToId: replyToId,
          ownerPubkey: _userPubkey,
        );

        final existingGroup = await _conversationsDao.getConversation(
          conversationId,
          ownerPubkey: _userPubkey,
        );
        await _conversationsDao.upsertConversation(
          id: conversationId,
          participantPubkeys: jsonEncode(participants),
          isGroup: true,
          createdAt: existingGroup?.createdAt ?? now,
          lastMessageContent: content,
          lastMessageTimestamp: now,
          lastMessageSenderPubkey: _userPubkey,
          currentUserHasSent: true,
          ownerPubkey: _userPubkey,
          dmProtocol: existingGroup?.dmProtocol,
        );
      });
    }

    return results;
  }

  // -------------------------------------------------------------------------
  // Delete (NIP-09 Kind 5)
  // -------------------------------------------------------------------------

  /// Delete a sent message for everyone via NIP-09 kind 5.
  ///
  /// Publishes a kind 5 event referencing the rumor event ID, then
  /// soft-deletes the local row so the gift-wrap dedup continues to work.
  ///
  /// Only the sender of [rumorId] may delete it (NIP-09 requirement).
  ///
  /// Throws [StateError] if not initialized.
  /// Throws [ArgumentError] if the message doesn't exist or the current
  /// user is not the sender.
  Future<void> deleteMessageForEveryone(String rumorId) async {
    _assertInitialized();

    final row = await _directMessagesDao.getMessageById(
      rumorId,
      ownerPubkey: _ownerPubkey,
    );
    if (row == null) {
      throw ArgumentError.value(
        rumorId,
        'rumorId',
        'message not found',
      );
    }
    if (row.senderPubkey != _userPubkey) {
      throw ArgumentError.value(
        rumorId,
        'rumorId',
        'only the sender can delete a message',
      );
    }

    // Resolve conversation participants so the kind 5 event carries `p` tags.
    // This ensures the relay subscription (filtered by `#p`) delivers the
    // deletion to the other party.
    final conversation = await _conversationsDao.getConversation(
      row.conversationId,
      ownerPubkey: _ownerPubkey,
    );
    final pTags = <List<String>>[];
    if (conversation != null) {
      final pubkeys =
          (jsonDecode(conversation.participantPubkeys) as List<dynamic>)
              .cast<String>();
      for (final pk in pubkeys) {
        if (pk != _userPubkey) {
          pTags.add(['p', pk]);
        }
      }
    }

    // Build and sign the kind 5 event (NIP-09).
    final event = Event(
      _userPubkey,
      EventKind.eventDeletion,
      [
        ['e', rumorId],
        ['k', '14'],
        ...pTags,
      ],
      '',
    );

    final signer = _signer!;
    final signed = await signer.signEvent(event);
    if (signed == null) {
      throw StateError('Failed to sign kind 5 deletion event');
    }

    // Publish to relays (best-effort — client-side processing is primary).
    await _nostrClient.publishEvent(signed);

    // Soft-delete locally so the UI updates immediately.
    await _directMessagesDao.markMessageDeleted(
      rumorId,
      ownerPubkey: _ownerPubkey,
    );

    // Update conversation preview if the deleted message was the latest.
    await _refreshConversationPreview(row.conversationId);

    Log.info(
      'Deleted message $rumorId via kind 5',
      category: LogCategory.system,
    );
  }

  /// Refreshes the conversation preview after a message is deleted.
  ///
  /// If the deleted message was the last message shown in the conversation
  /// list, the preview falls back to the next most recent non-deleted
  /// message.
  Future<void> _refreshConversationPreview(String conversationId) async {
    final remaining = await _directMessagesDao.getMessagesForConversation(
      conversationId,
      limit: 1,
      ownerPubkey: _ownerPubkey,
    );

    final conversation = await _conversationsDao.getConversation(
      conversationId,
      ownerPubkey: _ownerPubkey,
    );
    if (conversation == null) return;

    if (remaining.isEmpty) {
      // All messages deleted — clear the preview.
      await _conversationsDao.upsertConversation(
        id: conversationId,
        participantPubkeys: conversation.participantPubkeys,
        isGroup: conversation.isGroup,
        createdAt: conversation.createdAt,
        // Explicit nulls clear the previous preview after deletion.
        // ignore: avoid_redundant_argument_values, clears preview
        lastMessageContent: null,
        // ignore: avoid_redundant_argument_values, clears preview
        lastMessageTimestamp: null,
        // ignore: avoid_redundant_argument_values, clears preview
        lastMessageSenderPubkey: null,
        currentUserHasSent: conversation.currentUserHasSent,
        ownerPubkey: conversation.ownerPubkey,
        dmProtocol: conversation.dmProtocol,
      );
    } else {
      final latest = remaining.first;
      final previewContent = latest.messageKind == EventKind.fileMessage
          ? _filePreviewText(latest.fileType)
          : latest.content;

      await _conversationsDao.upsertConversation(
        id: conversationId,
        participantPubkeys: conversation.participantPubkeys,
        isGroup: conversation.isGroup,
        createdAt: conversation.createdAt,
        lastMessageContent: previewContent,
        lastMessageTimestamp: latest.createdAt,
        lastMessageSenderPubkey: latest.senderPubkey,
        currentUserHasSent: conversation.currentUserHasSent,
        ownerPubkey: conversation.ownerPubkey,
        dmProtocol: conversation.dmProtocol,
      );
    }
  }

  // -------------------------------------------------------------------------
  // Send - File (Kind 15)
  // -------------------------------------------------------------------------

  /// Send an encrypted file message to a 1:1 conversation.
  ///
  /// No NIP-04 fallback is sent for file messages because NIP-04 only
  /// supports plaintext content. File sharing requires NIP-17's kind 15
  /// with encrypted file metadata tags.
  ///
  /// The file should already be encrypted with AES-GCM and uploaded to a
  /// Blossom server. This method wraps the file URL and metadata in a
  /// Kind 15 event, then encrypts with NIP-59 gift wrapping.
  ///
  /// Throws [StateError] if the repository has not been initialized.
  /// Throws [ArgumentError] if [recipientPubkey] is invalid or required
  /// metadata is missing.
  Future<NIP17SendResult> sendFileMessage({
    required String recipientPubkey,
    required String fileUrl,
    required DmFileMetadata fileMetadata,
    String? replyToId,
  }) async {
    _assertInitialized();
    validatePubkey(recipientPubkey);
    if (fileUrl.trim().isEmpty) {
      throw ArgumentError.value(fileUrl, 'fileUrl', 'must not be empty');
    }

    final additionalTags = <List<String>>[
      ['file-type', fileMetadata.fileType],
      ['encryption-algorithm', fileMetadata.encryptionAlgorithm],
      ['decryption-key', fileMetadata.decryptionKey],
      ['decryption-nonce', fileMetadata.decryptionNonce],
      ['x', fileMetadata.fileHash],
      if (fileMetadata.originalFileHash != null)
        ['ox', fileMetadata.originalFileHash!],
      if (fileMetadata.fileSize != null)
        ['size', fileMetadata.fileSize.toString()],
      if (fileMetadata.dimensions != null) ['dim', fileMetadata.dimensions!],
      if (fileMetadata.blurhash != null) ['blurhash', fileMetadata.blurhash!],
      if (fileMetadata.thumbnailUrl != null)
        ['thumb', fileMetadata.thumbnailUrl!],
      if (replyToId != null) ['e', replyToId],
    ];

    final result = await _messageService!.sendPrivateMessage(
      recipientPubkey: recipientPubkey,
      content: fileUrl,
      eventKind: EventKind.fileMessage,
      additionalTags: additionalTags,
    );

    if (result.success) {
      final participants = [_userPubkey, recipientPubkey]..sort();
      final conversationId = computeConversationId(participants);
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      // Persist message + conversation atomically.
      await _conversationsDao.runInTransaction(() async {
        await _directMessagesDao.insertMessage(
          id: result.rumorEventId!,
          conversationId: conversationId,
          senderPubkey: _userPubkey,
          content: fileUrl,
          createdAt: now,
          giftWrapId: result.messageEventId!,
          messageKind: EventKind.fileMessage,
          replyToId: replyToId,
          fileType: fileMetadata.fileType,
          encryptionAlgorithm: fileMetadata.encryptionAlgorithm,
          decryptionKey: fileMetadata.decryptionKey,
          decryptionNonce: fileMetadata.decryptionNonce,
          fileHash: fileMetadata.fileHash,
          originalFileHash: fileMetadata.originalFileHash,
          fileSize: fileMetadata.fileSize,
          dimensions: fileMetadata.dimensions,
          blurhash: fileMetadata.blurhash,
          thumbnailUrl: fileMetadata.thumbnailUrl,
          ownerPubkey: _userPubkey,
        );

        final existingFile = await _conversationsDao.getConversation(
          conversationId,
          ownerPubkey: _userPubkey,
        );
        await _conversationsDao.upsertConversation(
          id: conversationId,
          participantPubkeys: jsonEncode(participants),
          isGroup: false,
          createdAt: existingFile?.createdAt ?? now,
          lastMessageContent: _filePreviewText(fileMetadata.fileType),
          lastMessageTimestamp: now,
          lastMessageSenderPubkey: _userPubkey,
          currentUserHasSent: true,
          ownerPubkey: _userPubkey,
          dmProtocol: existingFile?.dmProtocol,
        );
      });
    }

    return result;
  }

  // -------------------------------------------------------------------------
  // Send - NIP-04 fallback (Kind 4)
  // -------------------------------------------------------------------------

  /// Sends a NIP-04 encrypted direct message (kind 4) for legacy client
  /// interoperability.
  ///
  /// Reuses [NIP17SendResult] as the return type for simplicity — the
  /// semantics (success/failure with optional event ID) are identical.
  Future<NIP17SendResult> _sendNip04Message({
    required String recipientPubkey,
    required String content,
  }) async {
    // Reuses NIP17SendResult for simplicity — this is an internal helper.
    final signer = _signer;
    if (signer == null) {
      return NIP17SendResult.failure('Signer not available');
    }

    final ciphertext = await signer.encrypt(recipientPubkey, content);
    if (ciphertext == null) {
      return NIP17SendResult.failure('NIP-04 encrypt returned null');
    }

    final event = Event(
      _userPubkey,
      EventKind.directMessage,
      [
        ['p', recipientPubkey],
      ],
      ciphertext,
    );

    final signed = await signer.signEvent(event);
    if (signed == null) {
      return NIP17SendResult.failure('NIP-04 sign returned null');
    }

    final published = await _nostrClient.publishEvent(signed);
    if (published == null) {
      return NIP17SendResult.failure('NIP-04 publish returned null');
    }

    return NIP17SendResult.success(
      rumorEventId: published.id,
      messageEventId: published.id,
      recipientPubkey: recipientPubkey,
    );
  }

  // -------------------------------------------------------------------------
  // Query - Conversations
  // -------------------------------------------------------------------------

  /// Watch conversations (reactive stream), newest first.
  ///
  /// When [limit] is provided, only the top [limit] conversations are
  /// watched. Omit for all conversations.
  Stream<List<DmConversation>> watchConversations({int? limit}) {
    return _conversationsDao
        .watchAllConversations(limit: limit, ownerPubkey: _ownerPubkey)
        .map(
          (rows) => rows.map(_conversationFromRow).toList(),
        );
  }

  /// Get a single conversation by ID.
  ///
  /// Returns `null` if no conversation with the given ID exists.
  Future<DmConversation?> getConversation(String conversationId) async {
    final row = await _conversationsDao.getConversation(
      conversationId,
      ownerPubkey: _ownerPubkey,
    );
    return row == null ? null : _conversationFromRow(row);
  }

  /// Get all conversations.
  Future<List<DmConversation>> getConversations() async {
    final rows = await _conversationsDao.getAllConversations(
      ownerPubkey: _ownerPubkey,
    );
    return rows.map(_conversationFromRow).toList();
  }

  /// Watch conversations where the user has sent at least one message.
  ///
  /// Supports pagination via [limit]. These conversations are never
  /// message requests.
  Stream<List<DmConversation>> watchAcceptedConversations({int? limit}) {
    return _conversationsDao
        .watchAcceptedConversations(limit: limit, ownerPubkey: _ownerPubkey)
        .map((rows) => rows.map(_conversationFromRow).toList());
  }

  /// Watch conversations where the user has never sent a message.
  ///
  /// These are potential message requests. Final classification (based on
  /// follow state) is applied by [classifyPotentialRequests]. Returned
  /// without pagination since the list is typically small and needed in full.
  Stream<List<DmConversation>> watchPotentialRequests() {
    return _conversationsDao
        .watchPotentialRequestConversations(ownerPubkey: _ownerPubkey)
        .map(
          (rows) => rows.map(_conversationFromRow).toList(),
        );
  }

  /// Classifies potential request conversations by follow state.
  ///
  /// Conversations where `currentUserHasSent == false` are "potential
  /// requests". For 1:1 conversations from followed contacts, they go to
  /// the followed list (Messages tab). Everything else is a true request.
  static ({
    List<DmConversation> followed,
    List<DmConversation> requests,
  })
  classifyPotentialRequests(
    List<DmConversation> potentialRequests, {
    required String userPubkey,
    required bool Function(String) isFollowing,
  }) {
    final followed = <DmConversation>[];
    final requests = <DmConversation>[];

    for (final conversation in potentialRequests) {
      final otherPubkeys = conversation.participantPubkeys.where(
        (pk) => pk != userPubkey,
      );

      // A 1:1 conversation from a followed contact is not a request
      // even if the user hasn't replied yet. For groups, follow state
      // is irrelevant per the spec.
      final isFollowedContact =
          !conversation.isGroup && otherPubkeys.any(isFollowing);

      if (otherPubkeys.isEmpty || isFollowedContact) {
        followed.add(conversation);
      } else {
        requests.add(conversation);
      }
    }

    return (followed: followed, requests: requests);
  }

  /// Merges accepted conversations with followed-but-unreplied ones
  /// and sorts by timestamp descending.
  static List<DmConversation> mergeAndSort(
    List<DmConversation> accepted,
    List<DmConversation> followedPotential,
  ) {
    if (followedPotential.isEmpty) return accepted;
    return [...accepted, ...followedPotential]..sort((a, b) {
      return b.effectiveTimestamp.compareTo(a.effectiveTimestamp);
    });
  }

  /// Watch unread conversation count (all conversations).
  Stream<int> watchUnreadCount() {
    return _conversationsDao.watchUnreadCount(ownerPubkey: _ownerPubkey);
  }

  /// Watch unread count for accepted conversations only (excludes requests).
  Stream<int> watchUnreadAcceptedCount() {
    return _conversationsDao.watchUnreadAcceptedCount(
      ownerPubkey: _ownerPubkey,
    );
  }

  /// Mark a conversation as read.
  Future<void> markConversationAsRead(String conversationId) {
    return _conversationsDao.markAsRead(
      conversationId,
      ownerPubkey: _ownerPubkey,
    );
  }

  /// Mark multiple conversations as read in a single batch.
  ///
  /// No-op when [conversationIds] is empty.
  Future<void> markConversationsAsRead(List<String> conversationIds) {
    return _conversationsDao.markMultipleAsRead(
      conversationIds,
      ownerPubkey: _ownerPubkey,
    );
  }

  /// Remove a conversation and all its messages atomically.
  ///
  /// Deletes the messages first, then the conversation metadata
  /// inside a single database transaction.
  ///
  /// Throws:
  ///
  /// * `InvalidDataException` if a database constraint is violated.
  Future<void> removeConversation(String conversationId) {
    return _conversationsDao.runInTransaction(() async {
      await _directMessagesDao.deleteConversationMessages(
        conversationId,
        ownerPubkey: _ownerPubkey,
      );
      await _conversationsDao.deleteConversation(
        conversationId,
        ownerPubkey: _ownerPubkey,
      );
    });
  }

  /// Remove multiple conversations and all their messages atomically.
  ///
  /// No-op when [conversationIds] is empty.
  ///
  /// Throws:
  ///
  /// * `InvalidDataException` if a database constraint is violated.
  Future<void> removeConversations(List<String> conversationIds) {
    if (conversationIds.isEmpty) return Future.value();

    return _conversationsDao.runInTransaction(() async {
      await _directMessagesDao.deleteMultipleConversationMessages(
        conversationIds,
        ownerPubkey: _ownerPubkey,
      );
      await _conversationsDao.deleteMultiple(
        conversationIds,
        ownerPubkey: _ownerPubkey,
      );
    });
  }

  /// Count the total number of messages in a conversation.
  Future<int> countMessagesInConversation(String conversationId) {
    return _directMessagesDao.countMessages(
      conversationId,
      ownerPubkey: _ownerPubkey,
    );
  }

  // -------------------------------------------------------------------------
  // Query - Messages
  // -------------------------------------------------------------------------

  /// Watch messages in a conversation (reactive stream).
  Stream<List<DmMessage>> watchMessages(String conversationId) {
    return _directMessagesDao
        .watchMessagesForConversation(
          conversationId,
          ownerPubkey: _ownerPubkey,
        )
        .map((rows) => rows.map(_messageFromRow).toList());
  }

  /// Get messages in a conversation.
  Future<List<DmMessage>> getMessages(
    String conversationId, {
    int? limit,
  }) async {
    final rows = await _directMessagesDao.getMessagesForConversation(
      conversationId,
      limit: limit,
      ownerPubkey: _ownerPubkey,
    );
    return rows.map(_messageFromRow).toList();
  }

  // -------------------------------------------------------------------------
  // Helpers
  // -------------------------------------------------------------------------

  /// Merges duplicate conversations where the same 1:1 peer appears as
  /// multiple conversations due to extra p-tags in NIP-17 events.
  ///
  /// For each peer that has more than one conversation with the current user,
  /// keeps the canonical 1:1 conversation and merges the rest into it.
  /// Idempotent and safe to run on every startup.
  Future<void> _mergeDuplicateConversations() async {
    try {
      final allConversations = await _conversationsDao.getAllConversations(
        ownerPubkey: _ownerPubkey,
      );

      // Group conversations by peer pubkey to find duplicates.
      final peerGroups = <String, List<ConversationRow>>{};
      for (final conv in allConversations) {
        final participants = (jsonDecode(conv.participantPubkeys) as List)
            .cast<String>();
        final peers = participants.where((pk) => pk != _userPubkey).toList()
          ..sort();
        if (peers.isEmpty) continue;

        // Use the first peer as the grouping key.
        final peerKey = peers.first;
        peerGroups.putIfAbsent(peerKey, () => []).add(conv);
      }

      for (final entry in peerGroups.entries) {
        if (entry.value.length <= 1) continue;

        final canonical1to1Participants = [_userPubkey, entry.key]..sort();
        final canonicalId = computeConversationId(canonical1to1Participants);

        // Check if the canonical 1:1 row already exists.
        final hasCanonicalRow = entry.value.any((c) => c.id == canonicalId);

        // Merge all conversations into the canonical 1:1 ID.
        await _conversationsDao.runInTransaction(() async {
          for (final conv in entry.value) {
            if (conv.id == canonicalId) continue;

            await _directMessagesDao.reassignConversation(
              fromConversationId: conv.id,
              toConversationId: canonicalId,
              ownerPubkey: _userPubkey,
            );
            await _conversationsDao.deleteConversation(
              conv.id,
              ownerPubkey: _ownerPubkey,
            );
          }

          // If the canonical 1:1 row didn't exist, create it from the
          // most recent duplicate's metadata.
          if (!hasCanonicalRow) {
            final source = entry.value.first;
            await _conversationsDao.upsertConversation(
              id: canonicalId,
              participantPubkeys: jsonEncode(canonical1to1Participants),
              isGroup: false,
              createdAt: source.createdAt,
              lastMessageContent: source.lastMessageContent,
              lastMessageTimestamp: source.lastMessageTimestamp,
              lastMessageSenderPubkey: source.lastMessageSenderPubkey,
              currentUserHasSent: source.currentUserHasSent,
              ownerPubkey: source.ownerPubkey,
              dmProtocol: source.dmProtocol,
            );
          }
        });

        // Refresh preview from actual messages.
        await _refreshConversationPreview(canonicalId);
      }
    } on Object catch (e, stackTrace) {
      Log.error(
        'Failed to merge duplicate conversations: $e',
        category: LogCategory.system,
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Removes phantom self-conversations created by the self-wrap bug where
  /// `_resolveConversationParticipants` produced `[self, self]`.
  ///
  /// Idempotent — safe to call on every init.
  Future<void> _cleanupSelfConversations() async {
    try {
      final selfConvId = computeConversationId([_userPubkey, _userPubkey]);
      final existing = await _conversationsDao.getConversation(
        selfConvId,
        ownerPubkey: _ownerPubkey,
      );
      if (existing == null) return;

      await _conversationsDao.runInTransaction(() async {
        await _directMessagesDao.deleteConversationMessages(
          selfConvId,
          ownerPubkey: _ownerPubkey,
        );
        await _conversationsDao.deleteConversation(
          selfConvId,
          ownerPubkey: _ownerPubkey,
        );
      });

      Log.info(
        'Cleaned up phantom self-conversation',
        category: LogCategory.system,
      );
    } on Object catch (e, stackTrace) {
      Log.error(
        'Failed to clean up self-conversation: $e',
        category: LogCategory.system,
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Runs post-auth cleanup and migration tasks sequentially so each step
  /// operates on the final state of the previous one (e.g. backfill runs
  /// after merge creates canonical conversation rows).
  Future<void> _runPostAuthMaintenance() async {
    await _mergeDuplicateConversations();
    await _cleanupSelfConversations();
    await _backfillCurrentUserHasSent();
  }

  /// Backfills `currentUserHasSent` for conversations where the column
  /// was added with DEFAULT 0 but the user has actually sent messages.
  ///
  /// Fixes #2834 — without this, all pre-existing conversations appear
  /// as message requests instead of in the Messages tab.
  ///
  /// Idempotent — safe to call on every init. Becomes a no-op once all
  /// conversations are correctly flagged.
  Future<void> _backfillCurrentUserHasSent() async {
    try {
      final updated = await _conversationsDao.backfillCurrentUserHasSent(
        _userPubkey,
      );
      if (updated > 0) {
        Log.info(
          'Backfilled currentUserHasSent for $updated conversations',
          category: LogCategory.system,
        );
      }
    } on Object catch (e, stackTrace) {
      Log.error(
        'Failed to backfill currentUserHasSent: $e',
        category: LogCategory.system,
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Compute a deterministic conversation ID from sorted participant pubkeys.
  static String computeConversationId(List<String> participants) {
    final sorted = List<String>.from(participants)..sort();
    final joined = sorted.join(':');
    return sha256.convert(utf8.encode(joined)).toString();
  }

  /// The current user's public key.
  ///
  /// Returns an empty string if the repository has not been initialized.
  String get userPubkey => _userPubkey;

  void _assertInitialized() {
    if (!isInitialized) {
      throw StateError(
        'DmRepository has not been initialized. '
        'Call initialize() before sending messages.',
      );
    }
  }

  List<String> _extractParticipants(Event rumorEvent) {
    final pubkeys = <String>{rumorEvent.pubkey};
    for (final tag in rumorEvent.tags) {
      if (tag.length >= 2 && tag[0] == 'p') {
        pubkeys.add(tag[1]);
      }
    }
    return pubkeys.toList()..sort();
  }

  /// Resolves the participant list for conversation routing.
  ///
  /// When a rumor has more p-tags than a standard 1:1 (sender + us),
  /// determines whether to route to the full participant group (if one
  /// already exists) or to the canonical 1:1 pair.
  ///
  /// Priority: existing group → existing 1:1 → default to 1:1.
  ///
  /// Defaulting to 1:1 when no conversation exists prevents phantom
  /// groups caused by non-compliant clients adding extra p-tags to
  /// what should be a 1:1 DM.
  Future<List<String>> _resolveConversationParticipants(
    List<String> extractedParticipants,
    String senderPubkey,
  ) async {
    final canonical1to1 = [_userPubkey, senderPubkey]..sort();

    // Standard 1:1 message — no ambiguity.
    if (extractedParticipants.length <= 2) {
      // Self-wrap: sender is the current user, so canonical1to1 would be
      // [self, self]. Use extracted participants which contain the actual
      // recipient from the rumor's p-tags.
      if (_userPubkey == senderPubkey) return extractedParticipants;
      return canonical1to1;
    }

    // Extra p-tags present. Check if a group conversation with the
    // full participant set already exists — if so, it's a genuine group.
    final fullId = computeConversationId(extractedParticipants);
    final existingFull = await _conversationsDao.getConversation(
      fullId,
      ownerPubkey: _ownerPubkey,
    );
    if (existingFull != null) return extractedParticipants;

    // No existing group. Check if a 1:1 conversation exists.
    final canonical1to1Id = computeConversationId(canonical1to1);
    final existing1to1 = await _conversationsDao.getConversation(
      canonical1to1Id,
      ownerPubkey: _ownerPubkey,
    );
    if (existing1to1 != null) return canonical1to1;

    // Neither exists. Default to 1:1 — prevents phantom groups from
    // non-compliant clients that add extra p-tags to 1:1 DMs.
    return canonical1to1;
  }

  /// Extracts Kind 15 file metadata from event tags.
  DmFileMetadata? _extractFileMetadata(Event rumorEvent) {
    String? fileType;
    String? encryptionAlgorithm;
    String? decryptionKey;
    String? decryptionNonce;
    String? fileHash;
    String? originalFileHash;
    int? fileSize;
    String? dimensions;
    String? blurhash;
    String? thumbnailUrl;

    for (final tag in rumorEvent.tags) {
      if (tag.length < 2) continue;
      switch (tag[0]) {
        case 'file-type':
          fileType = tag[1];
        case 'encryption-algorithm':
          encryptionAlgorithm = tag[1];
        case 'decryption-key':
          decryptionKey = tag[1];
        case 'decryption-nonce':
          decryptionNonce = tag[1];
        case 'x':
          fileHash = tag[1];
        case 'ox':
          originalFileHash = tag[1];
        case 'size':
          fileSize = int.tryParse(tag[1]);
        case 'dim':
          dimensions = tag[1];
        case 'blurhash':
          blurhash = tag[1];
        case 'thumb':
          thumbnailUrl = tag[1];
      }
    }

    // Required fields per NIP-17
    if (fileType == null ||
        encryptionAlgorithm == null ||
        decryptionKey == null ||
        decryptionNonce == null ||
        fileHash == null) {
      Log.warning(
        'Kind 15 event missing required file metadata tags',
        category: LogCategory.system,
      );
      return null;
    }

    return DmFileMetadata(
      fileType: fileType,
      encryptionAlgorithm: encryptionAlgorithm,
      decryptionKey: decryptionKey,
      decryptionNonce: decryptionNonce,
      fileHash: fileHash,
      originalFileHash: originalFileHash,
      fileSize: fileSize,
      dimensions: dimensions,
      blurhash: blurhash,
      thumbnailUrl: thumbnailUrl,
    );
  }

  /// Returns a human-readable preview for file messages in conversation list.
  static String _filePreviewText(String? mimeType) {
    if (mimeType == null) return 'Sent a file';
    if (mimeType.startsWith('image/')) return 'Sent a photo';
    if (mimeType.startsWith('video/')) return 'Sent a video';
    if (mimeType.startsWith('audio/')) return 'Sent an audio message';
    return 'Sent a file';
  }

  DmConversation _conversationFromRow(ConversationRow row) {
    final pubkeys = (jsonDecode(row.participantPubkeys) as List<dynamic>)
        .cast<String>();
    return DmConversation(
      id: row.id,
      participantPubkeys: pubkeys,
      isGroup: row.isGroup,
      createdAt: row.createdAt,
      lastMessageContent: row.lastMessageContent,
      lastMessageTimestamp: row.lastMessageTimestamp,
      lastMessageSenderPubkey: row.lastMessageSenderPubkey,
      subject: row.subject,
      isRead: row.isRead,
      currentUserHasSent: row.currentUserHasSent,
      dmProtocol: row.dmProtocol,
    );
  }

  DmMessage _messageFromRow(DirectMessageRow row) {
    final DmFileMetadata? fileMetadata;
    if (row.messageKind == EventKind.fileMessage &&
        row.fileType != null &&
        row.decryptionKey != null &&
        row.decryptionNonce != null &&
        row.fileHash != null) {
      fileMetadata = DmFileMetadata(
        fileType: row.fileType!,
        encryptionAlgorithm: row.encryptionAlgorithm ?? 'aes-gcm',
        decryptionKey: row.decryptionKey!,
        decryptionNonce: row.decryptionNonce!,
        fileHash: row.fileHash!,
        originalFileHash: row.originalFileHash,
        fileSize: row.fileSize,
        dimensions: row.dimensions,
        blurhash: row.blurhash,
        thumbnailUrl: row.thumbnailUrl,
      );
    } else {
      fileMetadata = null;
    }

    return DmMessage(
      id: row.id,
      conversationId: row.conversationId,
      senderPubkey: row.senderPubkey,
      content: row.content,
      createdAt: row.createdAt,
      giftWrapId: row.giftWrapId,
      messageKind: row.messageKind,
      replyToId: row.replyToId,
      subject: row.subject,
      fileMetadata: fileMetadata,
    );
  }

  static final _hexPattern = RegExp(r'^[0-9a-fA-F]{64}$');

  /// Validates that [pubkey] is a 64-character hex string.
  ///
  /// Throws [ArgumentError] if the pubkey is invalid.
  static void validatePubkey(String pubkey) {
    if (!_hexPattern.hasMatch(pubkey)) {
      throw ArgumentError.value(
        pubkey,
        'pubkey',
        'must be a 64-character hex string',
      );
    }
  }

  Never _dummyRelay(String url) {
    throw UnimplementedError('Relay not needed for decryption');
  }
}
