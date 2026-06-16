// ABOUTME: Service for publishing videos directly to Nostr without backend processing
// ABOUTME: Handles event creation, signing, and relay broadcasting for direct uploads

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:blossom_upload_service/blossom_upload_service.dart';
import 'package:blurhash_service/blurhash_service.dart';
import 'package:crypto/crypto.dart';
//adding c2pa support for publishing c2pa manifest data into nostr
import 'package:db_client/db_client.dart' hide Filter;
import 'package:meta/meta.dart';
import 'package:models/models.dart'
    hide LogCategory, NIP71VideoKinds, PendingUpload, UploadStatus;
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/event_kind.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:nostr_sdk/relay/publish_outcome.dart';
import 'package:nostr_sdk/relay/relay_pool.dart';
import 'package:openvine/constants/nip71_migration.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/models/pending_upload.dart';
import 'package:openvine/models/video_reply_context.dart';
import 'package:openvine/services/audio_extraction_service.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/c2pa_signing_service.dart';
import 'package:openvine/services/event_api_client.dart';
import 'package:openvine/services/personal_event_cache_service.dart';
import 'package:openvine/services/saved_sounds_service.dart';
import 'package:openvine/services/upload_manager.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:openvine/services/video_thumbnail_service.dart';
import 'package:openvine/utils/collaborator_tags.dart';
import 'package:openvine/utils/log_tag_sanitizer.dart';
import 'package:openvine/utils/proofmode_publishing_helpers.dart';
import 'package:profile_repository/profile_repository.dart';
import 'package:unified_logger/unified_logger.dart';

part '../internal/video_event_publisher_audio.dart';

/// Floor for the derived outer publish timeout. Covers empty-config /
/// pre-init races where `configuredRelayCount` reads as `0` but the
/// publish would still queue against a tempRelay or wait on
/// initialisation. Also keeps the timeout from collapsing to the buffer
/// alone for `relayCount == 1`, which would leave no slack for normal
/// network latency.
const Duration _outerPublishTimeoutFloor = Duration(seconds: 10);

/// Ceiling for the derived outer publish timeout. Bounds worst-case
/// user-visible publish latency on misconfigured huge relay lists so a
/// user with 50 wedged relays does not wait several minutes for the
/// publish to give up.
///
/// **Trade-off**: clamping to the ceiling means the strict invariant
/// `outer >= inner_worst_case + buffer` only holds while
/// `derived <= ceiling`. Beyond that boundary (currently
/// `relayCount >= 12` with `perRelaySendTimeout = 5s` and `buffer = 5s`)
/// the buffer evaporates; from `relayCount == 13` upward the outer
/// guard can fire before the inner sequential fan-out completes,
/// re-introducing the original false-negative-publish failure mode for
/// that edge case. We accept this because the field worst case is
/// driven by `connecting`-state waits and post-handshake socket
/// wedges — not all configured relays — so practical fan-out times for
/// any reasonable config stay well under the ceiling. The retry loop in
/// [VideoEventPublisher.publishDirectUpload] absorbs the rare
/// false-negative when it does happen.
const Duration _outerPublishTimeoutCeiling = Duration(seconds: 60);

/// Buffer added on top of the per-relay × count derivation. Covers the
/// microtask queue drains between sequential `relay.send` calls inside
/// [RelayPool._sendCollect], plus a small allowance for log formatting
/// and other in-process scheduling jitter. Picked at one
/// `perRelaySendTimeout` worth of slack — small relative to the total
/// `perRelay × N` budget at default-config sizes (≈14% of the 35s outer
/// at N=6) but large enough to absorb realistic dispatch overhead on
/// cold-start without erosion as the relay count grows.
const Duration _outerPublishTimeoutBuffer = RelayPool.perRelaySendTimeout;

/// Computes the outer timeout that bounds the call into
/// [NostrClient.publishEventAwaitOk] inside `_publishEventToNostr`.
///
/// Derivation: `RelayPool.perRelaySendTimeout * relayCount + buffer`,
/// clamped to `[floor, ceiling]`. Encoding the relationship in code
/// keeps the outer guard from silently firing before the inner
/// sequential fan-out inside [RelayPool._sendCollect] can complete on
/// degraded networks, regardless of how many relays the user has
/// configured — up to the ceiling boundary documented on
/// [_outerPublishTimeoutCeiling].
///
/// **Caveats on `relayCount`**: the value passed in is treated as an
/// upper bound on the actual sequential fan-out width. Two factors
/// make the real fan-out narrower:
///   * `_sendCollect` skips relays without `writeAccess` for `EVENT`
///     messages, so read-only relays in the configured set don't
///     consume a per-relay slot.
///   * Callers passing `tempRelays` to `RelayPool.send` add fan-out
///     width that this helper cannot see; the canonical
///     [VideoEventPublisher] path does not, but a future caller might.
/// Both factors err on the conservative side — the derived bound is
/// never tighter than the real worst case.
///
/// Exposed at file scope so unit tests can assert the math directly
/// without spinning up a [NostrClient].
Duration outerPublishTimeoutFor(int relayCount) {
  final derived =
      RelayPool.perRelaySendTimeout * relayCount + _outerPublishTimeoutBuffer;
  if (derived < _outerPublishTimeoutFloor) return _outerPublishTimeoutFloor;
  if (derived > _outerPublishTimeoutCeiling) return _outerPublishTimeoutCeiling;
  return derived;
}

List<List<String>> _buildMentionPTags(
  Iterable<String> pubkeys, {
  Iterable<String> excludedPubkeys = const [],
}) {
  final excluded = excludedPubkeys
      .map((pubkey) => pubkey.trim().toLowerCase())
      .where(NostrHexUtils.isValidPubkey)
      .toSet();
  final seen = <String>{};
  final tags = <List<String>>[];

  for (final pubkey in pubkeys) {
    final normalizedPubkey = pubkey.trim().toLowerCase();
    if (!NostrHexUtils.isValidPubkey(normalizedPubkey) ||
        excluded.contains(normalizedPubkey) ||
        !seen.add(normalizedPubkey)) {
      continue;
    }

    tags.add(['p', normalizedPubkey, collaboratorInviteRelayHint, 'mention']);
  }

  return tags;
}

/// Result of a single REST-then-WebSocket publish attempt.
enum _EventPublishOutcome {
  /// The event was accepted (REST 200, or a WebSocket send succeeded).
  published,

  /// The REST API rejected the event (401/403/422 or signer mismatch).
  /// Non-retryable — do not fall back or retry.
  permanentlyRejected,

  /// A transient failure (REST 5xx/timeout/network and the WebSocket
  /// fallback also failed). The caller may retry.
  transientFailure,
}

enum _RelayPresence { found, notFound, unknown }

/// Service for publishing processed videos to Nostr relays
/// REFACTORED: Removed ChangeNotifier - now uses pure state management via Riverpod
class VideoEventPublisher {
  VideoEventPublisher({
    required UploadManager uploadManager,
    required NostrClient nostrService,
    AuthService? authService,
    PersonalEventCacheService? personalEventCache,
    VideoEventService? videoEventService,
    BlossomUploadService? blossomUploadService,
    ProfileRepository? profileRepository,
    AudioExtractionService? audioExtractionService,
    ProfileStatsDao? profileStatsDao,
    SavedSoundsService? savedSoundsService,
    EventApiClient? eventApiClient,
  }) : _uploadManager = uploadManager,
       _nostrService = nostrService,
       _authService = authService,
       _personalEventCache = personalEventCache,
       _videoEventService = videoEventService,
       _blossomUploadService = blossomUploadService,
       _profileRepository = profileRepository,
       _audioExtractionService = audioExtractionService,
       _profileStatsDao = profileStatsDao,
       _savedSoundsService = savedSoundsService,
       _eventApiClient = eventApiClient;
  final UploadManager _uploadManager;
  final NostrClient _nostrService;
  final AuthService? _authService;
  final PersonalEventCacheService? _personalEventCache;
  final VideoEventService? _videoEventService;
  final BlossomUploadService? _blossomUploadService;
  final ProfileRepository? _profileRepository;
  final AudioExtractionService? _audioExtractionService;
  final ProfileStatsDao? _profileStatsDao;
  final SavedSoundsService? _savedSoundsService;

  /// REST-first publish client. When non-null, video events are published
  /// via `POST /api/events` first and only fall back to the WebSocket relay
  /// pool on transient REST failures. When null (legacy / test wiring), the
  /// publisher uses the WebSocket-only retry path.
  final EventApiClient? _eventApiClient;

  // Statistics
  int _totalEventsPublished = 0;
  int _totalEventsFailed = 0;
  DateTime? _lastPublishTime;

  /// The outer timeout that will bound the next call into
  /// [NostrClient.publishEventAwaitOk] inside [_publishEventToNostr], computed
  /// live from [outerPublishTimeoutFor] and the current
  /// [NostrClient.configuredRelayCount].
  ///
  /// Exposed so tests can pin the production wiring between the helper
  /// and the call site without instrumenting `Future.timeout`. Reading
  /// this getter has no side effects.
  Duration get currentOuterPublishTimeout =>
      outerPublishTimeoutFor(_nostrService.configuredRelayCount);

  void _addReplyTags(List<List<String>> tags, VideoReplyContext context) {
    tags
      ..add(['E', context.rootEventId, '', context.rootAuthorPubkey])
      ..add(['K', context.rootEventKind.toString()])
      ..add(['P', context.rootAuthorPubkey]);

    final rootAddressableId = context.rootAddressableId;
    if (rootAddressableId != null && rootAddressableId.isNotEmpty) {
      tags.add(['A', rootAddressableId, '']);
    }

    final parentCommentId = context.parentCommentId;
    if (parentCommentId != null && parentCommentId.isNotEmpty) {
      tags
        ..add([
          'e',
          parentCommentId,
          '',
          context.parentAuthorPubkey ?? context.rootAuthorPubkey,
        ])
        ..add(['k', EventKind.comment.toString()])
        ..add(['p', context.parentAuthorPubkey ?? context.rootAuthorPubkey]);
      return;
    }

    tags
      ..add(['e', context.rootEventId, '', context.rootAuthorPubkey])
      ..add(['k', context.rootEventKind.toString()])
      ..add(['p', context.rootAuthorPubkey]);

    if (rootAddressableId != null && rootAddressableId.isNotEmpty) {
      tags.add(['a', rootAddressableId, '']);
    }
  }

  /// Initialize the publisher
  Future<void> initialize() async {
    Log.debug(
      'Initializing VideoEventPublisher',
      name: 'VideoEventPublisher',
      category: LogCategory.video,
    );

    Log.info(
      'VideoEventPublisher initialized',
      name: 'VideoEventPublisher',
      category: LogCategory.video,
    );
  }

  /// Publishes a signed Nostr [event] to the configured relays and returns
  /// `true` iff at least one relay confirmed acceptance with a NIP-20
  /// `OK true` response ([PublishOutcome.confirmed]).
  ///
  /// A successful WebSocket send is NOT sufficient — relays can accept
  /// the frame and still reject the event at the protocol level (e.g.
  /// the divine relay's policy rejections). Treating a bare send as
  /// success used to mark rejected videos as published while they were
  /// silently dropped relay-side.
  ///
  /// **Failure contract** (returns `false`):
  /// 1. `TimeoutException` — the inner OK-wait (bound by
  ///    [currentOuterPublishTimeout], which the publish tracker starts
  ///    before the send fan-out) or the outer backstop
  ///    `Future.timeout` fires first. See [outerPublishTimeoutFor].
  /// 2. Relay rejection / no response — [PublishOutcome.failed]: every
  ///    targeted relay rejected the event with `OK false` or never
  ///    responded.
  /// 3. Inner exception — any throw inside the outer try/catch is
  ///    logged via `Log.error` and converted to `false`.
  ///
  /// All three causes are intentionally treated as transient by the
  /// retry loop in [publishDirectUpload] (3 attempts, 2s/4s backoff).
  /// The single-shot call sites in [_publishImportedAudioEvent],
  /// [_publishAudioEvent], and [republishWithSubtitles] surface a
  /// `false` return as `null` / `false` per their own contracts.
  ///
  /// **Sentinel-return contract** (per audit #3593 / #4592): this
  /// method intentionally does NOT throw. All four callers are
  /// internal and already have explicit post-failure recovery paths;
  /// introducing a `PublishFailedException` would mean wrapping each
  /// caller in try/catch to preserve the current bool/null/false
  /// semantics with no observable behaviour change. Per
  /// `.claude/rules/error_handling.md` the inner failures are
  /// network/IO + API/domain — matrix-NO — so the Reportable-wrapped
  /// throw path would not surface to Crashlytics either.
  Future<bool> _publishEventToNostr(Event event) async {
    try {
      Log.debug(
        'Publishing event to Nostr relays: ${event.id}',
        name: 'VideoEventPublisher',
        category: LogCategory.video,
      );

      // Log relay diagnostics
      Log.info(
        '🔍 Relay diagnostics: isInitialized=${_nostrService.isInitialized}, '
        'configured=${_nostrService.configuredRelayCount}, '
        'connected=${_nostrService.connectedRelayCount}',
        name: 'VideoEventPublisher',
        category: LogCategory.video,
      );
      Log.info(
        '🔍 Configured relays: ${_nostrService.configuredRelays}',
        name: 'VideoEventPublisher',
        category: LogCategory.video,
      );
      Log.info(
        '🔍 Connected relays: ${_nostrService.connectedRelays}',
        name: 'VideoEventPublisher',
        category: LogCategory.video,
      );

      // Ensure NostrClient is initialized before attempting broadcast
      if (!_nostrService.isInitialized) {
        Log.warning(
          '⚠️ NostrClient not initialized, initializing now...',
          name: 'VideoEventPublisher',
          category: LogCategory.video,
        );
        await _nostrService.initialize();
      }

      Log.info(
        '📡 ${_nostrService.connectedRelayCount} relay(s) connected',
        name: 'VideoEventPublisher',
        category: LogCategory.video,
      );

      // Log the complete event details
      Log.info(
        '📤 FULL EVENT TO PUBLISH:',
        name: 'VideoEventPublisher',
        category: LogCategory.video,
      );
      Log.info(
        '  ID: ${event.id}',
        name: 'VideoEventPublisher',
        category: LogCategory.video,
      );
      Log.info(
        '  Pubkey: ${event.pubkey}',
        name: 'VideoEventPublisher',
        category: LogCategory.video,
      );
      Log.info(
        '  Created At: ${event.createdAt}',
        name: 'VideoEventPublisher',
        category: LogCategory.video,
      );
      Log.info(
        '  Kind: ${event.kind}',
        name: 'VideoEventPublisher',
        category: LogCategory.video,
      );
      Log.info(
        '  Content: "${event.content}"',
        name: 'VideoEventPublisher',
        category: LogCategory.video,
      );
      Log.info(
        '  Tags (${event.tags.length} total):',
        name: 'VideoEventPublisher',
        category: LogCategory.video,
      );
      for (final tag in event.tags) {
        final sanitizedTag = sanitizeTagForLog(tag);
        Log.info(
          '    - ${sanitizedTag.join(", ")}',
          name: 'VideoEventPublisher',
          category: LogCategory.video,
        );
      }
      Log.info(
        '  Signature: ${event.sig}',
        name: 'VideoEventPublisher',
        category: LogCategory.video,
      );
      Log.info(
        '  Is Valid: ${event.isValid}',
        name: 'VideoEventPublisher',
        category: LogCategory.video,
      );
      Log.info(
        '  Is Signed: ${event.isSigned}',
        name: 'VideoEventPublisher',
        category: LogCategory.video,
      );

      // Log the raw JSON representation
      try {
        final eventMap = sanitizeEventJsonForLog(event.toJson());
        final jsonStr = jsonEncode(eventMap);
        Log.info(
          '📋 FULL EVENT JSON:',
          name: 'VideoEventPublisher',
          category: LogCategory.video,
        );
        Log.info(
          jsonStr,
          name: 'VideoEventPublisher',
          category: LogCategory.video,
        );
      } catch (e) {
        Log.warning(
          'Could not serialize event to JSON: $e',
          name: 'VideoEventPublisher',
          category: LogCategory.video,
        );
      }

      // Publish and wait for a NIP-20 `OK` from at least one relay. The
      // [outerPublishTimeoutFor]-derived bound (perRelaySendTimeout ×
      // relayCount + buffer) is passed as the OK-wait timeout — the SDK's
      // publish tracker starts that timer before the send fan-out, so it
      // covers both the sequential sends and the OK wait.
      //
      // Defense-in-depth: the outer `Future.timeout` (one extra
      // [RelayPool.perRelaySendTimeout] of slack so the inner tracker
      // normally fires first) guards the code that runs before the
      // tracker exists — e.g. `retryDisconnectedRelays` stuck in
      // reconnect backoff. The retry loop in [publishDirectUpload] picks
      // up after each failed attempt.
      //
      // We use try/catch on [TimeoutException] rather than `.timeout(
      // onTimeout: ...)`: `publishEventAwaitOk` returns a non-nullable
      // [PublishOutcome], so an `onTimeout` closure could not return
      // null, and the try/catch shape also avoids the mocktail
      // runtime-type mismatch on stubbed futures.
      final outerTimeout = currentOuterPublishTimeout;
      PublishOutcome? publishOutcome;
      try {
        publishOutcome = await _nostrService
            .publishEventAwaitOk(event, timeout: outerTimeout)
            .timeout(outerTimeout + RelayPool.perRelaySendTimeout);
      } on TimeoutException {
        Log.error(
          '⏱️ publishEventAwaitOk timed out after '
          '${outerTimeout.inSeconds}s for event ${event.id} '
          '(relayCount=${_nostrService.configuredRelayCount})',
          name: 'VideoEventPublisher',
          category: LogCategory.video,
        );
        publishOutcome = null;
      }

      if (publishOutcome != null && publishOutcome.confirmed) {
        Log.info(
          '📡 Event confirmed by relay(s): ${event.id} '
          '(${publishOutcome.summary}, '
          'configured=${_nostrService.configuredRelayCount}, '
          'connected=${_nostrService.connectedRelayCount})',
          name: 'VideoEventPublisher',
          category: LogCategory.video,
        );

        return true;
      } else {
        final failureReason = publishOutcome?.summary ?? 'timeout';
        Log.error(
          '❌ Event publish failed for ${event.id}: $failureReason '
          '(configured=${_nostrService.configuredRelayCount}, '
          'connected=${_nostrService.connectedRelayCount})',
          name: 'VideoEventPublisher',
          category: LogCategory.video,
        );
        return false;
      }
    } catch (e) {
      Log.error(
        'Failed to publish event to relays: $e',
        name: 'VideoEventPublisher',
        category: LogCategory.video,
      );
      return false;
    }
  }

  /// Publishes an already-signed video [event] for [upload] using the
  /// REST-first strategy with a WebSocket fire-and-forget fallback.
  ///
  /// Behaviour when an [EventApiClient] is configured:
  /// 1. If [isRetry], first query configured relays by event id and by
  ///    `author+kind+d-tag`; if the event is already on a relay, mark it
  ///    published and stop (avoids re-publishing a previously accepted
  ///    event whose `OK` was lost).
  /// 2. Up to 3 attempts of `POST /api/events`. A 200 acceptance is
  ///    published; a 401/403/422 is a non-retryable failure; a transient
  ///    REST failure falls back to a WebSocket `publishEvent`
  ///    (fire-and-forget, not `publishEventAwaitOk`).
  /// 3. Before each retry, re-check relay presence so a false-negative
  ///    WebSocket `OK` does not produce a duplicate publish.
  ///
  /// When no [EventApiClient] is configured, the legacy WebSocket-only
  /// retry path is used unchanged.
  ///
  /// The same signed [event] is reused across all attempts — no event is
  /// re-signed per retry, so relays deduplicate by id.
  @visibleForTesting
  Future<bool> publishSignedVideoEvent({
    required PendingUpload upload,
    required Event event,
    bool isRetry = false,
  }) async {
    final outcome = await _publishSignedVideoEventOutcome(
      upload: upload,
      event: event,
      isRetry: isRetry,
    );
    return outcome == _EventPublishOutcome.published;
  }

  Future<_EventPublishOutcome> _publishSignedVideoEventOutcome({
    required PendingUpload upload,
    required Event event,
    bool isRetry = false,
  }) async {
    final apiClient = _eventApiClient;
    if (apiClient == null) {
      return _publishWithWebSocketRetries(event);
    }

    if (isRetry && await _relayPresence(event) == _RelayPresence.found) {
      Log.info(
        '♻️ Recovered already-published video event ${event.id} from relays; '
        'skipping re-publish',
        name: 'VideoEventPublisher',
        category: LogCategory.video,
      );
      return _EventPublishOutcome.published;
    }

    const maxRetries = 3;
    for (var attempt = 1; attempt <= maxRetries; attempt++) {
      // A lost OK on a prior attempt can leave the event already stored on
      // a relay; re-check before re-broadcasting to avoid duplicates.
      if (attempt > 1 && await _relayPresence(event) == _RelayPresence.found) {
        Log.info(
          '♻️ Event ${event.id} found on relay before retry $attempt; '
          'marking published',
          name: 'VideoEventPublisher',
          category: LogCategory.video,
        );
        return _EventPublishOutcome.published;
      }

      final outcome = await _publishViaRestThenWebSocket(apiClient, event);
      switch (outcome) {
        case _EventPublishOutcome.published:
          if (attempt > 1) {
            Log.info(
              '✅ Publish succeeded on attempt $attempt',
              name: 'VideoEventPublisher',
              category: LogCategory.video,
            );
          }
          return _EventPublishOutcome.published;
        case _EventPublishOutcome.permanentlyRejected:
          Log.error(
            '❌ Publish permanently rejected for ${event.id}; not retrying',
            name: 'VideoEventPublisher',
            category: LogCategory.video,
          );
          return _EventPublishOutcome.permanentlyRejected;
        case _EventPublishOutcome.transientFailure:
          if (attempt < maxRetries) {
            final delaySeconds = attempt * 2; // 2s, 4s backoff
            Log.warning(
              '⚠️ Publish attempt $attempt failed, retrying in '
              '${delaySeconds}s...',
              name: 'VideoEventPublisher',
              category: LogCategory.video,
            );
            await Future<void>.delayed(Duration(seconds: delaySeconds));
          } else {
            Log.error(
              '❌ All $maxRetries publish attempts failed',
              name: 'VideoEventPublisher',
              category: LogCategory.video,
            );
          }
      }
    }
    return _EventPublishOutcome.transientFailure;
  }

  /// One publish attempt: REST first, WebSocket fire-and-forget on transient
  /// REST failure.
  Future<_EventPublishOutcome> _publishViaRestThenWebSocket(
    EventApiClient apiClient,
    Event event,
  ) async {
    final restResult = await apiClient.publishEvent(event);
    switch (restResult) {
      case EventApiAccepted():
        return _EventPublishOutcome.published;
      case EventApiRejected(:final statusCode, :final reason):
        Log.error(
          '❌ REST publish rejected ($statusCode) for ${event.id}: $reason',
          name: 'VideoEventPublisher',
          category: LogCategory.video,
        );
        return _EventPublishOutcome.permanentlyRejected;
      case EventApiTransientFailure(:final reason):
        Log.warning(
          '⚠️ REST publish transient failure for ${event.id} ($reason); '
          'falling back to WebSocket fire-and-forget',
          name: 'VideoEventPublisher',
          category: LogCategory.video,
        );
        return _publishViaWebSocketFireAndForget(event);
    }
  }

  /// Sends [event] over the WebSocket relay pool without waiting for a NIP-20
  /// `OK` (fire-and-forget). A [PublishSuccess] frame counts as sent.
  ///
  /// Video publishes intentionally avoid `publishEventAwaitOk` here: relays
  /// that accept and serve the event but drop the `OK` would otherwise make a
  /// successful upload look failed.
  Future<_EventPublishOutcome> _publishViaWebSocketFireAndForget(
    Event event,
  ) async {
    try {
      if (!_nostrService.isInitialized) {
        await _nostrService.initialize();
      }
      final outerTimeout = currentOuterPublishTimeout;
      PublishResult? result;
      try {
        result = await _nostrService.publishEvent(event).timeout(outerTimeout);
      } on TimeoutException {
        Log.error(
          '⏱️ WebSocket publishEvent timed out after '
          '${outerTimeout.inSeconds}s for ${event.id}',
          name: 'VideoEventPublisher',
          category: LogCategory.video,
        );
        return _EventPublishOutcome.transientFailure;
      }
      if (result is PublishSuccess) {
        Log.info(
          '📡 Event sent to relays (fire-and-forget): ${event.id}',
          name: 'VideoEventPublisher',
          category: LogCategory.video,
        );
        return _EventPublishOutcome.published;
      }
      Log.error(
        '❌ WebSocket publishEvent failed for ${event.id}: '
        '${result.failureReason ?? 'unknown'}',
        name: 'VideoEventPublisher',
        category: LogCategory.video,
      );
      return _EventPublishOutcome.transientFailure;
    } catch (e) {
      Log.error(
        'WebSocket fire-and-forget publish failed for ${event.id}: $e',
        name: 'VideoEventPublisher',
        category: LogCategory.video,
      );
      return _EventPublishOutcome.transientFailure;
    }
  }

  /// Legacy WebSocket-only publish with the original 3-attempt, 2s/4s backoff
  /// retry loop. Used only when no [EventApiClient] is configured.
  Future<_EventPublishOutcome> _publishWithWebSocketRetries(Event event) async {
    const maxRetries = 3;
    for (var attempt = 1; attempt <= maxRetries; attempt++) {
      if (await _publishEventToNostr(event)) {
        if (attempt > 1) {
          Log.info(
            '✅ Publish succeeded on attempt $attempt',
            name: 'VideoEventPublisher',
            category: LogCategory.video,
          );
        }
        return _EventPublishOutcome.published;
      }

      if (attempt < maxRetries) {
        final delaySeconds = attempt * 2; // 2s, 4s backoff
        Log.warning(
          '⚠️ Publish attempt $attempt failed, retrying in ${delaySeconds}s...',
          name: 'VideoEventPublisher',
          category: LogCategory.video,
        );
        await Future<void>.delayed(Duration(seconds: delaySeconds));
      } else {
        Log.error(
          '❌ All $maxRetries publish attempts failed',
          name: 'VideoEventPublisher',
          category: LogCategory.video,
        );
      }
    }
    return _EventPublishOutcome.transientFailure;
  }

  /// Checks whether [event] is already retrievable from the configured relays,
  /// queried both by event id and by `author+kind+d-tag`.
  Future<_RelayPresence> _relayPresence(Event event) async {
    try {
      final dTag = _dTagOf(event);
      final filters = <Filter>[
        Filter(ids: [event.id], limit: 1),
        if (dTag.isNotEmpty)
          Filter(
            authors: [event.pubkey],
            kinds: [event.kind],
            d: [dTag],
            limit: 1,
          ),
      ];
      final found = await _nostrService.queryEvents(filters, useCache: false);
      for (final candidate in found) {
        if (candidate.id == event.id) return _RelayPresence.found;
        if (candidate.pubkey == event.pubkey &&
            candidate.kind == event.kind &&
            _dTagOf(candidate) == dTag) {
          return _RelayPresence.found;
        }
      }
      return _RelayPresence.notFound;
    } catch (e) {
      Log.warning(
        'Recovery query failed for ${event.id}: $e',
        name: 'VideoEventPublisher',
        category: LogCategory.video,
      );
      return _RelayPresence.unknown;
    }
  }

  String _dTagOf(Event event) {
    var dTag = '';
    for (final tag in event.tags) {
      if (tag.length >= 2 && tag[0] == 'd') {
        dTag = tag[1];
        break;
      }
    }
    return dTag;
  }

  Event? _loadRetryableSignedEvent(PendingUpload upload) {
    final cachedEventId = upload.nostrEventId;
    if (cachedEventId == null || cachedEventId.isEmpty) {
      return null;
    }

    final cachedEvent = _personalEventCache?.getEventById(cachedEventId);
    if (cachedEvent == null) {
      Log.warning(
        'Stored retry event $cachedEventId was missing from personal cache',
        name: 'VideoEventPublisher',
        category: LogCategory.video,
      );
      return null;
    }

    Log.info(
      'Reusing cached signed video event for retry: ${cachedEvent.id}',
      name: 'VideoEventPublisher',
      category: LogCategory.video,
    );
    return cachedEvent;
  }

  Future<void> _persistRetryableSignedEvent(
    PendingUpload upload,
    Event event,
  ) async {
    _personalEventCache?.cacheUserEvent(event);
    await _uploadManager.updateUploadStatus(
      upload.id,
      upload.status,
      nostrEventId: event.id,
    );
  }

  /// Get publishing statistics
  Map<String, dynamic> get publishingStats => {
    'total_published': _totalEventsPublished,
    'total_failed': _totalEventsFailed,
    'last_publish_time': _lastPublishTime?.toIso8601String(),
  };

  /// Publish a video event with custom metadata
  Future<bool> publishVideoEvent({
    required PendingUpload upload,
    String? title,
    String? description,
    List<String>? hashtags,
    int? expirationTimestamp,
    bool allowAudioReuse = false,
    Duration? thumbnailTimestamp,
    List<String> collaboratorPubkeys = const [],
    List<String> mentionedPubkeys = const [],
    String? inspiredByAddressableId,
    String? inspiredByRelayUrl,
    String? inspiredByNpub,
    AudioEvent? selectedAudio,
    String? selectedAudioEventId,
    String? selectedAudioRelay,
    String? language,
    String? contentWarning,
    VideoReplyContext? replyContext,
    bool addReplyToFeed = false,
  }) async {
    // Create a temporary upload with updated metadata
    final updatedUpload = upload.copyWith(
      title: title ?? upload.title,
      description: description ?? upload.description,
      hashtags: hashtags ?? upload.hashtags,
    );

    return publishDirectUpload(
      updatedUpload,
      expirationTimestamp: expirationTimestamp,
      allowAudioReuse: allowAudioReuse,
      collaboratorPubkeys: collaboratorPubkeys,
      mentionedPubkeys: mentionedPubkeys,
      inspiredByAddressableId: inspiredByAddressableId,
      inspiredByRelayUrl: inspiredByRelayUrl,
      inspiredByNpub: inspiredByNpub,
      selectedAudio: selectedAudio,
      selectedAudioEventId: selectedAudioEventId,
      selectedAudioRelay: selectedAudioRelay,
      language: language,
      contentWarning: contentWarning,
      thumbnailTimestamp: thumbnailTimestamp,
      replyContext: replyContext,
      addReplyToFeed: addReplyToFeed,
    );
  }

  /// Publish a video directly without polling (for direct upload)
  Future<bool> publishDirectUpload(
    PendingUpload upload, {
    int? expirationTimestamp,
    bool allowAudioReuse = false,
    List<String> collaboratorPubkeys = const [],
    List<String> mentionedPubkeys = const [],
    Duration? thumbnailTimestamp,
    String? inspiredByAddressableId,
    String? inspiredByRelayUrl,
    String? inspiredByNpub,
    AudioEvent? selectedAudio,
    String? selectedAudioEventId,
    String? selectedAudioRelay,
    String? language,
    String? contentWarning,
    VideoReplyContext? replyContext,
    bool addReplyToFeed = false,
  }) async {
    if (upload.videoId == null || upload.cdnUrl == null) {
      Log.error(
        'Cannot publish upload - missing videoId or cdnUrl',
        name: 'VideoEventPublisher',
        category: LogCategory.video,
      );
      return false;
    }

    // Validate that at least one video URL is a proper HTTP/HTTPS URL
    // This prevents local file paths from being published to Nostr
    final hasValidVideoUrl =
        _isHttpUrl(upload.streamingMp4Url) ||
        _isHttpUrl(upload.fallbackUrl) ||
        _isHttpUrl(upload.streamingHlsUrl) ||
        _isHttpUrl(upload.cdnUrl);
    if (!hasValidVideoUrl) {
      Log.error(
        '❌ Cannot publish - no valid HTTP video URLs found. '
        'cdnUrl=${upload.cdnUrl}, fallbackUrl=${upload.fallbackUrl}, '
        'streamingMp4Url=${upload.streamingMp4Url}, '
        'streamingHlsUrl=${upload.streamingHlsUrl}',
        name: 'VideoEventPublisher',
        category: LogCategory.video,
      );
      return false;
    }

    try {
      Log.debug(
        'Publishing direct upload: ${upload.videoId}',
        name: 'VideoEventPublisher',
        category: LogCategory.video,
      );

      // Create NIP-71 compliant tags for the video
      final tags = <List<String>>[];

      // Generate unique identifier for the addressable event
      // Use videoId if available, otherwise generate from timestamp and upload ID
      final dTag =
          upload.videoId ??
          '${DateTime.now().millisecondsSinceEpoch}_${upload.id}';
      tags.add(['d', dTag]);

      if (replyContext != null) {
        _addReplyTags(tags, replyContext);
        if (addReplyToFeed) {
          tags.add(const [
            videoReplyVisibilityTagName,
            videoReplyVisibilityFeedValue,
          ]);
        }
      }

      // Build imeta tag components
      final imetaComponents = <String>[];

      // Add all video URLs from Blossom upload stored in PendingUpload
      // Priority order (based on _scoreVideoUrl in video_event.dart):
      // 1. streamingMp4Url (BunnyStream MP4 - scores 110) - ONLY if valid
      // 2. fallbackUrl (R2 MP4 - scores 100)
      // 3. streamingHlsUrl (HLS - scores 90)

      final urlsAdded = <String>[];

      // Validate BunnyStream MP4 URL - must have quality suffix (e.g., play_360p.mp4)
      // Invalid: .../play.mp4 (returns 404)
      // Valid: .../play_360p.mp4, .../play_480p.mp4, etc.
      if (_isHttpUrl(upload.streamingMp4Url)) {
        final isValidBunnyMp4 =
            !upload.streamingMp4Url!.contains('stream.divine.video') ||
            upload.streamingMp4Url!.contains(
              RegExp(r'play_\d+p\.mp4'),
            ); // Non-BunnyStream URLs are assumed valid

        if (isValidBunnyMp4) {
          imetaComponents.add('url ${upload.streamingMp4Url}');
          urlsAdded.add('MP4(streaming): ${upload.streamingMp4Url}');
        } else {
          Log.warning(
            '⚠️ Skipping invalid BunnyStream MP4 URL (missing quality suffix): ${upload.streamingMp4Url}',
            name: 'VideoEventPublisher',
            category: LogCategory.video,
          );
        }
      } else if (upload.streamingMp4Url != null &&
          upload.streamingMp4Url!.isNotEmpty) {
        Log.error(
          '⚠️ Skipping non-HTTP streamingMp4Url (possible local path): ${upload.streamingMp4Url}',
          name: 'VideoEventPublisher',
          category: LogCategory.video,
        );
      }

      if (_isHttpUrl(upload.fallbackUrl)) {
        imetaComponents.add('url ${upload.fallbackUrl}');
        urlsAdded.add('MP4(R2 fallback): ${upload.fallbackUrl}');
      } else if (upload.fallbackUrl != null && upload.fallbackUrl!.isNotEmpty) {
        Log.error(
          '⚠️ Skipping non-HTTP fallbackUrl (possible local path): ${upload.fallbackUrl}',
          name: 'VideoEventPublisher',
          category: LogCategory.video,
        );
      }

      if (_isHttpUrl(upload.streamingHlsUrl)) {
        imetaComponents.add('url ${upload.streamingHlsUrl}');
        urlsAdded.add('HLS: ${upload.streamingHlsUrl}');
      } else if (upload.streamingHlsUrl != null &&
          upload.streamingHlsUrl!.isNotEmpty) {
        Log.error(
          '⚠️ Skipping non-HTTP streamingHlsUrl (possible local path): ${upload.streamingHlsUrl}',
          name: 'VideoEventPublisher',
          category: LogCategory.video,
        );
      }

      // Fallback to legacy cdnUrl if no Blossom-specific URLs
      if (urlsAdded.isEmpty && _isHttpUrl(upload.cdnUrl)) {
        imetaComponents.add('url ${upload.cdnUrl}');
        urlsAdded.add('Legacy CDN: ${upload.cdnUrl}');
      } else if (urlsAdded.isEmpty &&
          upload.cdnUrl != null &&
          upload.cdnUrl!.isNotEmpty) {
        Log.error(
          '⚠️ Skipping non-HTTP cdnUrl (possible local path): ${upload.cdnUrl}',
          name: 'VideoEventPublisher',
          category: LogCategory.video,
        );
      }

      if (urlsAdded.isNotEmpty) {
        Log.info(
          '✅ Added video URLs to imeta:\n  ${urlsAdded.join("\n  ")}',
          name: 'VideoEventPublisher',
          category: LogCategory.video,
        );
      } else {
        Log.error(
          '❌ No valid HTTP video URLs available - refusing to publish. '
          'This prevents local file paths from leaking into Nostr events.',
          name: 'VideoEventPublisher',
          category: LogCategory.video,
        );
        return false;
      }

      imetaComponents.add('m video/mp4');

      // Use uploaded thumbnail CDN URL from Blossom upload
      if (upload.thumbnailPath != null && upload.thumbnailPath!.isNotEmpty) {
        final thumbnailPath = upload.thumbnailPath!;
        // Only include HTTP/HTTPS CDN URLs
        if (thumbnailPath.startsWith('http://') ||
            thumbnailPath.startsWith('https://')) {
          imetaComponents.add('image $thumbnailPath');
          Log.info(
            '✅ Using uploaded thumbnail CDN URL: $thumbnailPath',
            name: 'VideoEventPublisher',
            category: LogCategory.video,
          );
        }
      }

      // Add dimensions to imeta if available
      if (upload.videoWidth != null && upload.videoHeight != null) {
        imetaComponents.add('dim ${upload.videoWidth}x${upload.videoHeight}');
      }

      // Add file size and SHA256 if available from local video file
      if (upload.localVideoPath.isNotEmpty) {
        try {
          final videoFile = File(upload.localVideoPath);
          if (videoFile.existsSync()) {
            // Add file size
            final fileSize = videoFile.lengthSync();
            imetaComponents.add('size $fileSize');

            // Calculate SHA256 hash
            final bytes = await videoFile.readAsBytes();
            final hash = sha256.convert(bytes);
            imetaComponents.add('x $hash');

            Log.verbose(
              'Added file metadata - size: $fileSize bytes, hash: $hash',
              name: 'VideoEventPublisher',
              category: LogCategory.video,
            );
          }
        } catch (e) {
          Log.warning(
            'Failed to calculate file metadata: $e',
            name: 'VideoEventPublisher',
            category: LogCategory.video,
          );
        }
      }

      // Generate blurhash for progressive image loading
      if (upload.localVideoPath.isNotEmpty) {
        try {
          Log.debug(
            '🎨 Generating blurhash from video thumbnail',
            name: 'VideoEventPublisher',
            category: LogCategory.video,
          );

          // Extract thumbnail bytes with 10-second timeout
          final thumbnailBytes =
              await VideoThumbnailService.extractThumbnailBytes(
                videoPath: upload.localVideoPath,
                timestamp:
                    thumbnailTimestamp ??
                    VideoEditorConstants.defaultThumbnailExtractTime,
              ).timeout(
                const Duration(seconds: 10),
                onTimeout: () {
                  Log.warning(
                    '⏱️ Thumbnail extraction timed out after 10 seconds',
                    name: 'VideoEventPublisher',
                    category: LogCategory.video,
                  );
                  return null;
                },
              );

          if (thumbnailBytes != null) {
            // Generate blurhash with 3-second timeout
            final blurhash =
                await BlurhashService.generateBlurhash(
                  thumbnailBytes.bytes,
                ).timeout(
                  const Duration(seconds: 3),
                  onTimeout: () {
                    Log.warning(
                      '⏱️ Blurhash generation timed out after 3 seconds',
                      name: 'VideoEventPublisher',
                      category: LogCategory.video,
                    );
                    return null;
                  },
                );

            if (blurhash != null && blurhash.isNotEmpty) {
              imetaComponents.add('blurhash $blurhash');
              Log.info(
                '✅ Generated blurhash: $blurhash',
                name: 'VideoEventPublisher',
                category: LogCategory.video,
              );
            } else {
              Log.warning(
                'Blurhash generation returned null or empty',
                name: 'VideoEventPublisher',
                category: LogCategory.video,
              );
            }
          } else {
            Log.warning(
              'Thumbnail extraction returned null',
              name: 'VideoEventPublisher',
              category: LogCategory.video,
            );
          }
        } catch (e) {
          Log.warning(
            'Failed to generate blurhash: $e',
            name: 'VideoEventPublisher',
            category: LogCategory.video,
          );
          // Continue publishing without blurhash - it's optional metadata
        }
      }

      // Add the complete imeta tag
      tags.add(['imeta', ...imetaComponents]);

      // Optional tags
      if (upload.title != null) tags.add(['title', upload.title!]);
      if (upload.description != null) {
        tags.add(['summary', upload.description!]);
      }

      // Add hashtags
      if (upload.hashtags != null) {
        for (final hashtag in upload.hashtags!) {
          tags.add(['t', hashtag]);
        }
      }

      // Add NIP-32 language self-labeling tags
      if (language != null && language.isNotEmpty) {
        tags.add(['L', 'ISO-639-1']);
        tags.add(['l', language, 'ISO-639-1']);
      }

      // Add NIP-32 content-warning self-labeling tags (NIP-36).
      if (contentWarning != null && contentWarning.isNotEmpty) {
        final warnings = contentWarning.split(',').map((value) => value.trim());
        tags.add(['content-warning', warnings.first]);
        tags.add(['L', 'content-warning']);
        for (final warning in warnings) {
          tags.add(['l', warning, 'content-warning']);
        }
      }

      // Add published_at tag (current timestamp)
      tags.add([
        'published_at',
        (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString(),
      ]);

      // Add duration tag if available
      if (upload.videoDuration != null) {
        tags.add(['duration', upload.videoDuration!.inSeconds.toString()]);
      }

      // Add alt tag for accessibility (use title or description as alt text)
      final altText = upload.title ?? upload.description ?? 'Short video';
      tags.add(['alt', altText]);

      // Add expiration tag if specified
      if (expirationTimestamp != null) {
        tags.add(['expiration', expirationTimestamp.toString()]);
      }

      tags.addAll(buildCollaboratorPTags(collaboratorPubkeys));
      tags.addAll(
        _buildMentionPTags(
          mentionedPubkeys,
          excludedPubkeys: collaboratorPubkeys,
        ),
      );

      // Add Inspired By a-tag (specific video reference)
      if (inspiredByAddressableId != null) {
        tags.add([
          'a',
          inspiredByAddressableId,
          inspiredByRelayUrl ?? 'wss://relay.divine.video',
          'mention',
        ]);
      }

      var selectedAudioReferenceId = selectedAudioEventId;
      var selectedAudioReferenceRelay = selectedAudioRelay;

      if (selectedAudio?.isLocalImport == true) {
        final userPubkey = _authService?.currentPublicKeyHex;
        final relayHint = _audioRelayHint();
        if (userPubkey == null) {
          Log.error(
            'Cannot publish imported audio without an authenticated pubkey',
            name: 'VideoEventPublisher',
            category: LogCategory.video,
          );
          return false;
        }

        selectedAudioReferenceId = await _publishImportedAudioEvent(
          audio: selectedAudio!,
          videoDTag: dTag,
          pubkey: userPubkey,
          relayHint: relayHint,
        );
        selectedAudioReferenceRelay = relayHint;

        if (selectedAudioReferenceId == null) {
          Log.error(
            'Imported audio publishing failed; blocking video publish',
            name: 'VideoEventPublisher',
            category: LogCategory.video,
          );
          return false;
        }
      }

      // Handle selected audio: reference an existing Kind 1063 audio event
      // (e.g., when recording with a selected sound from another video)
      final hasSelectedAudioEventId =
          selectedAudioReferenceId != null &&
          selectedAudioReferenceId.isNotEmpty;
      final reusableSelectedAudioEventId =
          NostrHexUtils.isValidEventId(selectedAudioReferenceId)
          ? selectedAudioReferenceId
          : null;
      if (hasSelectedAudioEventId && reusableSelectedAudioEventId == null) {
        Log.warning(
          'Skipping selected audio reference because it is not a Nostr event id: '
          '$selectedAudioReferenceId',
          name: 'VideoEventPublisher',
          category: LogCategory.video,
        );
      }

      if (reusableSelectedAudioEventId != null) {
        final audioRelay =
            selectedAudioReferenceRelay ?? 'wss://relay.divine.video';
        tags.add(['e', reusableSelectedAudioEventId, audioRelay, 'audio']);
        Log.info(
          'Added selected audio reference e tag: $reusableSelectedAudioEventId',
          name: 'VideoEventPublisher',
          category: LogCategory.video,
        );
      }

      // Handle audio reuse: extract audio, upload, publish Kind 1063 event
      // Then add e tag linking video to audio event
      // Skip if we already referenced a selected audio event above
      String? audioEventId;
      if (allowAudioReuse &&
          !hasSelectedAudioEventId &&
          upload.localVideoPath.isNotEmpty) {
        tags.add(['allow_audio_reuse', 'true']);
        Log.info(
          'Audio reuse enabled - starting audio publishing flow',
          name: 'VideoEventPublisher',
          category: LogCategory.video,
        );

        // Get the user's pubkey for the audio event
        final userPubkey = _authService?.currentPublicKeyHex;
        if (userPubkey != null) {
          // Get a relay hint from connected relays
          String relayHint = 'wss://relay.divine.video';
          if (_nostrService.connectedRelays.isNotEmpty) {
            relayHint = _nostrService.connectedRelays.first;
          }

          // Publish audio event first (we need its ID for the video event)
          audioEventId = await _publishAudioEvent(
            videoPath: upload.localVideoPath,
            videoDTag: dTag,
            pubkey: userPubkey,
            relayHint: relayHint,
            videoTitle: upload.title,
          );

          if (audioEventId != null) {
            // Add e tag referencing the audio event
            // Format: ["e", <audio-event-id>, <relay-hint>, "audio"]
            tags.add(['e', audioEventId, relayHint, 'audio']);
            Log.info(
              'Added audio reference e tag: $audioEventId',
              name: 'VideoEventPublisher',
              category: LogCategory.video,
            );
          } else {
            Log.warning(
              'Audio publishing failed - continuing with video-only publish',
              name: 'VideoEventPublisher',
              category: LogCategory.video,
            );
          }
        } else {
          Log.warning(
            'No user pubkey available - skipping audio publishing',
            name: 'VideoEventPublisher',
            category: LogCategory.video,
          );
        }
      }

      // Add ProofMode tags if native proof exists
      if (upload.hasProofMode) {
        try {
          final nativeProof = upload.nativeProof;
          if (nativeProof != null) {
            Log.info(
              '📜 Adding ProofMode verification tags to Nostr event',
              name: 'VideoEventPublisher',
              category: LogCategory.video,
            );

            //check C2PA metadata
            final C2paSigningService c2paSigningService = C2paSigningService();
            final manifestInfo = await c2paSigningService.readManifest(
              upload.localVideoPath,
            );
            if (manifestInfo?.validationStatus != null) {
              tags.add(['c2pa_manifest_id', ?manifestInfo?.activeManifest]);
              Log.verbose(
                'Added c2pa_manifest_id tag: ${manifestInfo?.activeManifest}',
                name: 'VideoEventPublisher',
                category: LogCategory.video,
              );
            }

            // Add verification level tag (NIP-145)
            final verificationLevel = getVerificationLevel(nativeProof);
            tags.add(['verification', verificationLevel]);
            Log.verbose(
              'Added verification tag: $verificationLevel',
              name: 'VideoEventPublisher',
              category: LogCategory.video,
            );

            // Add ProofMode native proof tag (complete JSON proof data)
            final proofTag = createProofManifestTag(nativeProof);
            tags.add(['proofmode', proofTag]);
            Log.verbose(
              'Added proofmode proof tag (${proofTag.length} chars)',
              name: 'VideoEventPublisher',
              category: LogCategory.video,
            );

            // Add device attestation tag if available (NIP-145)
            final deviceTag = createDeviceAttestationTag(nativeProof);
            if (deviceTag != null) {
              tags.add(['device_attestation', deviceTag]);
              Log.verbose(
                'Added device_attestation tag',
                name: 'VideoEventPublisher',
                category: LogCategory.video,
              );
            }

            // Add PGP fingerprint tag if available (NIP-145)
            final pgpTag = createPgpFingerprintTag(nativeProof);
            if (pgpTag != null) {
              tags.add(['pgp_fingerprint', pgpTag]);
              Log.verbose(
                'Added pgp_fingerprint tag: $pgpTag',
                name: 'VideoEventPublisher',
                category: LogCategory.video,
              );
            }

            _addIdentityDiscoveryTags(tags, nativeProof);

            Log.info(
              '✅ ProofMode verification tags added successfully',
              name: 'VideoEventPublisher',
              category: LogCategory.video,
            );
          }
        } catch (e) {
          Log.error(
            'Failed to add ProofMode tags: $e',
            name: 'VideoEventPublisher',
            category: LogCategory.video,
          );
          // Continue publishing even if ProofMode tag generation fails
        }
      }

      // Create the event content
      var content = upload.description ?? upload.title ?? '';

      // Append NIP-27 Inspired By person reference to content
      if (inspiredByNpub != null && inspiredByNpub.isNotEmpty) {
        final ibText = '\n\nInspired by nostr:$inspiredByNpub';
        content = content.isEmpty ? ibText.trim() : '$content$ibText';
      }

      // Create and sign the event
      if (_authService == null) {
        Log.error(
          'Auth service is null - cannot create video event',
          name: 'VideoEventPublisher',
          category: LogCategory.video,
        );
        return false;
      }

      if (!_authService.isAuthenticated) {
        Log.error(
          'User not authenticated - cannot create video event',
          name: 'VideoEventPublisher',
          category: LogCategory.video,
        );
        return false;
      }

      Log.debug(
        '📱 Creating and signing video event...',
        name: 'VideoEventPublisher',
        category: LogCategory.video,
      );
      Log.verbose(
        'Content: "$content"',
        name: 'VideoEventPublisher',
        category: LogCategory.video,
      );
      Log.verbose(
        'Tags: ${tags.length} tags',
        name: 'VideoEventPublisher',
        category: LogCategory.video,
      );

      final reusedEvent = _loadRetryableSignedEvent(upload);
      final event =
          reusedEvent ??
          await _authService.createAndSignEvent(
            kind:
                NIP71VideoKinds.getPreferredAddressableKind(), // NIP-71 addressable short video
            content: content,
            tags: tags,
          );

      if (event == null) {
        Log.error(
          'Failed to create and sign video event - createAndSignEvent returned null',
          name: 'VideoEventPublisher',
          category: LogCategory.video,
        );
        return false;
      }

      if (upload.nostrEventId != event.id) {
        await _persistRetryableSignedEvent(upload, event);
      }

      Log.info(
        'Created video event: ${event.id}',
        name: 'VideoEventPublisher',
        category: LogCategory.video,
      );

      // Publish to Nostr relays with retry logic
      Log.info(
        '🚀 Starting relay publication for event ${event.id}',
        name: 'VideoEventPublisher',
        category: LogCategory.video,
      );

      final publishResult = await publishSignedVideoEvent(
        upload: upload,
        event: event,
        isRetry: reusedEvent != null,
      );

      if (publishResult) {
        final shouldAddToDiscoveryCache =
            replyContext == null || addReplyToFeed;
        if (_videoEventService != null && shouldAddToDiscoveryCache) {
          try {
            final videoEvent = VideoEvent.fromNostrEvent(event);
            _videoEventService.addVideoEvent(videoEvent);
            Log.info(
              'Added confirmed video to discovery cache: ${event.id}',
              name: 'VideoEventPublisher',
              category: LogCategory.video,
            );
          } catch (e) {
            Log.warning(
              'Failed to add confirmed video to discovery cache: $e',
              name: 'VideoEventPublisher',
              category: LogCategory.video,
            );
          }
        }

        // Update upload status
        await _uploadManager.updateUploadStatus(
          upload.id,
          UploadStatus.published,
          nostrEventId: event.id,
        );

        _totalEventsPublished++;
        _lastPublishTime = DateTime.now();

        // Note: Discovery cache was already updated immediately after event
        // creation (before relay publish) for instant local UI feedback.

        // Invalidate profile stats cache so video count updates immediately
        final currentPubkey = _nostrService.publicKey;
        if (currentPubkey.isNotEmpty) {
          unawaited(_profileStatsDao?.deleteStats(currentPubkey));
          Log.debug(
            'Invalidated profile stats cache for new video',
            name: 'VideoEventPublisher',
            category: LogCategory.video,
          );
        }

        Log.info(
          'Successfully published direct upload: ${event.id}',
          name: 'VideoEventPublisher',
          category: LogCategory.video,
        );
        Log.debug(
          'Video URL: ${upload.cdnUrl}',
          name: 'VideoEventPublisher',
          category: LogCategory.video,
        );

        return true;
      } else {
        Log.error(
          'Failed to publish to Nostr relays',
          name: 'VideoEventPublisher',
          category: LogCategory.video,
        );
        return false;
      }
    } catch (e, stackTrace) {
      Log.error(
        'Error publishing direct upload: $e',
        name: 'VideoEventPublisher',
        category: LogCategory.video,
      );
      Log.verbose(
        '📱 Stack trace: $stackTrace',
        name: 'VideoEventPublisher',
        category: LogCategory.video,
      );
      _totalEventsFailed++;
      return false;
    }
  }

  /// Republish a video event with an added text-track tag for subtitles.
  ///
  /// Takes the existing video event's original tags, adds a text-track tag
  /// referencing the subtitle event, and publishes the updated event.
  /// Returns true if publishing succeeded.
  Future<bool> republishWithSubtitles({
    required VideoEvent existingEvent,
    required String textTrackRef,
    String textTrackLang = 'en',
  }) async {
    // Start from the original Nostr event tags
    final tags = existingEvent.nostrEventTags
        .where((t) => t.isNotEmpty && t.first != 'text-track')
        .map(List<String>.from)
        .toList();

    // Add the new text-track tag
    tags.add([
      'text-track',
      textTrackRef,
      'wss://relay.divine.video',
      'captions',
      textTrackLang,
    ]);

    // Sign the updated event
    final event = await _authService?.createAndSignEvent(
      kind: NIP71VideoKinds.getPreferredAddressableKind(),
      content: existingEvent.content,
      tags: tags,
    );

    if (event == null) {
      Log.error(
        'Failed to sign republished event with subtitles',
        name: 'VideoEventPublisher',
        category: LogCategory.video,
      );
      return false;
    }

    // Publish to relays before updating local cache. A WebSocket send is not
    // enough here; rejected subtitle republishes must not appear locally.
    final published = await _publishEventToNostr(event);
    if (!published) return false;

    try {
      _videoEventService?.addVideoEvent(VideoEvent.fromNostrEvent(event));
    } catch (e) {
      Log.warning(
        'Failed to update local cache after subtitle republish: $e',
        name: 'VideoEventPublisher',
        category: LogCategory.video,
      );
    }

    return true;
  }

  /// Check if a URL is a valid HTTP/HTTPS URL (not a local file path)
  static bool _isHttpUrl(String? url) {
    if (url == null || url.isEmpty) return false;
    return url.startsWith('http://') || url.startsWith('https://');
  }

  void _addIdentityDiscoveryTags(
    List<List<String>> tags,
    NativeProofData nativeProof,
  ) {
    if (_hasCreatorBinding(nativeProof)) {
      tags.add(['identity_binding', 'nostr_creator']);
    }

    if (_hasPortableIdentity(nativeProof)) {
      tags.add(['identity_portable', 'cawg']);
    }

    final verifier = _extractIdentityVerifier(
      nativeProof.verifiedIdentityBundleJson,
    );
    if (verifier != null && verifier.isNotEmpty) {
      tags.add(['identity_verifier', verifier]);
    }
  }

  bool _hasCreatorBinding(NativeProofData nativeProof) {
    return (nativeProof.creatorBindingAssertionLabel?.isNotEmpty ?? false) ||
        (nativeProof.creatorBindingPayloadJson?.isNotEmpty ?? false);
  }

  bool _hasPortableIdentity(NativeProofData nativeProof) {
    return nativeProof.cawgIdentityAssertionLabel == 'cawg.identity' ||
        (nativeProof.verifiedIdentityBundleJson?.isNotEmpty ?? false);
  }

  String? _extractIdentityVerifier(String? verifiedIdentityBundleJson) {
    if (verifiedIdentityBundleJson == null ||
        verifiedIdentityBundleJson.isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(verifiedIdentityBundleJson);
      if (decoded is Map) {
        return decoded['issuer']?.toString();
      }
    } catch (error) {
      Log.warning(
        'Failed to parse verifier identity bundle: $error',
        name: 'VideoEventPublisher',
        category: LogCategory.video,
      );
    }

    return null;
  }

  void dispose() {
    Log.debug(
      'Disposing VideoEventPublisher',
      name: 'VideoEventPublisher',
      category: LogCategory.video,
    );
  }
}
