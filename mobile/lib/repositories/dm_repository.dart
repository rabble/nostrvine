// ABOUTME: Repository for NIP-17 direct message management.
// ABOUTME: Handles subscribing to gift-wrapped events, decrypting messages,
// ABOUTME: persisting to the database, and providing reactive streams.
// ABOUTME: Supports both Kind 14 (text) and Kind 15 (file) messages.
// ABOUTME: Works with any NostrSigner (local keys, Keycast RPC, Amber, etc.)

import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:db_client/db_client.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/event_kind.dart';
import 'package:nostr_sdk/filter.dart' as nostr_filter;
import 'package:nostr_sdk/nip59/gift_wrap_util.dart';
import 'package:nostr_sdk/nostr.dart';
import 'package:nostr_sdk/signer/nostr_signer.dart';
import 'package:openvine/services/nip17_message_service.dart';
import 'package:openvine/utils/unified_logger.dart';

/// Decrypts a gift-wrapped event (kind 1059) through the NIP-17 layers
/// (gift wrap → seal → rumor) and returns the inner rumor event.
///
/// Returns `null` if decryption fails at any layer.
typedef RumorDecryptor = Future<Event?> Function(Nostr nostr, Event giftWrap);

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
  DmRepository({
    required NostrClient nostrClient,
    required DirectMessagesDao directMessagesDao,
    required ConversationsDao conversationsDao,
    NIP17MessageService? messageService,
    String? userPubkey,
    NostrSigner? signer,
    RumorDecryptor? rumorDecryptor,
  }) : _nostrClient = nostrClient,
       _directMessagesDao = directMessagesDao,
       _conversationsDao = conversationsDao,
       _messageService = messageService,
       _userPubkey = userPubkey ?? '',
       _signer = signer,
       _rumorDecryptor = rumorDecryptor ?? GiftWrapUtil.getRumorEvent;

  final NostrClient _nostrClient;
  final DirectMessagesDao _directMessagesDao;
  final ConversationsDao _conversationsDao;
  NIP17MessageService? _messageService;
  String _userPubkey;
  NostrSigner? _signer;
  RumorDecryptor _rumorDecryptor;

  StreamSubscription<Event>? _giftWrapSubscription;
  Timer? _pollTimer;
  bool _disposed = false;

  /// Whether a poll is currently in progress (prevents overlap).
  bool _pollInProgress = false;

  /// Whether the repository has been initialized with auth credentials.
  ///
  /// Read-only operations (watchConversations, watchMessages, etc.) work
  /// regardless of initialization. Write operations (send) and the relay
  /// subscription require initialization.
  bool get isInitialized => _signer != null && _userPubkey.isNotEmpty;

  /// Set auth credentials and start the relay subscription.
  ///
  /// Called by the provider when the user's keys become available.
  /// Read methods work before this; send/subscribe require it.
  ///
  /// Safe to call multiple times — subsequent calls for the same user are
  /// no-ops. If called with a different user, resets and re-initializes.
  void initialize({
    required String userPubkey,
    required NostrSigner signer,
    required NIP17MessageService messageService,
    RumorDecryptor? rumorDecryptor,
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
    startListening();
  }

  /// Reset internal state so the repository can be re-initialized for a
  /// different user. Stops the relay subscription and clears credentials.
  ///
  /// Synchronous so [initialize] can call it inline. Subscription cancel
  /// is fire-and-forget — the old subscription filtered by the old pubkey
  /// so any late arrivals are harmless (dedup rejects them).
  void _resetState() {
    _disposed = true;
    _pollTimer?.cancel();
    _pollTimer = null;
    unawaited(_giftWrapSubscription?.cancel());
    _giftWrapSubscription = null;
    try {
      unawaited(_nostrClient.unsubscribe('dm_inbox'));
    } on Object {
      // Ignore if subscription doesn't exist
    }
    _userPubkey = '';
    _signer = null;
    _messageService = null;
    _disposed = false;
    _pollInProgress = false;
  }

  /// Delay before attempting to re-subscribe after stream closure.
  static const _reconnectDelay = Duration(seconds: 2);

  /// Interval for polling the relay for new kind 1059 events.
  ///
  /// Some relays deliver stored events on subscription but don't push new
  /// real-time events for `#p`-filtered kind 1059 subscriptions (possibly
  /// due to AUTH requirements or relay implementation). This poll ensures
  /// messages arrive within a bounded delay regardless of relay behavior.
  static const _pollInterval = Duration(seconds: 10);

  // -------------------------------------------------------------------------
  // Subscription lifecycle
  // -------------------------------------------------------------------------

  /// Start listening for incoming gift-wrapped DMs.
  ///
  /// Subscribes to kind 1059 events p-tagged to the current user.
  /// Each received event is decrypted and persisted automatically.
  ///
  /// If the relay stream closes unexpectedly (e.g. relay disconnect,
  /// NostrClient rebuild), automatically re-subscribes after a brief delay.
  ///
  /// Also starts a periodic health check that reconnects relays when they
  /// become disconnected (e.g. from WebSocket idle timeout). This is
  /// critical on iOS where connections are dropped more aggressively.
  void startListening() {
    if (_giftWrapSubscription != null || _disposed || !isInitialized) return;

    final filter = nostr_filter.Filter(
      kinds: [EventKind.giftWrap],
      p: [_userPubkey],
    );

    Log.info(
      'Starting DM subscription for pubkey $_userPubkey '
      '(connected relays: '
      '${_nostrClient.connectedRelayCount}/'
      '${_nostrClient.configuredRelayCount}, '
      'filter: ${filter.toJson()})',
      category: LogCategory.system,
    );

    final stream = _nostrClient.subscribe(
      [filter],
      subscriptionId: 'dm_inbox',
    );

    _giftWrapSubscription = stream.listen(
      _handleGiftWrapEvent,
      onError: (Object error) {
        Log.error(
          'DM subscription error: $error',
          category: LogCategory.system,
        );
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
          Future<void>.delayed(_reconnectDelay, startListening);
        }
      },
    );

    // Start periodic polling for new events.
    // Some relays don't push real-time events for kind 1059 #p
    // subscriptions, so polling ensures messages arrive reliably.
    _startPolling();
  }

  /// Stop listening for incoming DMs and clean up resources.
  Future<void> stopListening() async {
    _disposed = true;
    _pollTimer?.cancel();
    _pollTimer = null;
    await _giftWrapSubscription?.cancel();
    _giftWrapSubscription = null;
    try {
      await _nostrClient.unsubscribe('dm_inbox');
    } on Object {
      // Ignore if subscription doesn't exist
    }
  }

  /// Periodically poll the relay for new kind 1059 events.
  ///
  /// Workaround for relays that accept subscriptions and deliver stored
  /// events but don't push new real-time events for `#p`-filtered kind 1059.
  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(_pollInterval, (_) async {
      if (_disposed || _pollInProgress) return;
      _pollInProgress = true;

      try {
        // NIP-17 gift wraps use randomized created_at (up to 2 days in the
        // past) so a `since` filter based on wall-clock time won't work.
        // Instead, fetch the most recent events and rely on dedup to skip
        // already-processed ones.
        final filter = nostr_filter.Filter(
          kinds: [EventKind.giftWrap],
          p: [_userPubkey],
          limit: 20,
        );

        final events = await _nostrClient.queryEvents(
          [filter],
          subscriptionId: 'dm_poll_${DateTime.now().millisecondsSinceEpoch}',
          useCache: false,
        );

        for (final event in events) {
          await _handleGiftWrapEvent(event);
        }
      } on Object catch (e) {
        Log.error(
          'DM poll error: $e',
          category: LogCategory.system,
        );
      } finally {
        _pollInProgress = false;
      }
    });
  }

  // -------------------------------------------------------------------------
  // Receive pipeline
  // -------------------------------------------------------------------------

  Future<void> _handleGiftWrapEvent(Event giftWrapEvent) async {
    try {
      Log.debug(
        'Received gift wrap event ${giftWrapEvent.id} '
        'from ${giftWrapEvent.pubkey}',
        category: LogCategory.system,
      );

      // Dedup: skip if already processed
      if (await _directMessagesDao.hasGiftWrap(giftWrapEvent.id)) {
        Log.debug(
          'Skipping duplicate gift wrap ${giftWrapEvent.id}',
          category: LogCategory.system,
        );
        return;
      }

      // Decrypt: gift wrap → seal → rumor
      final nostr = Nostr(_signer!, [], _dummyRelay);
      await nostr.refreshPublicKey();

      final rumorEvent = await _rumorDecryptor(nostr, giftWrapEvent);
      if (rumorEvent == null) {
        Log.debug(
          'Failed to decrypt gift wrap event ${giftWrapEvent.id}',
          category: LogCategory.system,
        );
        return;
      }

      // Accept kind 14 (text) and kind 15 (file)
      if (!_supportedDmKinds.contains(rumorEvent.kind)) return;

      // Extract conversation participants from pubkey + p tags
      final participants = _extractParticipants(rumorEvent);
      if (participants.length < 2) return;

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

      // Persist the message
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

      // Update or create the conversation
      final isGroup = participants.length > 2;
      final isSentByMe = rumorEvent.pubkey == _userPubkey;

      // For file messages, show a preview like "Sent a photo" instead of URL
      final previewContent = rumorEvent.kind == EventKind.fileMessage
          ? _filePreviewText(fileMetadata?.fileType)
          : rumorEvent.content;

      // Preserve sticky state from any existing conversation row so that
      // the full-row upsert does not clobber previous values.
      final existing = await _conversationsDao.getConversation(
        conversationId,
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
      );

      Log.debug(
        'Persisted DM (kind ${rumorEvent.kind}) in conversation '
        '$conversationId',
        category: LogCategory.system,
      );
    } catch (e, stackTrace) {
      Log.error(
        'Failed to process gift wrap event: $e',
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

        await _directMessagesDao.insertMessage(
          id: result.messageEventId!,
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
        );
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
        );

        Log.debug(
          'Persisted sent message locally in conversation '
          '$conversationId',
          category: LogCategory.system,
        );
      } catch (e, stackTrace) {
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
    for (final pk in recipientPubkeys) {
      validatePubkey(pk);
    }
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

    // If at least one send succeeded, persist locally
    if (results.any((r) => r.success)) {
      final participants = [_userPubkey, ...recipientPubkeys]..sort();
      final conversationId = computeConversationId(participants);
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final firstSuccess = results.firstWhere((r) => r.success);

      await _directMessagesDao.insertMessage(
        id: firstSuccess.messageEventId!,
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
      );
    }

    return results;
  }

  // -------------------------------------------------------------------------
  // Send - File (Kind 15)
  // -------------------------------------------------------------------------

  /// Send an encrypted file message to a 1:1 conversation.
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

      await _directMessagesDao.insertMessage(
        id: result.messageEventId!,
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
      );
    }

    return result;
  }

  // -------------------------------------------------------------------------
  // Query - Conversations
  // -------------------------------------------------------------------------

  /// Watch conversations (reactive stream), newest first.
  ///
  /// When [limit] is provided, only the top [limit] conversations are
  /// watched. Omit for all conversations.
  Stream<List<DmConversation>> watchConversations({int? limit}) {
    final pubkey = _userPubkey.isEmpty ? null : _userPubkey;
    return _conversationsDao
        .watchAllConversations(limit: limit, ownerPubkey: pubkey)
        .map(
          (rows) => rows.map(_conversationFromRow).toList(),
        );
  }

  /// Get a single conversation by ID.
  ///
  /// Returns `null` if no conversation with the given ID exists.
  Future<DmConversation?> getConversation(String conversationId) async {
    final row = await _conversationsDao.getConversation(conversationId);
    return row == null ? null : _conversationFromRow(row);
  }

  /// Get all conversations.
  Future<List<DmConversation>> getConversations() async {
    final pubkey = _userPubkey.isEmpty ? null : _userPubkey;
    final rows = await _conversationsDao.getAllConversations(
      ownerPubkey: pubkey,
    );
    return rows.map(_conversationFromRow).toList();
  }

  /// Watch conversations where the user has sent at least one message.
  ///
  /// Supports pagination via [limit]. These conversations are never
  /// message requests.
  Stream<List<DmConversation>> watchAcceptedConversations({int? limit}) {
    final pubkey = _userPubkey.isEmpty ? null : _userPubkey;
    return _conversationsDao
        .watchAcceptedConversations(limit: limit, ownerPubkey: pubkey)
        .map((rows) => rows.map(_conversationFromRow).toList());
  }

  /// Watch conversations where the user has never sent a message.
  ///
  /// These are potential message requests. Final classification (based on
  /// follow state) is applied by [classifyPotentialRequests]. Returned
  /// without pagination since the list is typically small and needed in full.
  Stream<List<DmConversation>> watchPotentialRequests() {
    final pubkey = _userPubkey.isEmpty ? null : _userPubkey;
    return _conversationsDao
        .watchPotentialRequestConversations(ownerPubkey: pubkey)
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
    final pubkey = _userPubkey.isEmpty ? null : _userPubkey;
    return _conversationsDao.watchUnreadCount(ownerPubkey: pubkey);
  }

  /// Watch unread count for accepted conversations only (excludes requests).
  Stream<int> watchUnreadAcceptedCount() {
    final pubkey = _userPubkey.isEmpty ? null : _userPubkey;
    return _conversationsDao.watchUnreadAcceptedCount(ownerPubkey: pubkey);
  }

  /// Mark a conversation as read.
  Future<void> markConversationAsRead(String conversationId) {
    return _conversationsDao.markAsRead(conversationId);
  }

  /// Mark multiple conversations as read in a single batch.
  ///
  /// No-op when [conversationIds] is empty.
  Future<void> markConversationsAsRead(List<String> conversationIds) {
    return _conversationsDao.markMultipleAsRead(conversationIds);
  }

  /// Remove a conversation and all its messages atomically.
  ///
  /// Deletes the messages first, then the conversation metadata
  /// inside a single database transaction.
  ///
  /// Throws:
  ///
  /// * [InvalidDataException] if a database constraint is violated.
  Future<void> removeConversation(String conversationId) {
    return _conversationsDao.runInTransaction(() async {
      await _directMessagesDao.deleteConversationMessages(conversationId);
      await _conversationsDao.deleteConversation(conversationId);
    });
  }

  /// Remove multiple conversations and all their messages atomically.
  ///
  /// No-op when [conversationIds] is empty.
  ///
  /// Throws:
  ///
  /// * [InvalidDataException] if a database constraint is violated.
  Future<void> removeConversations(List<String> conversationIds) {
    if (conversationIds.isEmpty) return Future.value();
    return _conversationsDao.runInTransaction(() async {
      await _directMessagesDao.deleteMultipleConversationMessages(
        conversationIds,
      );
      await _conversationsDao.deleteMultiple(conversationIds);
    });
  }

  /// Count the total number of messages in a conversation.
  Future<int> countMessagesInConversation(String conversationId) {
    final pubkey = _userPubkey.isEmpty ? null : _userPubkey;
    return _directMessagesDao.countMessages(
      conversationId,
      ownerPubkey: pubkey,
    );
  }

  // -------------------------------------------------------------------------
  // Query - Messages
  // -------------------------------------------------------------------------

  /// Watch messages in a conversation (reactive stream).
  Stream<List<DmMessage>> watchMessages(String conversationId) {
    final pubkey = _userPubkey.isEmpty ? null : _userPubkey;
    return _directMessagesDao
        .watchMessagesForConversation(
          conversationId,
          ownerPubkey: pubkey,
        )
        .map((rows) => rows.map(_messageFromRow).toList());
  }

  /// Get messages in a conversation.
  Future<List<DmMessage>> getMessages(
    String conversationId, {
    int? limit,
  }) async {
    final pubkey = _userPubkey.isEmpty ? null : _userPubkey;
    final rows = await _directMessagesDao.getMessagesForConversation(
      conversationId,
      limit: limit,
      ownerPubkey: pubkey,
    );
    return rows.map(_messageFromRow).toList();
  }

  // -------------------------------------------------------------------------
  // Helpers
  // -------------------------------------------------------------------------

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
