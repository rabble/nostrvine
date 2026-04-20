// ABOUTME: Abstract base class providing shared event publishing patterns for social event services
// ABOUTME: Handles event creation, signing, publishing, and caching with consistent error handling

import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/personal_event_cache_service.dart';

/// Base class for services that publish and manage social events
/// (reactions, reposts, etc).
///
/// Provides shared patterns for event lifecycle:
/// create → sign → publish-with-retry → cache.
///
/// The publish path routes through [NostrClient.publishEventWithRetry]
/// so subclasses benefit from bounded retry on transient relay failures
/// and can inspect per-relay NIP-20 OK state via the returned
/// [PublishOutcome].
abstract class SocialEventServiceBase {
  /// Nostr service for broadcasting events to relays
  NostrClient get nostrService;

  /// Auth service for creating and signing events
  AuthService get authService;

  /// Optional cache for storing user's own events locally
  PersonalEventCacheService? get personalEventCache;

  /// Publishes [event] to relays with retry and caches it locally on
  /// [PublishOutcome.acceptedByAny].
  ///
  /// Throws [Exception] if no relay accepted. The caller can inspect
  /// the outcome via [broadcastAndCacheEventAwaitOk] if finer-grained
  /// feedback is required.
  Future<String> broadcastAndCacheEvent(Event event) async {
    final outcome = await broadcastAndCacheEventAwaitOk(event);
    if (!outcome.acceptedByAny) {
      final feedback = PublishResultMapper.map(outcome);
      throw Exception(
        'Failed to publish event to relays '
        '(retryable=${feedback.retryable} '
        'reason=${feedback.firstRejectionReason ?? 'n/a'})',
      );
    }
    return event.id;
  }

  /// Publishes [event] via [NostrClient.publishEventWithRetry] and, on
  /// any relay acceptance, caches the event locally for
  /// same-device continuity.
  ///
  /// Returns the full [PublishOutcome] so callers can thread the
  /// per-relay result through a typed `Result` type or UI snackbar via
  /// [PublishResultMapper].
  Future<PublishOutcome> broadcastAndCacheEventAwaitOk(Event event) async {
    final outcome = await nostrService.publishEventWithRetry(event);
    if (outcome.acceptedByAny) {
      personalEventCache?.cacheUserEvent(event);
    }
    return outcome;
  }

  /// Creates, signs, broadcasts (with retry), and caches an event in one
  /// atomic operation.
  ///
  /// Throws [Exception] if creation, signing, or publish fails.
  Future<String> createSignBroadcastAndCache({
    required int kind,
    required String content,
    required List<List<String>> tags,
  }) async {
    final event = await authService.createAndSignEvent(
      kind: kind,
      content: content,
      tags: tags,
    );

    if (event == null) {
      throw Exception('Failed to create and sign event');
    }

    return broadcastAndCacheEvent(event);
  }

  /// Publishes a deletion event (Kind 5) for the target event.
  ///
  /// Throws [Exception] if deletion event creation or broadcast fails.
  Future<void> publishDeletionEvent(String targetEventId) async {
    await createSignBroadcastAndCache(
      kind: 5,
      content: 'Deleted',
      tags: [
        ['e', targetEventId],
      ],
    );
  }
}
