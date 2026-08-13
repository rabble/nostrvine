// ABOUTME: Service for publishing video view events (Kind 22236) to Nostr
// ABOUTME: Tracks video watch time and publishes ephemeral analytics events

import 'package:models/models.dart' hide LogCategory;
import 'package:nostr_client/nostr_client.dart';
import 'package:openvine/models/view_event_drop_reason.dart';
import 'package:openvine/models/view_traffic_source.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:unified_logger/unified_logger.dart';

/// Kind 22236 - Ephemeral video view event (NIP-71 extension)
const int viewEventKind = 22236;

/// Notified every time a view event is dropped instead of published.
///
/// Wired in the app layer to Crashlytics for structural drops. Injected
/// rather than reached for statically so tests can assert on drops.
typedef ViewEventDropReporter =
    void Function(
      ViewEventDropReason reason, {
      required String videoId,
      required String method,
    });

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
    ViewEventDropReporter? onDrop,
  }) : _nostrService = nostrService,
       _authService = authService,
       _onDrop = onDrop,
       _defaultRelayHint = defaultRelayHint ?? 'wss://relay.divine.video';

  final NostrClient _nostrService;
  final AuthService _authService;
  final String _defaultRelayHint;
  final ViewEventDropReporter? _onDrop;

  /// Records a dropped view event and returns `false` for the caller.
  ///
  /// Every early return in this class routes through here, so a new skip
  /// path cannot be added without declaring whether it is a defect.
  bool _drop(ViewEventDropReason reason, String videoId, String method) {
    Log.debug(
      'View event dropped (${reason.name}) for video $videoId',
      name: 'ViewEventPublisher',
      category: LogCategory.video,
    );
    _onDrop?.call(reason, videoId: videoId, method: method);
    return false;
  }

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
    double? loopCount,
  }) async {
    const method = 'publishViewEvent';
    // View = playback start per 2026-08-13 view/loop spec: any playback
    // start counts, even if the session ends before completing a loop
    // (N=0 loops is valid). Only reject inverted ranges.
    if (endSeconds < startSeconds) {
      return _drop(ViewEventDropReason.belowMinimumWatchTime, video.id, method);
    }

    if (!_authService.isAuthenticated) {
      return _drop(ViewEventDropReason.notAuthenticated, video.id, method);
    }

    try {
      // View events require an addressable video reference.
      final aTag = video.addressableId;
      if (aTag == null) {
        return _drop(
          ViewEventDropReason.missingAddressableDTag,
          video.id,
          method,
        );
      }

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
          ['source', source.tagValue, sourceDetail]
        else
          ['source', source.tagValue],
        // Loop count as playthrough fraction (optional, omitted if null or <= 0).
        // Fractional to preserve partial passes (median 0.75) per spec.
        if (loopCount != null && loopCount > 0) ['loops', loopCount.toString()],
      ];

      Log.debug(
        'Publishing view event for video ${video.id}',
        name: 'ViewEventPublisher',
        category: LogCategory.video,
      );
      Log.verbose(
        'View data: watched ${endSeconds - startSeconds}s, source=${source.tagValue}',
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
        return _drop(ViewEventDropReason.signingFailed, video.id, method);
      }

      // Publish to relays (fire-and-forget for ephemeral events)
      final sentEvent = await _nostrService.publishEvent(event);

      if (sentEvent is PublishSuccess) {
        Log.info(
          'View event published: video=${video.id}, watched=${endSeconds - startSeconds}s',
          name: 'ViewEventPublisher',
          category: LogCategory.video,
        );
        return true;
      } else {
        return _drop(ViewEventDropReason.relayRejected, video.id, method);
      }
    } catch (e) {
      Log.error(
        'Error publishing view event: $e',
        name: 'ViewEventPublisher',
        category: LogCategory.video,
      );
      return _drop(ViewEventDropReason.unexpectedError, video.id, method);
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
    const method = 'publishViewEventWithSegments';
    // Filter out invalid segments. Per view=playback-start spec, any
    // non-inverted segment counts (even <1s / N=0 loops is a valid view).
    final validSegments = segments.where((s) => s.$2 >= s.$1).toList();

    if (validSegments.isEmpty) {
      return _drop(ViewEventDropReason.belowMinimumWatchTime, video.id, method);
    }

    if (!_authService.isAuthenticated) {
      return _drop(ViewEventDropReason.notAuthenticated, video.id, method);
    }

    try {
      final aTag = video.addressableId;
      if (aTag == null) {
        return _drop(
          ViewEventDropReason.missingAddressableDTag,
          video.id,
          method,
        );
      }

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
          ['source', source.tagValue, sourceDetail]
        else
          ['source', source.tagValue],
      ];

      final event = await _authService.createAndSignEvent(
        kind: viewEventKind,
        content: '',
        tags: tags,
      );

      if (event == null) {
        return _drop(ViewEventDropReason.signingFailed, video.id, method);
      }

      final sentEvent = await _nostrService.publishEvent(event);

      if (sentEvent is PublishSuccess) {
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
      return _drop(ViewEventDropReason.relayRejected, video.id, method);
    } catch (e) {
      Log.error(
        'Error publishing multi-segment view event: $e',
        name: 'ViewEventPublisher',
        category: LogCategory.video,
      );
      return _drop(ViewEventDropReason.unexpectedError, video.id, method);
    }
  }
}
