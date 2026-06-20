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
import 'package:dm_repository/src/collaborator_invite_recovery.dart';
import 'package:dm_repository/src/dm_decryption_worker.dart';
import 'package:dm_repository/src/dm_reactions_repository.dart';
import 'package:dm_repository/src/dm_repository_reportable_sites.dart';
import 'package:dm_repository/src/dm_shared_video_citation.dart';
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
    Future<String?> Function(String peerPubkey, String ciphertext);

/// Forwarder for DAO-bookkeeping failures inside [DmRepository].
///
/// The repository swallows these failures after [Log.error] to keep the
/// recovery primitive idempotent on doubly-degraded paths (publish
/// landed, bookkeeping write failed — see #4127). Wiring an
/// implementation routes the same signal to Crashlytics without
/// crossing the `dm_repository` → app package boundary.
///
/// [site] is one of `DmRepositoryReportableSites`'s constants and is
/// used as the Crashlytics `reason:` suffix so the dashboard aggregates
/// per swallow site.
///
/// Implementations MUST NOT throw — the repository invokes after the
/// existing `Log.error` and any throw would defeat the swallow.
typedef DmRepositoryErrorReporter =
    void Function(Object error, StackTrace stackTrace, {required String site});

/// Supported NIP-17 rumor event kinds.
const Set<int> _supportedDmKinds = {
  EventKind.privateDirectMessage, // 14
  EventKind.fileMessage, // 15
};

/// Tuning for the one-time full-history drain
/// (`DmRepository.backfillHistoryIfNeeded`).
///
/// The drain pages relays newest→oldest until the relay runs out of
/// events or [maxPages] is reached, whichever comes first. The cap is a
/// safety valve for pathological histories: because the drain walks
/// newest-first and a conversation appears as soon as *any* of its
/// messages is persisted, the most-recent [maxPages] × [pageSize] window
/// already contains the latest message of essentially every active
/// conversation.
abstract class DmHistoryDrainConfig {
  /// Events requested per relay page.
  static const int pageSize = 100;

  /// Maximum pages fetched in a single drain (≈ [pageSize] × this events).
  static const int maxPages = 50;

  /// Maximum NIP-44 decryption attempts for a single gift wrap before the
  /// failed-decrypt retry queue gives up on it. Generous so a transient
  /// remote-signer (Keycast RPC) outage spanning several inbox opens still
  /// recovers, while a permanently-undecryptable wrap cannot loop forever.
  /// See #5202.
  static const int maxDecryptRetries = 10;
}

const _relayLoopbackHosts = <String>{
  'localhost',
  '127.0.0.1',
  '10.0.2.2',
  '::1',
};

/// Compile-time gate for temporary per-conversation classification
/// diagnostics. Off by default and structurally disabled in release builds:
/// the `!kReleaseMode` term folds the constant to `false` under AOT product
/// mode, so `DM_CLASSIFY_DIAGNOSTICS` can never enable follow-graph logging
/// in a distributed build. Enable for a targeted repro on a debug/profile
/// build with `--dart-define=DM_CLASSIFY_DIAGNOSTICS=true`.
// TODO(realmeylisdev): remove DM classify diagnostics after #5374.
const bool _classifyDiagnostics =
    bool.fromEnvironment('DM_CLASSIFY_DIAGNOSTICS') && !kReleaseMode;

bool _isAllowedDmRelayUrl(String url) {
  final uri = Uri.tryParse(url.trim());
  if (uri == null || !uri.hasAuthority || uri.host.isEmpty) return false;
  if (uri.path.startsWith('//')) return false;
  final scheme = uri.scheme.toLowerCase();
  if (scheme == 'wss') return true;
  if (scheme == 'ws') {
    return _relayLoopbackHosts.contains(uri.host.toLowerCase());
  }
  return false;
}

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
  ///
  /// [errorReporter] is invoked from each DAO-bookkeeping swallow site
  /// (see [DmRepositoryErrorReporter] and `DmRepositoryReportableSites`)
  /// after the in-repo [Log.error] call. Defaults to `null` so existing
  /// test fixtures keep working without rewiring; production wires it
  /// through `dmRepositoryProvider` to forward to Crashlytics.
  DmRepository({
    required NostrClient nostrClient,
    required DirectMessagesDao directMessagesDao,
    required ConversationsDao conversationsDao,
    OutgoingDmsDao? outgoingDmsDao,
    PendingGiftWrapsDao? pendingGiftWrapsDao,
    DmSyncState? syncState,
    NIP17MessageService? messageService,
    String? userPubkey,
    NostrSigner? signer,
    RumorDecryptor? rumorDecryptor,
    Nip04Decryptor? nip04Decryptor,
    DmRepositoryErrorReporter? errorReporter,
    DmReactionsRepository? reactionsRepository,
  }) : _nostrClient = nostrClient,
       _directMessagesDao = directMessagesDao,
       _conversationsDao = conversationsDao,
       _outgoingDmsDao = outgoingDmsDao,
       _pendingGiftWrapsDao = pendingGiftWrapsDao,
       _syncState = syncState,
       _messageService = messageService,
       _userPubkey = userPubkey ?? '',
       _signer = signer,
       _rumorDecryptor = rumorDecryptor ?? GiftWrapUtil.getRumorEvent,
       _nip04Decryptor = nip04Decryptor,
       _errorReporter = errorReporter,
       _reactionsRepository = reactionsRepository;

  final NostrClient _nostrClient;
  final DirectMessagesDao _directMessagesDao;
  final ConversationsDao _conversationsDao;

  /// Optional DAO for the durable outgoing-DM queue. When provided,
  /// [sendMessage] enqueues a row before publishing so a crash mid-send
  /// leaves a recoverable trace; the retry service introduced later in
  /// the #3909 stack uses this same queue. Nullable to keep older test
  /// fixtures working without rewiring — when `null`, [sendMessage]
  /// keeps its previous direct-write behaviour.
  final OutgoingDmsDao? _outgoingDmsDao;

  /// Optional DAO for the durable failed-decrypt gift-wrap retry queue.
  /// When provided, gift wraps that fail NIP-44 decryption are persisted
  /// here (instead of being silently dropped) so [retryPendingDecryptions]
  /// can recover them on a later inbox open — the H2 resilience path for
  /// flaky remote-signer (Keycast RPC) decryption. Nullable to keep older
  /// test fixtures working without rewiring. See #5202.
  final PendingGiftWrapsDao? _pendingGiftWrapsDao;

  final DmSyncState? _syncState;
  NIP17MessageService? _messageService;
  String _userPubkey;
  NostrSigner? _signer;
  RumorDecryptor _rumorDecryptor;
  Nip04Decryptor? _nip04Decryptor;
  final DmRepositoryErrorReporter? _errorReporter;

  /// Optional sibling repository for NIP-25 reactions on DMs. When wired,
  /// [_handleGiftWrapEvent] routes kind-7 rumors to it instead of
  /// persisting them as DMs. Nullable to keep existing tests working
  /// without rewiring; production injects it via `dmRepositoryProvider`.
  final DmReactionsRepository? _reactionsRepository;

  StreamSubscription<Event>? _giftWrapSubscription;
  Timer? _reconnectTimer;
  late bool _disposed = false;

  /// Serializes event processing so concurrent subscription events
  /// never race into the dedup/insert path.
  Future<void>? _eventLock;

  /// Tracks the first post-auth cleanup pass so conversation queries can avoid
  /// emitting stale denormalized previews before repairs land.
  Future<void>? _postAuthMaintenance;

  /// The in-flight one-time history drain, shared by concurrent callers so
  /// repeated [backfillHistoryIfNeeded] calls (e.g. every inbox open) never
  /// launch overlapping drains. Cleared when the drain settles.
  Future<void>? _historyDrain;

  /// The in-flight failed-decrypt retry pass, shared by concurrent callers so
  /// repeated [retryPendingDecryptions] calls (every inbox open, plus
  /// load-more / blocklist re-dispatches) never run overlapping passes that
  /// would double the Keycast RPC decrypts or race the per-wrap attempt
  /// counter. Cleared when the pass settles. See #5202.
  Future<void>? _pendingDecryptRetry;

  /// Count of in-flight recovery operations doing real work — history-drain
  /// paging and failed-decrypt replay passes. Drives [isRecoveringHistory] /
  /// [historyRecoveryStream] so the inbox can show a restore progress
  /// indicator while a reinstall backfill runs (it can take a while on
  /// remote-signer accounts that decrypt each wrap over RPC). See #5202.
  int _activeRecoveryOps = 0;
  final StreamController<bool> _recoveryStateController =
      StreamController<bool>.broadcast();

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
    _postAuthMaintenance = _runPostAuthMaintenance();
    unawaited(_postAuthMaintenance);
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
    // Drop the in-flight history drain and decrypt-retry pass so the next
    // user can start fresh; the running loops bail on the _userPubkey change.
    _historyDrain = null;
    _pendingDecryptRetry = null;
    // Abandon the recovery signal for the outgoing user. The bailing loops'
    // _endRecovery() then no-ops (guarded on the zeroed counter).
    if (_activeRecoveryOps > 0) {
      _activeRecoveryOps = 0;
      if (!_recoveryStateController.isClosed) {
        _recoveryStateController.add(false);
      }
    }
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
    _postAuthMaintenance = null;
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
    final stream = _nostrClient.subscribe([
      filter,
    ], subscriptionId: _subscriptionId);

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

  /// Fetches a single older page of DM events (gift wraps, NIP-04,
  /// deletions) addressed to [pubkey] from the relay older than [until]
  /// (inclusive), capped to [limit]. Each event flows through
  /// [_handleIncomingEvent] so dedup, transaction integrity, and
  /// sync-boundary tracking apply automatically. Returns the raw events so
  /// the caller can advance its own pagination cursor by their outer
  /// `created_at`, or `null` if the user switched / the repository was torn
  /// down mid-fetch (so the caller stops paging for the stale user).
  Future<List<Event>?> _fetchHistoryPage({
    required int until,
    required int limit,
    required String subscriptionId,
    required String pubkey,
  }) async {
    final filter = nostr_filter.Filter(
      kinds: [
        EventKind.giftWrap,
        EventKind.directMessage,
        EventKind.eventDeletion,
      ],
      p: [pubkey],
      until: until,
      limit: limit,
    );

    final events = await _nostrClient.queryEvents(
      [filter],
      subscriptionId: subscriptionId,
      useCache: false,
    );
    if (_disposed || _userPubkey != pubkey) return null;

    for (final event in events) {
      if (_disposed || _userPubkey != pubkey) return null;
      await _handleIncomingEvent(event);
    }
    return events;
  }

  /// Recovers the user's OWN outgoing NIP-04 (kind-4) messages after a wipe.
  ///
  /// The live subscription and history drain both filter `p:[self]`, which
  /// matches incoming NIP-04 (`author=peer, p=self`) and the user's NIP-17
  /// self-wraps, but never the user's outgoing NIP-04 (`author=self,
  /// p=recipient`, per NIP-04). Without this pass a legacy conversation the
  /// user only ever replied to over NIP-04 cannot re-prove `currentUserHasSent`
  /// and is stranded under "Message requests". Pages `authors:[self]` kind-4
  /// newest→oldest and routes each through [_handleIncomingEvent], which
  /// already sets `currentUserHasSent` for self-authored messages. Bounded by
  /// [DmHistoryDrainConfig.maxPages].
  ///
  /// Returns `true` when the pass completed against a live relay — genuine
  /// exhaustion or the page budget — and `false` when it could not run: no
  /// relay connected, the repository was torn down / the user switched, or a
  /// relay error. A `false` result MUST NOT mark the drain complete, mirroring
  /// the gift-wrap drain's `connectedRelayCount == 0` guard so a momentary
  /// disconnect in this window doesn't silently skip recovery *and*
  /// permanently strand the user's outgoing NIP-04 history. See #5304.
  Future<bool> _recoverOutgoingNip04(String pubkey) async {
    try {
      var cursor = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      for (var page = 0; page < DmHistoryDrainConfig.maxPages; page++) {
        if (_disposed || _userPubkey != pubkey) return false;
        final events = await _nostrClient.queryEvents(
          [
            nostr_filter.Filter(
              authors: [pubkey],
              kinds: [EventKind.directMessage],
              until: cursor,
              limit: DmHistoryDrainConfig.pageSize,
            ),
          ],
          subscriptionId: 'dm_drain_nip04_${pubkey}_$page',
          useCache: false,
        );
        if (_disposed || _userPubkey != pubkey) return false;
        if (events.isEmpty) {
          // An empty page is genuine exhaustion only if a relay was actually
          // connected to answer it. With 0 connected relays queryEvents
          // short-circuits to [] — concluding "nothing to recover" and letting
          // the caller mark the drain complete would permanently strand the
          // user's outgoing NIP-04 (the #5202 failure mode, mirrored here).
          return _nostrClient.connectedRelayCount > 0;
        }
        for (final event in events) {
          if (_disposed || _userPubkey != pubkey) return false;
          await _handleIncomingEvent(event);
        }
        // Step strictly below the oldest event seen so the loop terminates;
        // `until` is inclusive, so a re-requested boundary is absorbed by the
        // hasGiftWrap dedup in [_handleNip04Event].
        final minCreatedAt = events
            .map((event) => event.createdAt)
            .reduce((a, b) => a < b ? a : b);
        final next = minCreatedAt < cursor ? minCreatedAt : cursor - 1;
        if (next <= 0) return true;
        cursor = next;
      }
      // Page budget exhausted. NIP-04 is legacy/low-volume and the gift-wrap
      // drain already reached the end, so treat this as done rather than
      // looping a re-drain for a pathologically long kind-4 history.
      return true;
    } on Object catch (e) {
      // Relay/IO failures are expected on flaky networks. Returning false
      // defers drain completion so recovery retries on the next inbox open
      // rather than silently skipping it and marking complete. See #5304.
      Log.warning(
        'Outgoing NIP-04 recovery did not finish for $pubkey: $e',
        category: LogCategory.system,
      );
      return false;
    }
  }

  /// Whether a DM history recovery (the backfill drain or a failed-decrypt
  /// replay) is actively doing work right now. The inbox surfaces this as a
  /// restore progress indicator so the user knows chats are still being
  /// recovered after a reinstall. See #5202.
  bool get isRecoveringHistory => _activeRecoveryOps > 0;

  /// Broadcasts changes to [isRecoveringHistory]. Does not replay the current
  /// value, so callers should seed with [isRecoveringHistory] (e.g.
  /// `historyRecoveryStream.startWith(repo.isRecoveringHistory)`). See #5202.
  Stream<bool> get historyRecoveryStream => _recoveryStateController.stream;

  /// Whether the one-time history-recovery drain has fully completed for the
  /// current user.
  ///
  /// Until this is `true` — notably the post-reinstall window while the drain
  /// pages back through history — the inbox MUST NOT segregate conversations
  /// into message requests. After a wipe a previously-accepted chat
  /// re-materializes from the peer's message before the user's own
  /// (self-wrapped) message is re-ingested, so `currentUserHasSent` is still
  /// `false` and the conversation would transiently classify as a request even
  /// though the user had replied. Gating the request split on this flag closes
  /// that window; it flips `true` (and re-fires the recovery stream via
  /// [_endRecovery]) when the drain reaches relay exhaustion. Falls back to
  /// `true` when uninitialized so the inbox never hides the split forever.
  /// See #5304.
  bool get isHistoryRecoveryComplete {
    final syncState = _syncState;
    if (syncState == null || _userPubkey.isEmpty) return true;
    return syncState.historyDrainComplete(_userPubkey);
  }

  void _beginRecovery() {
    _activeRecoveryOps++;
    if (_activeRecoveryOps == 1 && !_recoveryStateController.isClosed) {
      _recoveryStateController.add(true);
    }
  }

  void _endRecovery() {
    if (_activeRecoveryOps == 0) return;
    _activeRecoveryOps--;
    if (_activeRecoveryOps == 0 && !_recoveryStateController.isClosed) {
      _recoveryStateController.add(false);
    }
  }

  /// Recovers the user's full DM history from relays once per install.
  ///
  /// On reinstall the local DB and [DmSyncState] are wiped, so the live
  /// subscription's bounded first-open window (`limit:50`) only persists
  /// the most-recent conversations; the rest are absent from the
  /// conversation list (a pure local-DB projection) with no UI path to
  /// recover them. This drains older pages newest→oldest until the relay
  /// is exhausted (or [DmHistoryDrainConfig.maxPages] is reached),
  /// backfilling every conversation that still has events on a relay.
  /// See #4953.
  ///
  /// Idempotent and resumable: returns immediately once a clean drain has
  /// completed for the user ([DmSyncState.historyDrainComplete]); an
  /// interrupted drain resumes from the persisted boundary on the next
  /// call. Concurrent callers share one in-flight run. Runs in the
  /// background — per-event decryption already offloads to a [compute]
  /// isolate — so it is safe to fire-and-forget from the inbox BLoC on
  /// every open.
  Future<void> backfillHistoryIfNeeded() {
    final existing = _historyDrain;
    if (existing != null) return existing;
    final drain = _runHistoryDrain();
    _historyDrain = drain;
    unawaited(
      drain.whenComplete(() {
        if (identical(_historyDrain, drain)) _historyDrain = null;
      }),
    );
    return drain;
  }

  /// Replays gift wraps that previously failed NIP-44 decryption.
  ///
  /// On remote-signer accounts (Keycast RPC) each gift-wrap decrypt is a
  /// network call, so a transient failure during the history-drain burst
  /// would otherwise silently drop the conversation. Those wraps are
  /// persisted raw (see [_handleGiftWrapEvent]); this replays each back
  /// through the decrypt + persist pipeline, newest first, capped at
  /// [DmHistoryDrainConfig.maxDecryptRetries] attempts per wrap so a
  /// permanently-undecryptable wrap cannot loop forever (rows that exhaust
  /// the cap are dropped). Each replay routes through [_handleIncomingEvent]
  /// so it serializes on the same `_eventLock` as the live subscription and
  /// the drain. Concurrent callers share one in-flight pass. A no-op when no
  /// failed-decrypt DAO is wired. Safe to fire-and-forget from the inbox
  /// BLoC on every open. See #5202.
  Future<void> retryPendingDecryptions() {
    final existing = _pendingDecryptRetry;
    if (existing != null) return existing;
    final run = _runPendingDecryptRetry();
    _pendingDecryptRetry = run;
    unawaited(
      run.whenComplete(() {
        if (identical(_pendingDecryptRetry, run)) _pendingDecryptRetry = null;
      }),
    );
    return run;
  }

  Future<void> _runPendingDecryptRetry() async {
    if (!isInitialized) return;
    final dao = _pendingGiftWrapsDao;
    if (dao == null) return;
    final pubkey = _userPubkey;
    var began = false;
    try {
      // Drop wraps that exhausted the retry cap so the queue cannot grow
      // without bound — a permanently-undecryptable wrap or spammed kind-1059
      // events addressed to the user would otherwise linger forever. See #5202.
      await dao.deleteExhausted(
        ownerPubkey: pubkey,
        maxAttempts: DmHistoryDrainConfig.maxDecryptRetries,
      );
      final pending = await dao.getRetryable(
        ownerPubkey: pubkey,
        maxAttempts: DmHistoryDrainConfig.maxDecryptRetries,
      );
      if (pending.isEmpty) return;
      // Only signal "recovering" once there is genuine work, so a normal
      // inbox open (empty queue) never flickers the progress indicator.
      _beginRecovery();
      began = true;
      for (final row in pending) {
        if (_disposed || _userPubkey != pubkey) return;
        // Already recovered by the live sub / drain — clear the stale row so
        // it does not linger and re-query on every inbox open.
        if (await _directMessagesDao.hasGiftWrap(row.giftWrapId)) {
          await dao.deletePending(
            giftWrapId: row.giftWrapId,
            ownerPubkey: pubkey,
          );
          continue;
        }
        final Event giftWrapEvent;
        try {
          giftWrapEvent = Event.fromJson(
            jsonDecode(row.rawJson) as Map<String, dynamic>,
          );
        } on Object {
          // Corrupt stored JSON — drop it so it cannot loop. We wrote this
          // JSON ourselves, so a parse failure is a programming invariant.
          await dao.deletePending(
            giftWrapId: row.giftWrapId,
            ownerPubkey: pubkey,
          );
          continue;
        }
        // Re-check after the awaits above so an account switch mid-pass never
        // replays the old user's wrap under the new session.
        if (_disposed || _userPubkey != pubkey) return;
        // Route through _handleIncomingEvent so the replay serializes on the
        // same _eventLock as the live subscription and the drain. A
        // successful decrypt deletes the pending row inside
        // _handleGiftWrapEvent; a failure increments its attempts.
        await _handleIncomingEvent(giftWrapEvent);
      }
    } on Object catch (e, stackTrace) {
      // Relay/DB/IO failures here are expected (e.g. a transient read-only
      // DB) and NOT reportable; the pass resumes on the next inbox open since
      // rows are removed only on success, cap, or corruption.
      Log.error(
        'DM decrypt-retry pass failed (will resume on next inbox open): $e',
        category: LogCategory.system,
        error: e,
        stackTrace: stackTrace,
      );
    } finally {
      if (began) _endRecovery();
    }
  }

  Future<void> _runHistoryDrain() async {
    if (!isInitialized) return;
    final syncState = _syncState;
    if (syncState == null) return;
    // Pin the user for the whole drain so an account switch mid-drain can
    // never mark the wrong pubkey complete or query for the new user.
    final pubkey = _userPubkey;
    // One-time forced re-drain: installs that completed under an older,
    // buggy drain (pre-#5202) are stuck with historyDrainComplete=true while
    // the relay still holds unrecovered history. A drain-version bump clears
    // the stale flag once so recovery runs again. No-op once at the current
    // version, so it does not loop on every inbox open. See #5202.
    await syncState.upgradeDrainVersionIfNeeded(pubkey);
    if (syncState.historyDrainComplete(pubkey)) {
      Log.info(
        'DM history drain skipped for $pubkey: already complete',
        category: LogCategory.system,
      );
      return;
    }

    Log.info(
      'DM history drain starting for $pubkey '
      '(connected relays ${_nostrClient.connectedRelayCount}/'
      '${_nostrClient.configuredRelayCount})',
      category: LogCategory.system,
    );

    _beginRecovery();
    try {
      // The relay filters `until:` on the OUTER gift-wrap created_at, which
      // NIP-59 randomizes up to 2 days into the past — so the cursor tracks
      // fetched events' outer timestamps, NOT the rumor times recorded in
      // oldestSyncedAt. Resume from the persisted drain cursor when an
      // earlier run was interrupted or page-capped; otherwise seed below
      // the live subscription's discovered boundary (oldestSyncedAt); else
      // now.
      var cursor =
          syncState.historyDrainCursor(pubkey) ??
          syncState.oldestSyncedAt(pubkey) ??
          DateTime.now().millisecondsSinceEpoch ~/ 1000;

      var reachedEnd = false;
      var pagesRun = 0;
      var totalEvents = 0;
      for (var page = 0; page < DmHistoryDrainConfig.maxPages; page++) {
        // Bail if the user switched or the repository was torn down.
        if (_disposed || _userPubkey != pubkey) return;
        final events = await _fetchHistoryPage(
          until: cursor,
          limit: DmHistoryDrainConfig.pageSize,
          subscriptionId: 'dm_drain_${pubkey}_$page',
          pubkey: pubkey,
        );
        if (events == null) return;
        pagesRun++;
        totalEvents += events.length;
        if (events.isEmpty) {
          // An empty page is genuine history exhaustion ONLY if a relay was
          // actually connected to answer it. With 0 connected relays the
          // query short-circuits to [] — marking the drain complete then
          // would permanently strand unrecovered history (the #5202 root
          // cause). Defer instead: leave historyDrainComplete unset and the
          // cursor persisted so the next inbox open resumes once relays
          // are up.
          if (_nostrClient.connectedRelayCount == 0) {
            Log.warning(
              'DM history drain saw an empty page with 0 connected relays '
              'for $pubkey; deferring completion to the next inbox open.',
              category: LogCategory.system,
            );
            return;
          }
          reachedEnd = true;
          break;
        }

        // Step strictly below the oldest event seen so the loop always
        // makes progress. `until` is inclusive, so re-requesting the
        // boundary on a saturated page is absorbed by hasGiftWrap dedup
        // rather than lost.
        final minCreatedAt = events
            .map((event) => event.createdAt)
            .reduce((a, b) => a < b ? a : b);
        cursor = minCreatedAt < cursor ? minCreatedAt : cursor - 1;
        if (cursor <= 0) {
          reachedEnd = true;
          break;
        }
        // Persist the boundary so an interrupted or page-capped run
        // resumes from here on the next inbox open rather than restarting
        // from the top.
        await syncState.setHistoryDrainCursor(pubkey, cursor);
      }

      if (reachedEnd) {
        // Before declaring history complete, recover the user's OWN outgoing
        // NIP-04 messages. The paged drain above filters `p:[self]`, which
        // matches incoming NIP-04 and the user's NIP-17 self-wraps but never
        // the user's outgoing kind-4 (`author=self, p=recipient`, per NIP-04),
        // so a legacy conversation the user only ever replied to over NIP-04
        // could not re-prove `currentUserHasSent` and stayed stranded under
        // "Message requests". See #5304.
        //
        // Defer completion if this pass couldn't run against a live relay
        // (e.g. a momentary disconnect in this window) so a flaky network
        // never silently skips recovery AND marks the drain complete — it
        // resumes on the next inbox open instead.
        final nip04Recovered = await _recoverOutgoingNip04(pubkey);
        if (nip04Recovered) {
          await syncState.markHistoryDrainComplete(pubkey);
          Log.info(
            'DM history drain complete for $pubkey: '
            'pages=$pagesRun, eventsFetched=$totalEvents',
            category: LogCategory.system,
          );
        } else {
          Log.warning(
            'DM history drain reached the end for $pubkey but outgoing '
            'NIP-04 recovery could not complete (no live relay); deferring '
            'completion to the next inbox open.',
            category: LogCategory.system,
          );
        }
      } else {
        // Page cap hit: leave historyDrainComplete unset and the cursor
        // persisted so the next inbox open resumes the remaining history
        // instead of permanently truncating it for heavy users. See #4953.
        Log.warning(
          'DM history drain paused at the page cap '
          '(${DmHistoryDrainConfig.maxPages}) for $pubkey after '
          '$totalEvents events; will resume from the persisted cursor '
          '($cursor) on the next inbox open.',
          category: LogCategory.system,
        );
      }
    } on Object catch (e, stackTrace) {
      // Relay/IO failures are expected on flaky networks and are NOT
      // reportable (see error_handling.md). Leaving historyDrainComplete
      // unset lets the next inbox open resume the drain.
      Log.error(
        'DM history drain failed (will resume on next inbox open): $e',
        category: LogCategory.system,
        error: e,
        stackTrace: stackTrace,
      );
      if (e is StateError || e is TypeError || e is RangeError) {
        _errorReporter?.call(
          e,
          stackTrace,
          site: DmRepositoryReportableSites.historyDrainUnexpectedFailure,
        );
      }
    } finally {
      _endRecovery();
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
        // Persist the still-encrypted wrap so a later retry can recover the
        // conversation instead of losing it — flaky remote-signer (Keycast
        // RPC) decryption must not be permanent data loss. See #5202.
        await _pendingGiftWrapsDao?.recordFailedDecrypt(
          giftWrapId: giftWrapEvent.id,
          ownerPubkey: _userPubkey,
          rawJson: jsonEncode(giftWrapEvent.toJson()),
          createdAt: giftWrapEvent.createdAt,
        );
        Log.debug(
          'Failed to decrypt gift wrap event ${giftWrapEvent.id}; '
          'queued for retry',
          category: LogCategory.system,
        );
        return;
      }
      // Decrypt succeeded — drop any prior failed-decrypt record so the
      // retry queue stops reprocessing this wrap. See #5202.
      await _pendingGiftWrapsDao?.deletePending(
        giftWrapId: giftWrapEvent.id,
        ownerPubkey: _userPubkey,
      );

      // NIP-17 spec line 14 explicitly permits kind 7 reactions inside
      // the gift-wrap envelope. Reaction deletions are also wrapped by
      // this feature so the remove path preserves DM privacy. Route both
      // before the DM-only kinds gate below. #4633.
      if (rumorEvent.kind == EventKind.reaction) {
        await _reactionsRepository?.persistIncoming(
          rumorEvent: rumorEvent,
          giftWrapId: giftWrapEvent.id,
        );
        return;
      }
      if (rumorEvent.kind == EventKind.eventDeletion) {
        await _reactionsRepository?.handleIncomingDeletion(
          rumorEvent: rumorEvent,
          giftWrapId: giftWrapEvent.id,
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
          tagsJson: jsonEncode(rumorEvent.tags),
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

  /// Resolves [pubkey]'s NIP-17 DM inbox relays from their kind-10050
  /// "DM relays list" event.
  ///
  /// Returns the relay URLs the recipient prefers to receive gift-wrapped
  /// DMs on, or `null` when no kind-10050 event is found (NIP-17: such a
  /// user "is not ready to receive messages"). Callers route the gift
  /// wrap to these relays; a `null` result lets the caller fall back to
  /// the default relay pool so reachability is preserved for recipients
  /// who have not advertised a DM inbox. Resolution failures degrade to
  /// `null` rather than throwing, so a relay hiccup never blocks a send.
  Future<List<String>?> resolveDmInboxRelays(String pubkey) async {
    try {
      final events = await _nostrClient.queryEvents([
        nostr_filter.Filter(
          authors: [pubkey],
          kinds: [EventKind.dmRelaysList],
          limit: 1,
        ),
      ]);
      if (events.isEmpty) return null;
      // Newest wins for a replaceable event served from multiple relays.
      events.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      final relays = <String>{
        for (final tag in events.first.tags)
          if (tag.length >= 2 &&
              tag[0] == 'relay' &&
              tag[1].isNotEmpty &&
              _isAllowedDmRelayUrl(tag[1]))
            tag[1],
      };
      return relays.isEmpty ? null : relays.toList();
    } on Object catch (e) {
      Log.warning(
        'Failed to resolve DM inbox relays for $pubkey: $e',
        category: LogCategory.system,
      );
      return null;
    }
  }

  /// Send a text message to a 1:1 conversation.
  ///
  /// Throws [StateError] if the repository has not been initialized.
  /// Throws [ArgumentError] if [recipientPubkey] is not a 64-character
  /// hex string or if [content] is empty.
  ///
  /// When an [OutgoingDmsDao] is injected, the send goes through the
  /// durable queue: build the rumor, enqueue a `pending`/`pending` row
  /// keyed by the rumor's id, publish, then transition the queue row
  /// by wrap outcome:
  ///
  /// - Full NIP-17 delivery (`selfWrapPublished == true`): delete the
  ///   queue row in the same transaction that inserts `direct_messages`.
  /// - Partial delivery (`selfWrapPublished == false`): keep the row,
  ///   mark the recipient wrap `sent`, and mark the self-wrap `failed`
  ///   so only the missing self-wrap is retried later.
  /// - Recipient publish failure: mark both wraps `failed` and leave
  ///   the row queued for replay.
  Future<NIP17SendResult> sendMessage({
    required String recipientPubkey,
    required String content,
    String? replyToId,
    List<List<String>> additionalTags = const [],
    bool skipNip04Fallback = false,
  }) async {
    _assertInitialized();
    validatePubkey(recipientPubkey);
    if (content.trim().isEmpty) {
      throw ArgumentError.value(content, 'content', 'must not be empty');
    }

    final rumorTags = <List<String>>[
      ...additionalTags,
      if (replyToId != null) ['e', replyToId],
    ];
    final participants = [_userPubkey, recipientPubkey]..sort();
    final conversationId = computeConversationId(participants);

    // Build the rumor up front so the queue row PK matches the rumor id
    // the relay will see — receiver-side gift-wrap dedup keys on this id
    // and a re-mint between enqueue and publish would defeat it.
    final rumor = _messageService!.buildRumor(
      recipientPubkey: recipientPubkey,
      content: content,
      additionalTags: rumorTags,
    );

    // Enqueue before publish so an app crash mid-send leaves a
    // recoverable trace. No-op when the queue dao isn't wired in
    // (older test fixtures, NIP-04-only callers).
    final outgoingDao = _outgoingDmsDao;
    if (outgoingDao != null) {
      await outgoingDao.enqueue(
        OutgoingDm(
          id: rumor.id,
          conversationId: conversationId,
          recipientPubkey: recipientPubkey,
          content: content,
          createdAt: rumor.createdAt,
          rumorEventJson: jsonEncode(rumor.toJson()),
          messageKind: rumor.kind,
          replyToId: replyToId,
          recipientWrapStatus: OutgoingWrapStatus.pending,
          selfWrapStatus: OutgoingWrapStatus.pending,
          queuedAt: DateTime.now(),
          ownerPubkey: _userPubkey,
        ),
      );
    }

    // Route the gift wrap to the recipient's NIP-17 DM inbox relays
    // (kind 10050) when they advertise one; null falls back to the
    // default relay pool so reachability is preserved for recipients who
    // have not published a DM inbox. Resolved after the queue enqueue
    // above so the optimistic UI echo is never delayed by this lookup.
    final inboxRelays = await resolveDmInboxRelays(recipientPubkey);

    final result = await _messageService!.sendRumor(
      rumorEvent: rumor,
      recipientPubkey: recipientPubkey,
      targetRelays: inboxRelays,
    );

    if (result.success) {
      // Persist our own sent message locally so it appears immediately
      // without waiting for a relay round-trip.
      try {
        final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

        // Persist message + conversation atomically. When the queue is
        // wired in, the queue transition also lives in this transaction
        // so a watcher never observes a window where the message is in
        // neither table and so partial delivery preserves the retry row.
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
            tagsJson: rumorTags.isEmpty ? null : jsonEncode(rumorTags),
            ownerPubkey: _userPubkey,
          );

          final existingSend = await _conversationsDao.getConversation(
            conversationId,
            ownerPubkey: _userPubkey,
          );
          protocol = existingSend?.dmProtocol;
          // Mark the conversation as NIP-17 once we successfully publish
          // a NIP-17 message ourselves. Without this, `dmProtocol` only
          // ever flips when the peer sends us a NIP-17 message, so a
          // send-first conversation stayed `null` forever and every
          // subsequent send fired the NIP-04 fallback (#3663).
          final nextProtocol = protocol ?? 'nip17';
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
            dmProtocol: nextProtocol,
          );

          if (outgoingDao != null) {
            await _finalizeAfterRecipientSuccess(
              outgoingDao: outgoingDao,
              rumorId: rumor.id,
              result: result,
            );
          }
        });

        Log.debug(
          'Persisted sent message locally in conversation '
          '$conversationId',
          category: LogCategory.system,
        );

        // Fire NIP-04 fallback for interop with legacy clients. Skip
        // when the conversation is known NIP-17-only, or when the caller
        // opts out — structured DMs that cannot be represented in NIP-04
        // (e.g. collaborator invites) would degrade to a plaintext
        // duplicate.
        if (protocol != 'nip17' && !skipNip04Fallback) {
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
              return NIP17SendResult.failure('NIP-04 fallback failed: $e');
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
        _errorReporter?.call(
          e,
          stackTrace,
          site: DmRepositoryReportableSites.sendMessageOuterTransaction,
        );
        // Don't rethrow — the message was published successfully.
        // Local persistence failure is a degraded state, not a send failure.
      }
    } else if (outgoingDao != null) {
      // Recipient publish failed before the self-wrap could land, so
      // both wrap statuses remain retryable on the queue row.
      await _finalizeAfterRecipientFailure(
        outgoingDao: outgoingDao,
        rumorId: rumor.id,
        errorMessage: result.error ?? 'Unknown publish failure',
      );
    }

    return result;
  }

  /// Shares a video into a 1:1 NIP-17 DM as a kind-14 rumor that cites the
  /// video with a NIP-18 `q` tag and a NIP-21 `nostr:` URI, in addition to the
  /// human-readable [baseContent] (which keeps the `https://divine.video` URL
  /// so non-Nostr clients still render a link).
  ///
  /// [videoKind] selects the citation form — addressable (34236/34235) emits a
  /// coordinate + `naddr`; regular (22) emits an id + `nevent`. When a valid
  /// citation can't be built, falls back to a plain-text [sendMessage] so the
  /// share still goes through (the URL remains in [baseContent]).
  ///
  /// Throws the same errors as [sendMessage].
  Future<NIP17SendResult> sendSharedVideo({
    required String recipientPubkey,
    required String baseContent,
    required int videoKind,
    required String videoAuthorPubkey,
    String? videoDTag,
    String? videoEventId,
    String? relayHint,
    String? replyToId,
  }) async {
    final citation = DmSharedVideoCitation.build(
      videoKind: videoKind,
      authorPubkey: videoAuthorPubkey,
      relayHint: relayHint ?? DmShareConstants.defaultRelayHint,
      dTag: videoDTag,
      eventId: videoEventId,
    );

    if (citation == null) {
      return sendMessage(
        recipientPubkey: recipientPubkey,
        content: baseContent,
        replyToId: replyToId,
      );
    }

    return sendMessage(
      recipientPubkey: recipientPubkey,
      content: '$baseContent\n${citation.nostrUri}',
      additionalTags: [citation.qTag],
      replyToId: replyToId,
    );
  }

  /// Re-publish only the sender self-addressed gift wrap for an
  /// already-sent rumor whose recipient publish landed but whose
  /// self-wrap did not.
  ///
  /// Looks up the queue row for [rumorId] (must have been enqueued by
  /// [sendMessage] / [sendGroupMessage]), rebuilds the rumor from the
  /// stored JSON, calls [NIP17MessageService.publishSelfWrap], and
  /// transitions the queue row by outcome:
  ///
  /// - Success: delete the queue row — both wraps have now landed.
  /// - Failure: mark the self-wrap status [OutgoingWrapStatus.failed]
  ///   so the row stays retryable.
  ///
  /// Returns the underlying [NIP17SendResult] so callers can chain a
  /// per-rumor recovery and aggregate the result.
  ///
  /// Idempotent: if the row's `selfWrapStatus` is already
  /// [OutgoingWrapStatus.sent] (e.g. a concurrent recovery already
  /// landed), returns success without republishing.
  ///
  /// Throws [StateError] if the repository or its queue DAO are not
  /// wired in. Throws [ArgumentError] if no row exists for [rumorId]
  /// or the row belongs to a different account.
  Future<NIP17SendResult> recoverSelfWrap({required String rumorId}) async {
    _assertInitialized();
    final dao = _outgoingDmsDao;
    if (dao == null) {
      throw StateError(
        'recoverSelfWrap requires the outgoing_dms queue DAO; '
        'wire OutgoingDmsDao into DmRepository before calling.',
      );
    }
    final row = await dao.getById(rumorId);
    if (row == null) {
      throw ArgumentError.value(
        rumorId,
        'rumorId',
        'no queued outgoing DM with this id',
      );
    }
    if (row.ownerPubkey != _userPubkey) {
      throw ArgumentError.value(
        rumorId,
        'rumorId',
        'queue row belongs to a different account',
      );
    }

    // Idempotent re-tap. Reached when a prior recovery attempt's publish
    // already landed: either a concurrent recovery for this rumor, or
    // the previous sweep's deleteById threw and the fallback below
    // marked self_wrap_status=sent. Return success so the caller's
    // aggregation treats this rumor as done without re-publishing.
    if (row.selfWrapStatus == OutgoingWrapStatus.sent) {
      return NIP17SendResult.success(
        rumorEventId: rumorId,
        messageEventId: row.selfWrapEventId ?? rumorId,
        recipientPubkey: _userPubkey,
      );
    }

    final Event rumor;
    try {
      final json = jsonDecode(row.rumorEventJson) as Map<String, dynamic>;
      rumor = Event.fromJson(json);
    } on Object catch (e, stackTrace) {
      Log.error(
        'Failed to parse rumor JSON for $rumorId: $e',
        category: LogCategory.system,
        error: e,
        stackTrace: stackTrace,
      );
      _errorReporter?.call(
        e,
        stackTrace,
        site: DmRepositoryReportableSites.recoverSelfWrapRumorJsonParse,
      );
      // Mark the self-wrap status failed so the row surfaces in the
      // next retry sweep with a record of the parse failure.
      try {
        await dao.markSelfWrapStatus(
          id: rumorId,
          status: OutgoingWrapStatus.failed,
          lastError: 'rumor JSON parse failed: $e',
        );
      } on Object catch (markError, markStack) {
        Log.error(
          'Failed to mark self-wrap failed after JSON parse error for '
          '$rumorId: $markError',
          category: LogCategory.system,
          error: markError,
          stackTrace: markStack,
        );
        _errorReporter?.call(
          markError,
          markStack,
          site: DmRepositoryReportableSites
              .recoverSelfWrapMarkFailedAfterJsonParse,
        );
        // Swallow — caller still gets the failure result below.
      }
      return NIP17SendResult.failure('rumor JSON parse failed: $e');
    }

    final result = await _messageService!.publishSelfWrap(rumorEvent: rumor);

    if (result.success) {
      // Both wraps have landed. Mirror sendMessage's full-delivery
      // path: drop the queue row so the retry sweep stops returning it.
      try {
        await dao.deleteById(rumorId);
      } on Object catch (e, stackTrace) {
        Log.error(
          'Failed to delete outgoing_dms row $rumorId after self-wrap '
          'recovery: $e',
          category: LogCategory.system,
          error: e,
          stackTrace: stackTrace,
        );
        _errorReporter?.call(
          e,
          stackTrace,
          site: DmRepositoryReportableSites.recoverSelfWrapDeleteAfterPublish,
        );
        // Publish landed but the row is still here. Mark
        // self_wrap_status=sent with the published event id so the next
        // recovery sweep short-circuits via the idempotent guard above
        // instead of republishing the self-wrap.
        try {
          await dao.markSelfWrapStatus(
            id: rumorId,
            status: OutgoingWrapStatus.sent,
            eventId: result.messageEventId,
          );
        } on Object catch (markError, markStack) {
          Log.error(
            'Fallback markSelfWrapStatus(sent) also failed for $rumorId: '
            '$markError',
            category: LogCategory.system,
            error: markError,
            stackTrace: markStack,
          );
          _errorReporter?.call(
            markError,
            markStack,
            site: DmRepositoryReportableSites
                .recoverSelfWrapBookkeepingDoubleFailure,
          );
          // Both bookkeeping writes failed. The row stays
          // `recipient: sent / self: failed` and the next sweep
          // republishes the self-wrap. Self-wraps to the sender are
          // idempotent on receive (NIP-17 dedup keys on the rumor id),
          // so the doubly-degraded path is safe — surfaced via logs.
        }
      }
    } else {
      try {
        await dao.markSelfWrapStatus(
          id: rumorId,
          status: OutgoingWrapStatus.failed,
          lastError: result.error ?? 'self-wrap recovery failed',
        );
      } on Object catch (e, stackTrace) {
        Log.error(
          'Failed to mark outgoing_dms self-wrap failed for $rumorId: '
          '$e',
          category: LogCategory.system,
          error: e,
          stackTrace: stackTrace,
        );
        _errorReporter?.call(
          e,
          stackTrace,
          site: DmRepositoryReportableSites
              .recoverSelfWrapMarkFailedAfterPublishFailure,
        );
        // Don't rethrow — caller already gets the failure result.
      }
    }

    return result;
  }

  /// Re-publish both gift wraps for a stored rumor whose recipient
  /// publish previously failed.
  ///
  /// Used by `OutgoingDmRetryService`'s strategy-table dispatch for
  /// rows in `recipient_wrap_status == failed`. Re-publishing the
  /// rumor against a relay that already accepted the original wire
  /// copy is safe: NIP-17 receiver-side dedup keys on the rumor id
  /// (preserved verbatim via `rumor_event_json`), so the receiver sees
  /// one logical message even when the wire copy was sent twice.
  ///
  /// Looks up the queue row for [rumorId] (must have been enqueued by
  /// [sendMessage] / [sendGroupMessage]), rebuilds the rumor from the
  /// stored JSON, calls [NIP17MessageService.sendRumor], and
  /// transitions the queue row by outcome:
  ///
  /// - Full success: delete the row in the same transaction that
  ///   inserts `direct_messages`. Same atomicity contract as
  ///   [sendMessage]'s happy path.
  /// - Partial success (recipient sent, self failed): mark recipient
  ///   `sent` and self `failed` so the next sweep replays only the
  ///   missing self-wrap via [recoverSelfWrap].
  /// - Recipient failure: re-mark both wraps `failed` so the row
  ///   stays retryable.
  ///
  /// Idempotent: if the row's `recipientWrapStatus` is already
  /// [OutgoingWrapStatus.sent] (a concurrent recovery raced ahead or
  /// the row was already mid-recovery), defers to [recoverSelfWrap]
  /// so the recipient wrap is never republished.
  ///
  /// Returns the underlying [NIP17SendResult] so callers can chain a
  /// per-rumor recovery and aggregate the result.
  ///
  /// Throws [StateError] if the repository or its queue DAO are not
  /// wired in. Throws [ArgumentError] if no row exists for [rumorId]
  /// or the row belongs to a different account.
  Future<NIP17SendResult> recoverFullSend({required String rumorId}) async {
    _assertInitialized();
    final dao = _outgoingDmsDao;
    if (dao == null) {
      throw StateError(
        'recoverFullSend requires the outgoing_dms queue DAO; '
        'wire OutgoingDmsDao into DmRepository before calling.',
      );
    }
    final row = await dao.getById(rumorId);
    if (row == null) {
      throw ArgumentError.value(
        rumorId,
        'rumorId',
        'no queued outgoing DM with this id',
      );
    }
    if (row.ownerPubkey != _userPubkey) {
      throw ArgumentError.value(
        rumorId,
        'rumorId',
        'queue row belongs to a different account',
      );
    }

    // Idempotent guard: if a concurrent recovery (or the original
    // send's partial-success path) already promoted the recipient
    // wrap to sent, defer to recoverSelfWrap so the recipient wrap
    // is never republished. The two recovery primitives share the
    // same per-row state machine; this branch keeps them composable.
    if (row.recipientWrapStatus == OutgoingWrapStatus.sent) {
      return recoverSelfWrap(rumorId: rumorId);
    }

    final Event rumor;
    try {
      final json = jsonDecode(row.rumorEventJson) as Map<String, dynamic>;
      rumor = Event.fromJson(json);
    } on Object catch (e, stackTrace) {
      Log.error(
        'Failed to parse rumor JSON for $rumorId: $e',
        category: LogCategory.system,
        error: e,
        stackTrace: stackTrace,
      );
      // Mark both wraps failed with the parse error so the row stays
      // visible to the retry sweep with a record of why this attempt
      // produced no publish.
      await _finalizeAfterRecipientFailure(
        outgoingDao: dao,
        rumorId: rumorId,
        errorMessage: 'rumor JSON parse failed: $e',
      );
      return NIP17SendResult.failure('rumor JSON parse failed: $e');
    }

    final result = await _messageService!.sendRumor(
      rumorEvent: rumor,
      recipientPubkey: row.recipientPubkey,
    );

    if (result.success) {
      // Mirror sendMessage's happy-path transaction: persist
      // direct_messages + conversation upsert + queue finalize
      // atomically so a watcher never sees a window where the message
      // is in neither table, and so a partial delivery preserves the
      // retry row.
      try {
        final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        final participants = [_userPubkey, row.recipientPubkey]..sort();
        await _conversationsDao.runInTransaction(() async {
          await _directMessagesDao.insertMessage(
            id: result.rumorEventId!,
            conversationId: row.conversationId,
            senderPubkey: _userPubkey,
            content: row.content,
            createdAt: now,
            giftWrapId: result.messageEventId!,
            messageKind: row.messageKind,
            replyToId: row.replyToId,
            ownerPubkey: _userPubkey,
          );

          final existing = await _conversationsDao.getConversation(
            row.conversationId,
            ownerPubkey: _userPubkey,
          );
          // Mirror sendMessage: once we successfully publish a NIP-17
          // message ourselves, mark the conversation NIP-17 so the
          // legacy NIP-04 fallback path doesn't fire on future sends.
          final nextProtocol = existing?.dmProtocol ?? 'nip17';
          await _conversationsDao.upsertConversation(
            id: row.conversationId,
            participantPubkeys: jsonEncode(participants),
            isGroup: false,
            createdAt: existing?.createdAt ?? now,
            lastMessageContent: row.content,
            lastMessageTimestamp: now,
            lastMessageSenderPubkey: _userPubkey,
            currentUserHasSent: true,
            ownerPubkey: _userPubkey,
            dmProtocol: nextProtocol,
          );

          await _finalizeAfterRecipientSuccess(
            outgoingDao: dao,
            rumorId: rumorId,
            result: result,
          );
        });

        Log.debug(
          'Recovered full send and persisted locally in conversation '
          '${row.conversationId}',
          category: LogCategory.system,
        );
      } on Object catch (e, stackTrace) {
        Log.error(
          'Failed to persist recovered send locally for $rumorId: $e',
          category: LogCategory.system,
          error: e,
          stackTrace: stackTrace,
        );
        // Publish landed but local persistence failed — degraded
        // state. Don't rethrow: the caller still gets the success
        // result. The retry sweep will not pick this row up again
        // because the publish succeeded; missing local persistence
        // surfaces only as a sender-side gap until the self-wrap
        // arrives via the receive pipeline.
      }
    } else {
      await _finalizeAfterRecipientFailure(
        outgoingDao: dao,
        rumorId: rumorId,
        errorMessage: result.error ?? 'Unknown publish failure',
      );
    }

    return result;
  }

  /// Watches the durable outgoing DM queue for collaborator invites whose
  /// recipient delivery still needs recovery.
  ///
  /// Returns an empty stream when the queue DAO is not wired or the
  /// repository has not been scoped to an authenticated owner yet.
  Stream<List<PendingCollaboratorInviteGroup>>
  watchPendingCollaboratorInviteGroups() {
    final dao = _outgoingDmsDao;
    final ownerPubkey = _ownerPubkey;
    if (dao == null || ownerPubkey == null) {
      return Stream.value(const <PendingCollaboratorInviteGroup>[]);
    }

    return dao.watchAllForOwner(ownerPubkey).map((rows) {
      final pending = rows
          .map((row) => _tryParsePendingCollaboratorInvite(row, ownerPubkey))
          .whereType<PendingCollaboratorInvite>()
          .where((invite) => invite.requiresRecipientRecovery)
          .toList(growable: false);

      final grouped = <String, List<PendingCollaboratorInvite>>{};
      for (final invite in pending) {
        grouped.putIfAbsent(invite.videoAddress, () => []).add(invite);
      }

      final groups =
          grouped.entries
              .map((entry) {
                final invites = entry.value.toList(growable: false)
                  ..sort((a, b) => a.queuedAt.compareTo(b.queuedAt));
                final first = invites.first;
                return PendingCollaboratorInviteGroup(
                  creatorPubkey: first.creatorPubkey,
                  videoAddress: first.videoAddress,
                  title: first.title,
                  thumbnailUrl: first.thumbnailUrl,
                  relayHint: first.relayHint,
                  invites: invites,
                );
              })
              .toList(growable: false)
            ..sort(
              (a, b) =>
                  b.invites.first.queuedAt.compareTo(a.invites.first.queuedAt),
            );

      return groups;
    });
  }

  /// Retries the given queued collaborator invites by replaying their original
  /// rumors through [recoverFullSend].
  Future<CollaboratorInviteRetrySummary> retryPendingCollaboratorInvites(
    Iterable<PendingCollaboratorInvite> invites,
  ) async {
    final matchingInvites = invites
        .where((invite) => invite.requiresRecipientRecovery)
        .toList(growable: false);
    if (matchingInvites.isEmpty) {
      return const CollaboratorInviteRetrySummary(
        attemptedCount: 0,
        successCount: 0,
        failureCount: 0,
      );
    }

    var attempted = 0;
    var success = 0;
    for (final invite in matchingInvites) {
      attempted++;
      try {
        final result = await recoverFullSend(rumorId: invite.rumorId);
        if (result.success) {
          success++;
        } else {
          Log.warning(
            'Collaborator invite retry failed for rumor ${invite.rumorId} '
            '(recipient=${invite.collaboratorPubkey}, '
            'video=${invite.videoAddress}): ${result.error}',
            category: LogCategory.system,
          );
        }
      } on Object catch (error, stackTrace) {
        Log.error(
          'Collaborator invite retry threw for rumor ${invite.rumorId} '
          '(recipient=${invite.collaboratorPubkey}, '
          'video=${invite.videoAddress}): $error',
          category: LogCategory.system,
          error: error,
          stackTrace: stackTrace,
        );
        _errorReporter?.call(
          error,
          stackTrace,
          site: DmRepositoryReportableSites
              .retryPendingCollaboratorInviteUnexpectedThrow,
        );
      }
    }

    return CollaboratorInviteRetrySummary(
      attemptedCount: attempted,
      successCount: success,
      failureCount: attempted - success,
    );
  }

  /// Finds queued collaborator invites for a specific video and retries the
  /// unresolved rows whose collaborator pubkeys match [collaboratorPubkeys].
  Future<CollaboratorInviteRetrySummary>
  retryPendingCollaboratorInvitesForVideo({
    required String videoAddress,
    Iterable<String> collaboratorPubkeys = const [],
  }) async {
    final groups = await watchPendingCollaboratorInviteGroups().first;
    final targetPubkeys = collaboratorPubkeys.toSet();
    final matchingInvites = groups
        .where((group) => group.videoAddress == videoAddress)
        .expand((group) => group.invites)
        .where((invite) {
          if (targetPubkeys.isEmpty) return true;
          return targetPubkeys.contains(invite.collaboratorPubkey);
        })
        .toList(growable: false);

    return retryPendingCollaboratorInvites(matchingInvites);
  }

  /// Apply the queue-row transition for a successful per-recipient
  /// rumor publish. Shared between [sendMessage] and [sendGroupMessage]
  /// so both call sites agree on the partial-vs-full delivery
  /// bookkeeping. The caller is responsible for invoking this inside
  /// the same transaction that persists the local message row.
  Future<void> _finalizeAfterRecipientSuccess({
    required OutgoingDmsDao outgoingDao,
    required String rumorId,
    required NIP17SendResult result,
  }) async {
    if (result.selfWrapPublished == true) {
      await outgoingDao.deleteById(rumorId);
    } else {
      await outgoingDao.markRecipientWrapStatus(
        id: rumorId,
        status: OutgoingWrapStatus.sent,
        eventId: result.messageEventId,
      );
      await outgoingDao.markSelfWrapStatus(
        id: rumorId,
        status: OutgoingWrapStatus.failed,
        lastError: 'Recipient delivered, but self-wrap publish failed',
      );
    }
  }

  /// Apply the queue-row transition for a failed per-recipient rumor
  /// publish. Shared between [sendMessage] and [sendGroupMessage] so
  /// both call sites keep recipient/self wrap failure bookkeeping in
  /// lockstep.
  Future<void> _finalizeAfterRecipientFailure({
    required OutgoingDmsDao outgoingDao,
    required String rumorId,
    required String errorMessage,
  }) async {
    try {
      await outgoingDao.markRecipientWrapStatus(
        id: rumorId,
        status: OutgoingWrapStatus.failed,
        lastError: errorMessage,
      );
      await outgoingDao.markSelfWrapStatus(
        id: rumorId,
        status: OutgoingWrapStatus.failed,
        lastError: errorMessage,
      );
    } on Object catch (e, stackTrace) {
      Log.error(
        'Failed to mark outgoing_dms row failed for $rumorId: $e',
        category: LogCategory.system,
        error: e,
        stackTrace: stackTrace,
      );
      _errorReporter?.call(
        e,
        stackTrace,
        site: DmRepositoryReportableSites.finalizeAfterRecipientFailure,
      );
      // Don't rethrow — caller already gets the failure result. The
      // queue row stays retryable and the next sweep can pick it up.
    }
  }

  PendingCollaboratorInvite? _tryParsePendingCollaboratorInvite(
    OutgoingDm row,
    String ownerPubkey,
  ) {
    try {
      final json = jsonDecode(row.rumorEventJson);
      if (json is! Map<String, dynamic>) return null;
      final rumorEvent = Event.fromJson(json);
      final metadata = parseCollaboratorInviteRumor(rumorEvent);
      if (metadata == null || metadata.creatorPubkey != ownerPubkey) {
        return null;
      }

      return PendingCollaboratorInvite(
        rumorId: row.id,
        collaboratorPubkey: row.recipientPubkey,
        creatorPubkey: metadata.creatorPubkey,
        videoAddress: metadata.videoAddress,
        title: metadata.title,
        thumbnailUrl: metadata.thumbnailUrl,
        relayHint: metadata.relayHint,
        recipientWrapStatus: row.recipientWrapStatus,
        selfWrapStatus: row.selfWrapStatus,
        retryCount: row.retryCount,
        queuedAt: row.queuedAt,
        lastError: row.recipientWrapLastError ?? row.selfWrapLastError,
      );
    } on Object catch (error, stackTrace) {
      Log.warning(
        'Skipping outgoing_dms row ${row.id}; failed to parse '
        'collaborator invite rumor JSON: $error\n$stackTrace',
        category: LogCategory.system,
      );
      return null;
    }
  }

  /// Send a text message to a group conversation.
  ///
  /// Throws [StateError] if the repository has not been initialized.
  /// Throws [ArgumentError] if any pubkey in [recipientPubkeys] is not
  /// a 64-character hex string, if [content] is empty, or if
  /// [recipientPubkeys] is empty.
  ///
  /// When an [OutgoingDmsDao] is injected, each per-recipient send
  /// goes through the durable queue with the same atomicity contract
  /// as [sendMessage]: enqueue a `pending`/`pending` row keyed by the
  /// per-recipient rumor id, publish, then transition the row by wrap
  /// outcome (full delivery → row deleted in the same transaction
  /// that inserts `direct_messages`; partial delivery → recipient
  /// `sent` + self `failed` so the recovery path can replay only the
  /// missing self-wraps without re-delivering to recipients).
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

    final participants = [_userPubkey, ...recipientPubkeys]..sort();
    final conversationId = computeConversationId(participants);
    final outgoingDao = _outgoingDmsDao;

    final rumors = <Event>[];
    final results = <NIP17SendResult>[];

    for (final pubkey in recipientPubkeys) {
      final additionalTags = <List<String>>[
        // Include all recipients as p tags per NIP-17
        for (final pk in recipientPubkeys)
          if (pk != pubkey) ['p', pk],
        if (replyToId != null) ['e', replyToId],
      ];

      // Build the rumor up front so the queue row PK matches the rumor
      // id the relay will see (each recipient gets a distinct rumor —
      // their p-tag set differs — so queue rows never collide across
      // a single group send).
      final rumor = _messageService!.buildRumor(
        recipientPubkey: pubkey,
        content: content,
        additionalTags: additionalTags,
      );

      // Enqueue before publish so an app crash mid-send leaves a
      // recoverable trace per recipient. Same contract as sendMessage:
      // no-op when the queue dao isn't wired in (older test fixtures,
      // NIP-04-only callers).
      if (outgoingDao != null) {
        await outgoingDao.enqueue(
          OutgoingDm(
            id: rumor.id,
            conversationId: conversationId,
            recipientPubkey: pubkey,
            content: content,
            createdAt: rumor.createdAt,
            rumorEventJson: jsonEncode(rumor.toJson()),
            messageKind: rumor.kind,
            replyToId: replyToId,
            recipientWrapStatus: OutgoingWrapStatus.pending,
            selfWrapStatus: OutgoingWrapStatus.pending,
            queuedAt: DateTime.now(),
            ownerPubkey: _userPubkey,
          ),
        );
      }

      final result = await _messageService!.sendRumor(
        rumorEvent: rumor,
        recipientPubkey: pubkey,
      );
      rumors.add(rumor);
      results.add(result);
    }

    // If at least one send succeeded, persist locally (atomically). The
    // per-recipient queue updates for successful tuples ride inside the
    // same transaction so a watcher never observes a window where the
    // message is in neither table — and partial deliveries preserve
    // the retry row for the recovery path.
    if (results.any((r) => r.success)) {
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final firstSuccess = results.firstWhere((r) => r.success);
      final localTags = <List<String>>[
        for (final pk in recipientPubkeys) ['p', pk],
        if (replyToId != null) ['e', replyToId],
      ];

      await _conversationsDao.runInTransaction(() async {
        await _directMessagesDao.insertMessage(
          id: firstSuccess.rumorEventId!,
          conversationId: conversationId,
          senderPubkey: _userPubkey,
          content: content,
          createdAt: now,
          giftWrapId: firstSuccess.messageEventId!,
          replyToId: replyToId,
          tagsJson: localTags.isEmpty ? null : jsonEncode(localTags),
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

        if (outgoingDao != null) {
          for (var i = 0; i < rumors.length; i++) {
            final result = results[i];
            if (!result.success) continue;
            await _finalizeAfterRecipientSuccess(
              outgoingDao: outgoingDao,
              rumorId: rumors[i].id,
              result: result,
            );
          }
        }
      });
    }

    // Recipient publish failures: mark both wraps failed so the row
    // stays retryable. Lives outside the success-transaction, mirroring
    // sendMessage's split: a recipient-failed tuple has nothing to
    // atomically tie the queue update to (no message row insert).
    if (outgoingDao != null) {
      for (var i = 0; i < rumors.length; i++) {
        final result = results[i];
        if (result.success) continue;
        await _finalizeAfterRecipientFailure(
          outgoingDao: outgoingDao,
          rumorId: rumors[i].id,
          errorMessage: result.error ?? 'Unknown publish failure',
        );
      }
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
      throw ArgumentError.value(rumorId, 'rumorId', 'message not found');
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
    final event = Event(_userPubkey, EventKind.eventDeletion, [
      ['e', rumorId],
      ['k', '14'],
      ...pTags,
    ], '');

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
      // All messages deleted — clear the preview. Force the update so the
      // conditional timestamp check in upsertConversation does not block
      // a null timestamp from overwriting the existing value.
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
        forceUpdateLastMessage: true,
      );
    } else {
      final latest = remaining.first;
      final previewContent = latest.messageKind == EventKind.fileMessage
          ? _filePreviewText(latest.fileType)
          : latest.content;

      // Force the update: after a deletion the replacement message is the
      // newest *remaining* one, but its timestamp may be older than the
      // deleted message that was previously shown.
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
        forceUpdateLastMessage: true,
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
          tagsJson: jsonEncode(additionalTags),
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
      return const NIP17SendResult.failure('Signer not available');
    }

    final ciphertext = await signer.encrypt(recipientPubkey, content);
    if (ciphertext == null) {
      return const NIP17SendResult.failure('NIP-04 encrypt returned null');
    }

    final event = Event(_userPubkey, EventKind.directMessage, [
      ['p', recipientPubkey],
    ], ciphertext);

    final signed = await signer.signEvent(event);
    if (signed == null) {
      return const NIP17SendResult.failure('NIP-04 sign returned null');
    }

    final publishResult = await _nostrClient.publishEvent(signed);
    final failureReason = publishResult.failureReason;
    if (failureReason != null) {
      Log.error(
        'Failed to publish NIP-04 message: $failureReason',
        category: LogCategory.system,
      );
      return const NIP17SendResult.failure('NIP-04 publish failed');
    }

    final sent = publishResult as PublishSuccess;
    return NIP17SendResult.success(
      rumorEventId: sent.event.id,
      messageEventId: sent.event.id,
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
    return _watchConversationRows(
      () => _conversationsDao.watchAllConversations(
        limit: limit,
        ownerPubkey: _ownerPubkey,
      ),
    );
  }

  /// Get a single conversation by ID.
  ///
  /// Returns `null` if no conversation with the given ID exists.
  Future<DmConversation?> getConversation(String conversationId) async {
    await _awaitInitialConversationMaintenance();
    final row = await _conversationsDao.getConversation(
      conversationId,
      ownerPubkey: _ownerPubkey,
    );
    return row == null ? null : _conversationFromRow(row);
  }

  /// Get all conversations.
  Future<List<DmConversation>> getConversations() async {
    await _awaitInitialConversationMaintenance();
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
    return _watchConversationRows(
      () => _conversationsDao.watchAcceptedConversations(
        limit: limit,
        ownerPubkey: _ownerPubkey,
      ),
    );
  }

  /// Watch conversations where the user has never sent a message.
  ///
  /// These are potential message requests. Final classification (based on
  /// follow state) is applied by [classifyPotentialRequests]. Returned
  /// without pagination since the list is typically small and needed in full.
  Stream<List<DmConversation>> watchPotentialRequests() {
    return _watchConversationRows(
      () => _conversationsDao.watchPotentialRequestConversations(
        ownerPubkey: _ownerPubkey,
      ),
    );
  }

  /// Classifies potential request conversations by follow state.
  ///
  /// Conversations where `currentUserHasSent == false` are "potential
  /// requests". A 1:1 conversation from a followed contact goes to the
  /// followed list (Messages tab); everything else is a true request.
  ///
  /// 1:1-ness is derived from the deduplicated non-self participant count,
  /// NOT the denormalized `DmConversation.isGroup` flag. That column is
  /// written from `participants.length > 2` and overwritten on every
  /// upsert, so it can drift from a row's real participants — which was
  /// stranding followed 1:1 peers under "Message requests" (#5374). Groups
  /// (2+ non-self participants) are always requests here, independent of
  /// follow state.
  static ({List<DmConversation> followed, List<DmConversation> requests})
  classifyPotentialRequests(
    List<DmConversation> potentialRequests, {
    required String userPubkey,
    required bool Function(String) isFollowing,
  }) {
    final followed = <DmConversation>[];
    final requests = <DmConversation>[];

    for (final conversation in potentialRequests) {
      final otherPubkeys = conversation.participantPubkeys
          .where((pk) => pk != userPubkey)
          .toSet();

      // A 1:1 conversation from a followed contact is not a request even
      // if the user hasn't replied yet. Derive 1:1-ness from the actual
      // (deduplicated) non-self participant count rather than the stored
      // `isGroup` flag, which can drift from the row's real participants and
      // mis-route followed 1:1 peers to requests (#5374).
      final isOneToOne = otherPubkeys.length == 1;
      final isFollowedContact = isOneToOne && otherPubkeys.any(isFollowing);

      if (otherPubkeys.isEmpty || isFollowedContact) {
        followed.add(conversation);
      } else {
        if (_classifyDiagnostics) {
          final follows = otherPubkeys
              .map((pk) => '$pk:${isFollowing(pk)}')
              .join(', ');
          Log.debug(
            'classifyPotentialRequests → request: '
            'conversationId=${conversation.id} '
            'isGroup=${conversation.isGroup} '
            'participantCount=${conversation.participantPubkeys.length} '
            'otherPubkeys=$otherPubkeys follows={$follows}',
            category: LogCategory.system,
          );
        }
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
        .watchMessagesForConversation(conversationId, ownerPubkey: _ownerPubkey)
        .map((rows) => rows.map(_messageFromRow).toList());
  }

  /// Watch the durable `outgoing_dms` queue rows for [conversationId],
  /// scoped to the active owner. Empty stream when no row is queued or
  /// when no [OutgoingDmsDao] is wired (legacy test fixtures).
  ///
  /// Pair with [watchMessages] in the conversation bloc to render in-flight,
  /// partial-delivery, and recipient-failed bubbles alongside the
  /// persisted timeline. [sendMessage] enqueues a row before any signer
  /// round-trip, so the first tick of this stream lands within
  /// microseconds of dispatch — replacing the in-memory
  /// `pendingOptimistic` slice introduced for #4193.
  Stream<List<OutgoingDm>> watchOutgoing(String conversationId) {
    final dao = _outgoingDmsDao;
    final owner = _ownerPubkey;
    // Signed-out / not-yet-ready states leave the queue invisible to
    // the bloc — there is no owner to scope the rows to. The next
    // auth flip recreates the bloc (BlocProvider keyed on repo
    // identity) and the subscription starts fresh.
    if (dao == null || owner == null) {
      return Stream<List<OutgoingDm>>.value(const []);
    }
    return dao.watchForConversation(
      conversationId: conversationId,
      ownerPubkey: owner,
    );
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

  Future<void> _awaitInitialConversationMaintenance() async {
    await _postAuthMaintenance;
  }

  Stream<List<DmConversation>> _watchConversationRows(
    Stream<List<ConversationRow>> Function() watchRows,
  ) {
    final maintenance = _postAuthMaintenance;
    final gatedRows = maintenance == null
        ? watchRows()
        : Stream.fromFuture(maintenance).asyncExpand((_) => watchRows());
    return gatedRows.map((streamRows) {
      return streamRows.map(_conversationFromRow).toList();
    });
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
    await _backfillConversationPreviews();
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

  /// Backfills denormalized latest-message preview columns in conversations.
  ///
  /// Fixes stale previews created before the write-path timestamp guard landed,
  /// after which conversation rows become the source of truth again.
  Future<void> _backfillConversationPreviews() async {
    try {
      final updated = await _conversationsDao.backfillLatestMessagePreviews(
        ownerPubkey: _ownerPubkey,
      );
      if (updated > 0) {
        Log.info(
          'Backfilled latest message previews for $updated conversations',
          category: LogCategory.system,
        );
      }
    } on Object catch (e, stackTrace) {
      Log.error(
        'Failed to backfill latest message previews: $e',
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

    final tags = _parseTagsJson(row.tagsJson);
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
      tags: tags,
      fileMetadata: fileMetadata,
      sharedVideoRef: DmSharedVideoCitation.parse(tags),
    );
  }

  List<List<String>> _parseTagsJson(String? tagsJson) {
    if (tagsJson == null || tagsJson.isEmpty) return const [];
    try {
      final decoded = jsonDecode(tagsJson);
      if (decoded is! List) return const [];
      final tags = <List<String>>[];
      for (final tag in decoded) {
        if (tag is! List) continue;
        tags.add(tag.whereType<String>().toList());
      }
      return tags;
    } on FormatException {
      return const [];
    }
  }

  /// Validates that [pubkey] is a 64-character hex string.
  ///
  /// Throws [ArgumentError] if the pubkey is invalid.
  static void validatePubkey(String pubkey) {
    if (!NostrHexUtils.isValidPubkey(pubkey)) {
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
