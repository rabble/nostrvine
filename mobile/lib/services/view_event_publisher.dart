// ABOUTME: Service for publishing video view events (Kind 22236) to Nostr
// ABOUTME: Tracks video watch time and publishes ephemeral analytics events

import 'package:models/models.dart' hide LogCategory;
import 'package:nostr_client/nostr_client.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/utils/unified_logger.dart';

/// Kind 22236 - Ephemeral video view event (NIP-71 extension)
const int viewEventKind = 22236;

/// Traffic source for video views
enum ViewTrafficSource {
  /// Video viewed from home/following feed
  home,

  /// Video viewed from explore/discovery — new videos tab
  discoveryNew,

  /// Video viewed from explore/discovery — classic vines tab
  discoveryClassic,

  /// Video viewed from explore/discovery — for you (personalized) tab
  discoveryForYou,

  /// Video viewed from explore/discovery — popular videos tab
  discoveryPopular,

  /// Video viewed from a user's profile page
  profile,

  /// Video viewed via shared link
  share,

  /// Video viewed from search results or hashtag feed
  search,

  /// Unknown/unspecified source
  unknown,
}

/// Service for publishing video view events to Nostr relays.
///
/// View events are ephemeral (kind 22236) and are processed by analytics
/// services in real-time. They track watch time, traffic sources, and
/// enable creator analytics and recommendation systems.
class ViewEventPublisher {
  ViewEventPublisher({
    required NostrClient nostrService,
    required AuthService authService,
    String? defaultRelayHint,
  }) : _nostrService = nostrService,
       _authService = authService,
       _defaultRelayHint = defaultRelayHint ?? 'wss://relay.divine.video';

  final NostrClient _nostrService;
  final AuthService _authService;
  final String _defaultRelayHint;

  /// Client identifier for analytics
  static const String _clientId = 'divine-mobile/1.0';

  /// Publish a video view event.
  ///
  /// [video] - The video that was viewed
  /// [startSeconds] - When the viewing started (seconds into video)
  /// [endSeconds] - When the viewing ended (seconds into video)
  /// [source] - Where the video was discovered/viewed from
  ///
  /// Returns true if the event was published successfully.
  Future<bool> publishViewEvent({
    required VideoEvent video,
    required int startSeconds,
    required int endSeconds,
    ViewTrafficSource source = ViewTrafficSource.unknown,
    String? sourceDetail,
    int? loopCount,
  }) async {
    // Skip if no meaningful watch time
    if (endSeconds <= startSeconds) {
      Log.debug(
        'Skipping view event: no watch time (start=$startSeconds, end=$endSeconds)',
        name: 'ViewEventPublisher',
        category: LogCategory.video,
      );
      return false;
    }

    // Skip very short views (less than 1 second)
    if (endSeconds - startSeconds < 1) {
      Log.debug(
        'Skipping view event: less than 1 second watched',
        name: 'ViewEventPublisher',
        category: LogCategory.video,
      );
      return false;
    }

    // Check authentication
    if (!_authService.isAuthenticated) {
      Log.warning(
        'Cannot publish view event: user not authenticated',
        name: 'ViewEventPublisher',
        category: LogCategory.video,
      );
      return false;
    }

    // Skip self-views (relay would reject them anyway)
    if (_authService.currentPublicKeyHex == video.pubkey) {
      Log.debug(
        'Skipping view event: self-view',
        name: 'ViewEventPublisher',
        category: LogCategory.video,
      );
      return false;
    }

    try {
      // Build the addressable coordinate (a tag)
      // Format: "34236:author_pubkey:d_tag"
      // Use event ID as fallback if vineId (d-tag) is null
      final dTag = video.vineId ?? video.id;
      final aTag = '34236:${video.pubkey}:$dTag';

      // Get relay hint
      String relayHint = _defaultRelayHint;
      if (_nostrService.connectedRelays.isNotEmpty) {
        relayHint = _nostrService.connectedRelays.first;
      }

      // Build tags
      final tags = <List<String>>[
        // Addressable reference (required)
        ['a', aTag, relayHint],
        // Event ID reference (required)
        ['e', video.id, relayHint],
        // Watched segment (required)
        ['viewed', startSeconds.toString(), endSeconds.toString()],
        // Traffic source (optional but recommended)
        if (sourceDetail != null && sourceDetail.isNotEmpty)
          ['source', _sourceToString(source), sourceDetail]
        else
          ['source', _sourceToString(source)],
        // Loop count (optional, omitted if 0 or null)
        if (loopCount != null && loopCount > 0) ['loops', loopCount.toString()],
        // Client identifier (optional)
        ['client', _clientId],
      ];

      Log.debug(
        'Publishing view event for video ${video.id}',
        name: 'ViewEventPublisher',
        category: LogCategory.video,
      );
      Log.verbose(
        'View data: watched ${endSeconds - startSeconds}s, source=${_sourceToString(source)}',
        name: 'ViewEventPublisher',
        category: LogCategory.video,
      );

      // Create and sign the ephemeral event
      final event = await _authService.createAndSignEvent(
        kind: viewEventKind,
        content: '',
        tags: tags,
      );

      if (event == null) {
        Log.error(
          'Failed to create view event: createAndSignEvent returned null',
          name: 'ViewEventPublisher',
          category: LogCategory.video,
        );
        return false;
      }

      // Publish to relays (fire-and-forget for ephemeral events)
      final sentEvent = await _nostrService.publishEvent(event);

      if (sentEvent != null) {
        Log.info(
          'View event published: video=${video.id}, watched=${endSeconds - startSeconds}s',
          name: 'ViewEventPublisher',
          category: LogCategory.video,
        );
        return true;
      } else {
        Log.warning(
          'View event publish failed for video ${video.id}',
          name: 'ViewEventPublisher',
          category: LogCategory.video,
        );
        return false;
      }
    } catch (e) {
      Log.error(
        'Error publishing view event: $e',
        name: 'ViewEventPublisher',
        category: LogCategory.video,
      );
      return false;
    }
  }

  /// Publish view event for multiple watched segments.
  ///
  /// Use this when the user watched multiple non-contiguous segments
  /// of the video (e.g., skipped around).
  Future<bool> publishViewEventWithSegments({
    required VideoEvent video,
    required List<(int, int)> segments,
    ViewTrafficSource source = ViewTrafficSource.unknown,
    String? sourceDetail,
  }) async {
    // Filter out invalid segments
    final validSegments = segments
        .where((s) => s.$2 > s.$1 && s.$2 - s.$1 >= 1)
        .toList();

    if (validSegments.isEmpty) {
      Log.debug(
        'Skipping view event: no valid segments',
        name: 'ViewEventPublisher',
        category: LogCategory.video,
      );
      return false;
    }

    if (!_authService.isAuthenticated) {
      Log.warning(
        'Cannot publish view event: user not authenticated',
        name: 'ViewEventPublisher',
        category: LogCategory.video,
      );
      return false;
    }

    // Skip self-views (relay would reject them anyway)
    if (_authService.currentPublicKeyHex == video.pubkey) {
      Log.debug(
        'Skipping view event: self-view (segments)',
        name: 'ViewEventPublisher',
        category: LogCategory.video,
      );
      return false;
    }

    try {
      final dTag = video.vineId ?? video.id;
      final aTag = '34236:${video.pubkey}:$dTag';

      String relayHint = _defaultRelayHint;
      if (_nostrService.connectedRelays.isNotEmpty) {
        relayHint = _nostrService.connectedRelays.first;
      }

      // Build tags with multiple viewed segments
      final tags = <List<String>>[
        ['a', aTag, relayHint],
        ['e', video.id, relayHint],
        // Add all valid segments
        for (final segment in validSegments)
          ['viewed', segment.$1.toString(), segment.$2.toString()],
        if (sourceDetail != null && sourceDetail.isNotEmpty)
          ['source', _sourceToString(source), sourceDetail]
        else
          ['source', _sourceToString(source)],
        ['client', _clientId],
      ];

      final event = await _authService.createAndSignEvent(
        kind: viewEventKind,
        content: '',
        tags: tags,
      );

      if (event == null) {
        return false;
      }

      final sentEvent = await _nostrService.publishEvent(event);

      if (sentEvent != null) {
        final totalWatched = validSegments.fold<int>(
          0,
          (sum, s) => sum + (s.$2 - s.$1),
        );
        Log.info(
          'View event published: video=${video.id}, segments=${validSegments.length}, total=${totalWatched}s',
          name: 'ViewEventPublisher',
          category: LogCategory.video,
        );
        return true;
      }
      return false;
    } catch (e) {
      Log.error(
        'Error publishing multi-segment view event: $e',
        name: 'ViewEventPublisher',
        category: LogCategory.video,
      );
      return false;
    }
  }

  /// Convert traffic source enum to string for the tag.
  String _sourceToString(ViewTrafficSource source) {
    return switch (source) {
      ViewTrafficSource.home => 'home',
      ViewTrafficSource.discoveryNew => 'discovery:new',
      ViewTrafficSource.discoveryClassic => 'discovery:classic',
      ViewTrafficSource.discoveryForYou => 'discovery:foryou',
      ViewTrafficSource.discoveryPopular => 'discovery:popular',
      ViewTrafficSource.profile => 'profile',
      ViewTrafficSource.share => 'share',
      ViewTrafficSource.search => 'search',
      ViewTrafficSource.unknown => 'unknown',
    };
  }
}
