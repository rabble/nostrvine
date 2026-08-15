// ABOUTME: Widget that tracks native DivineVideoPlayerController playback metrics
// ABOUTME: Publishes view analytics for native InfiniteVideoFeed playback sessions

import 'dart:async';

import 'package:divine_video_player/divine_video_player.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart' hide LogCategory;
import 'package:openvine/models/view_traffic_source.dart'
    show ViewTrafficSource;
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/services/analytics_service.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/seen_videos_service.dart';
import 'package:unified_logger/unified_logger.dart';
import 'package:uuid/uuid.dart';

class DivineVideoMetricsTracker extends ConsumerStatefulWidget {
  const DivineVideoMetricsTracker({
    required this.video,
    required this.controller,
    required this.isActive,
    required this.child,
    this.isFeedVisible = true,
    this.trafficSource = ViewTrafficSource.unknown,
    this.sourceDetail,
    @visibleForTesting DateTime Function()? clock,
    super.key,
  }) : _clock = clock ?? DateTime.now;

  final VideoEvent video;
  final DivineVideoPlayerController? controller;

  /// Whether this item is the one the feed is showing (scroll position).
  final bool isActive;

  /// Whether the feed itself is visible — false when a sheet or route covers
  /// it, the tab is switched, or the app is backgrounded.
  ///
  /// Kept separate from [isActive] because the two mean different things for
  /// a viewing session: scrolling away ends it, a cover only interrupts it.
  /// Defaults to true for hosts that have no cover concept.
  final bool isFeedVisible;

  final Widget child;
  final ViewTrafficSource trafficSource;
  final String? sourceDetail;
  final DateTime Function() _clock;

  @override
  ConsumerState<DivineVideoMetricsTracker> createState() =>
      _DivineVideoMetricsTrackerState();
}

class _DivineVideoMetricsTrackerState
    extends ConsumerState<DivineVideoMetricsTracker> {
  bool get _isTracking => widget.isActive && widget.isFeedVisible;

  /// Identifies this mount's viewing session so the view_start dedupe in
  /// AnalyticsService suppresses double-fires within a session but lets a
  /// remount re-watch report its own start.
  String? _sessionToken;

  /// Whether playback has actually started at least once in this session.
  /// The view is counted at that moment, not at mount: a scroll-past that
  /// never reached playback starts no session and reports nothing.
  bool _hasStartedPlayback = false;
  bool _hasRecordedImpression = false;

  /// Mount time, kept for the seen-impression's elapsed-since-active gate.
  DateTime? _mountedAt;

  DateTime? _playIntervalStartedAt;
  bool _isPlaying = false;

  /// Cumulative watch time / completed-pass wraps for the session, and the
  /// amounts already flushed with an end event. An end segment reports the
  /// delta between them, so interrupting a session (comment sheet, tab
  /// switch) flushes one segment without ending the session — nothing
  /// accumulated after the interruption is lost.
  Duration _watchTotal = Duration.zero;

  /// Whole seconds already reported across this session's end segments.
  /// The wire format is whole seconds, so the remainder has to carry across
  /// flushes: truncating each segment independently would lose up to a
  /// second *per interruption* and drop sub-second segments entirely.
  int _watchSecondsReported = 0;
  double _wrapsTotal = 0;

  /// Cumulative loops already reported in an end segment, and the rounded
  /// loop total already handed to [SeenVideosService]. Both are cumulative
  /// so a segment reports the delta and the two never double-credit.
  double _loopsFlushed = 0;
  int _seenLoopsRecorded = 0;
  Duration _seenWatchRecorded = Duration.zero;

  Duration? _lastPosition;

  /// Last duration the player reported. Read at flush time in preference to
  /// the controller, which may already be serving the next video.
  Duration? _lastKnownDuration;

  StreamSubscription<DivineVideoPlayerState>? _stateSubscription;

  late AnalyticsService _analyticsService;
  ProviderSubscription<AnalyticsService>? _analyticsServiceSubscription;
  late AuthService _authService;
  late SeenVideosService _seenVideosService;

  @override
  void initState() {
    super.initState();
    _analyticsService = ref.read(analyticsServiceProvider);
    _analyticsServiceSubscription = ref.listenManual<AnalyticsService>(
      analyticsServiceProvider,
      (_, next) => _analyticsService = next,
    );
    _authService = ref.read(authServiceProvider);
    _seenVideosService = ref.read(seenVideosServiceProvider);
    if (_isTracking) _startTracking();
  }

  @override
  void didUpdateWidget(DivineVideoMetricsTracker oldWidget) {
    super.didUpdateWidget(oldWidget);

    final videoChanged = oldWidget.video.id != widget.video.id;
    final controllerChanged = oldWidget.controller != widget.controller;
    final wasTracking = oldWidget.isActive && oldWidget.isFeedVisible;
    final becameInactive = wasTracking && !_isTracking;
    final becameActive = !wasTracking && _isTracking;

    if (videoChanged) {
      _flushSegment(oldWidget.video);
      _resetTracking();
    } else if (becameInactive) {
      // Either way the visible segment ends, so report the delta so far.
      _flushSegment(widget.video);
      if (!widget.isActive) {
        // Scrolled away. The session is over; scrolling back is a fresh
        // watch and must count its own view (#7231).
        _resetViewSession();
      }
      // Otherwise the item is still current and only the feed was covered
      // (comment sheet, route push, tab switch, backgrounding). The session
      // stays alive so watch time after the cover lifts is still counted
      // against it rather than dropped (#7243).
    }

    if (controllerChanged || videoChanged || becameInactive) {
      unawaited(_stateSubscription?.cancel());
      _stateSubscription = null;
    }

    if (_isTracking && (videoChanged || becameActive || controllerChanged)) {
      _startTracking();
    }
  }

  void _startTracking() {
    final controller = widget.controller;
    if (controller == null) return;

    _mountedAt ??= widget._clock();
    _subscribeToController(controller);

    try {
      _handleState(controller.state);
    } catch (e) {
      Log.warning(
        'DivineVideoMetricsTracker: controller state unavailable - $e',
        name: 'DivineVideoMetricsTracker',
        category: LogCategory.video,
      );
    }
  }

  void _subscribeToController(DivineVideoPlayerController controller) {
    unawaited(_stateSubscription?.cancel());
    _stateSubscription = controller.stateStream.listen(
      _handleState,
      onError: (Object error) {
        Log.warning(
          'DivineVideoMetricsTracker: state stream error - $error',
          name: 'DivineVideoMetricsTracker',
          category: LogCategory.video,
        );
      },
    );
  }

  void _handleState(DivineVideoPlayerState state) {
    if (!widget.isActive) return;

    final now = widget._clock();
    if (state.isPlaying && !_isPlaying) {
      _isPlaying = true;
      _playIntervalStartedAt = now;
      _onPlaybackStarted();
    } else if (!state.isPlaying && _isPlaying) {
      _closePlayInterval(now);
    }

    final position = state.position;
    final duration = state.duration;
    if (duration > Duration.zero) _lastKnownDuration = duration;

    // Count completed loops via position wrap-around. Only meaningful once a
    // session has started; a stale pre-session position must not fabricate
    // one.
    if (_hasStartedPlayback &&
        _lastPosition != null &&
        position < _lastPosition! &&
        position < const Duration(seconds: 1) &&
        duration > Duration.zero &&
        _lastPosition!.inMilliseconds > duration.inMilliseconds - 1000) {
      _wrapsTotal += 1;
    }
    _lastPosition = position;
  }

  /// The view is counted here: one start-phase event, fired at the first
  /// real playback of the session and never again for this mount.
  ///
  /// The session token guards only against rapid-fire duplicates inside this
  /// mount — it is in-memory, never transmitted, and the relay does not dedup.
  /// See `AnalyticsService.trackDetailedVideoViewWithUser` for the crash
  /// window this leaves open.
  void _onPlaybackStarted() {
    if (_hasStartedPlayback) return;
    _hasStartedPlayback = true;
    _sessionToken = const Uuid().v4();

    unawaited(
      _analyticsService
          .trackDetailedVideoViewWithUser(
            widget.video,
            userId: _authService.currentPublicKeyHex,
            source: 'mobile',
            eventType: 'view_start',
            sessionToken: _sessionToken,
            trafficSource: widget.trafficSource,
            sourceDetail: widget.sourceDetail,
          )
          .catchError((Object e) {
            Log.warning(
              'Failed to send video start event: $e',
              name: 'DivineVideoMetricsTracker',
              category: LogCategory.video,
            );
          }),
    );
  }

  void _closePlayInterval(DateTime now) {
    final startedAt = _playIntervalStartedAt;
    if (startedAt != null) {
      _watchTotal += now.difference(startedAt);
      _playIntervalStartedAt = null;
    }
    _isPlaying = false;
  }

  /// Flush the watch/loop delta since the last flush as an end-phase event.
  /// Non-terminal by construction: a segment with no new playback emits
  /// nothing, so flush triggers (cover, video change, dispose) can all run
  /// without double-counting.
  void _flushSegment(VideoEvent video) {
    _closePlayInterval(widget._clock());

    Duration? totalDuration = _lastKnownDuration;
    if (totalDuration == null) {
      try {
        totalDuration = widget.controller?.state.duration;
      } catch (_) {
        totalDuration = null;
      }
    }

    _recordSeen(video, totalDuration);

    if (!_hasStartedPlayback) return;

    // Both figures are derived from the session totals and only then split
    // into a delta. Taking a per-segment maximum instead would double-credit
    // at every flush seam: 30s of a 6s video split at 15s would report
    // 2.5 + 3.0 = 5.5 loops. Truncating each segment's seconds independently
    // would lose the remainder at every seam instead of once per session.
    final cumulativeSeconds = _watchTotal.inSeconds;
    final deltaSeconds = cumulativeSeconds - _watchSecondsReported;
    final cumulativeLoops = _cumulativeLoops(totalDuration);
    final fractionalLoops = cumulativeLoops - _loopsFlushed;
    if (deltaSeconds <= 0 && fractionalLoops <= 0) return;

    unawaited(
      _analyticsService
          .trackDetailedVideoViewWithUser(
            video,
            userId: _authService.currentPublicKeyHex,
            source: 'mobile',
            eventType: 'view_end',
            watchDuration: Duration(seconds: deltaSeconds),
            totalDuration: totalDuration,
            loopCount: fractionalLoops,
            completedVideo:
                fractionalLoops >= 1 ||
                (totalDuration != null &&
                    totalDuration > Duration.zero &&
                    deltaSeconds * Duration.millisecondsPerSecond >=
                        totalDuration.inMilliseconds * 0.9),
            trafficSource: widget.trafficSource,
            sourceDetail: widget.sourceDetail,
          )
          .catchError((Object e) {
            Log.warning(
              'Failed to send video end event: $e',
              name: 'DivineVideoMetricsTracker',
              category: LogCategory.video,
            );
          }),
    );

    _watchSecondsReported = cumulativeSeconds;
    _loopsFlushed = cumulativeLoops;
  }

  /// Loops for the whole session so far: counted wrap-arounds, or the
  /// watch-time ratio when that is larger, so a wrap missed across a flush
  /// seam does not lose the pass.
  double _cumulativeLoops(Duration? totalDuration) {
    var loops = _wrapsTotal;
    if (totalDuration != null && totalDuration > Duration.zero) {
      final ratio = _watchTotal.inMilliseconds / totalDuration.inMilliseconds;
      if (ratio > loops) loops = ratio;
    }
    return loops;
  }

  /// Records the seen impression and the watch/loop accrued since the last
  /// record. [SeenVideosService.updateSession] accumulates, so every flush
  /// must contribute its delta — recording only the first one would strand
  /// everything watched after the first interruption.
  void _recordSeen(VideoEvent video, Duration? totalDuration) {
    final mountedAt = _mountedAt;
    if (mountedAt == null) return;
    if (widget._clock().difference(mountedAt) <= Duration.zero) return;

    final deltaWatch = _watchTotal - _seenWatchRecorded;
    // Round the cumulative figure, not each delta, so repeated partial
    // segments cannot each round down to zero and lose the pass.
    final cumulativeSeenLoops = _cumulativeLoops(totalDuration).round();
    final deltaLoops = cumulativeSeenLoops - _seenLoopsRecorded;

    if (_hasRecordedImpression &&
        deltaWatch <= Duration.zero &&
        deltaLoops <= 0) {
      return;
    }

    _hasRecordedImpression = true;
    _seenWatchRecorded = _watchTotal;
    _seenLoopsRecorded = cumulativeSeenLoops;

    unawaited(
      _seenVideosService.recordVideoView(
        video.id,
        loopCount: deltaLoops,
        watchDuration: deltaWatch,
      ),
    );
  }

  void _resetTracking() {
    _resetViewSession();
    _hasRecordedImpression = false;
  }

  /// Clears the viewing session without re-arming the seen impression, which
  /// belongs to the mount rather than to the session.
  void _resetViewSession() {
    _sessionToken = null;
    _hasStartedPlayback = false;
    _mountedAt = _isTracking ? widget._clock() : null;
    _playIntervalStartedAt = null;
    _isPlaying = false;
    _watchTotal = Duration.zero;
    _watchSecondsReported = 0;
    _wrapsTotal = 0;
    _loopsFlushed = 0;
    _seenLoopsRecorded = 0;
    _seenWatchRecorded = Duration.zero;
    _lastPosition = null;
    _lastKnownDuration = null;
  }

  @override
  void dispose() {
    _flushSegment(widget.video);
    unawaited(_stateSubscription?.cancel());
    _analyticsServiceSubscription?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
