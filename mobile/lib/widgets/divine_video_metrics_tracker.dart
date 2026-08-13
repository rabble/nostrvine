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

class DivineVideoMetricsTracker extends ConsumerStatefulWidget {
  const DivineVideoMetricsTracker({
    required this.video,
    required this.controller,
    required this.isActive,
    required this.child,
    this.trafficSource = ViewTrafficSource.unknown,
    this.sourceDetail,
    @visibleForTesting DateTime Function()? clock,
    super.key,
  }) : _clock = clock ?? DateTime.now;

  final VideoEvent video;
  final DivineVideoPlayerController? controller;
  final bool isActive;
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
  DateTime? _viewStartTime;
  DateTime? _lastPlayStartTime;
  Duration _totalWatchDuration = Duration.zero;
  Duration? _lastPosition;
  double _loopCount = 0;
  bool _hasTrackedView = false;
  bool _hasSentEndEvent = false;
  bool _hasRecordedImpression = false;
  bool _isPlaying = false;
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
    if (widget.isActive) _startTracking();
  }

  @override
  void didUpdateWidget(DivineVideoMetricsTracker oldWidget) {
    super.didUpdateWidget(oldWidget);

    final videoChanged = oldWidget.video.id != widget.video.id;
    final controllerChanged = oldWidget.controller != widget.controller;
    final becameInactive = oldWidget.isActive && !widget.isActive;
    final becameActive = !oldWidget.isActive && widget.isActive;

    if (videoChanged) {
      _finalizeAndPublish(finalizedVideo: oldWidget.video);
      _resetTracking();
    } else if (becameInactive) {
      _finalizeAndPublish();
      _resetViewSession();
    }

    if (controllerChanged || videoChanged || becameInactive) {
      unawaited(_stateSubscription?.cancel());
      _stateSubscription = null;
    }

    if (widget.isActive &&
        (videoChanged || becameActive || controllerChanged)) {
      _startTracking();
    }
  }

  void _startTracking() {
    final controller = widget.controller;
    if (controller == null) return;

    if (!_hasTrackedView) {
      _trackViewStart();
    }

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
    if (!_hasTrackedView || !widget.isActive) return;

    final now = widget._clock();
    if (state.isPlaying && !_isPlaying) {
      _isPlaying = true;
      _lastPlayStartTime = now;
    } else if (!state.isPlaying && _isPlaying) {
      _totalWatchDuration += now.difference(_lastPlayStartTime!);
      _lastPlayStartTime = null;
      _isPlaying = false;
    }

    final position = state.position;
    final duration = state.duration;
    // Count completed loops via position wrap-around. Also track fractional
    // loops — a 4.5s watch of a 6s video is 0.75 loops, which the old int
    // counter would record as 0. The view event sends this as a fraction
    // per the fractional-loops decision.
    if (_lastPosition != null &&
        position < _lastPosition! &&
        position < const Duration(seconds: 1) &&
        duration > Duration.zero &&
        _lastPosition!.inMilliseconds > duration.inMilliseconds - 1000) {
      _loopCount += 1;
    }
    _lastPosition = position;
  }

  void _trackViewStart() {
    _viewStartTime = widget._clock();
    _hasTrackedView = true;
    _hasSentEndEvent = false;

    _analyticsService.trackDetailedVideoViewWithUser(
      widget.video,
      userId: _authService.currentPublicKeyHex,
      source: 'mobile',
      eventType: 'view_start',
    );
  }

  void _finalizeAndPublish({VideoEvent? finalizedVideo}) {
    if (!_hasTrackedView) return;
    if (_hasSentEndEvent && _hasRecordedImpression) return;
    final viewStartTime = _viewStartTime;
    if (viewStartTime == null) return;

    if (_isPlaying && _lastPlayStartTime != null) {
      _totalWatchDuration += widget._clock().difference(_lastPlayStartTime!);
      _lastPlayStartTime = null;
    }
    _isPlaying = false;

    final video = finalizedVideo ?? widget.video;
    final activeDuration = widget._clock().difference(viewStartTime);
    _publishEvents(video, activeDuration: activeDuration);
  }

  void _publishEvents(VideoEvent video, {required Duration activeDuration}) {
    Duration? totalDuration;
    try {
      totalDuration = widget.controller?.state.duration;
    } catch (_) {
      totalDuration = null;
    }

    // Compute fractional loops for this session. Integer wrap-arounds are
    // already in _loopCount; add the fractional remainder for views that
    // never completed a full pass. This ensures a 4.5s watch of a 6s video
    // reports 0.75 rather than 0 — the median case that flooring would zero.
    var fractionalLoops = _loopCount;
    if (totalDuration != null &&
        totalDuration > Duration.zero &&
        _totalWatchDuration > Duration.zero) {
      final fractional =
          _totalWatchDuration.inMilliseconds / totalDuration.inMilliseconds;
      // Take the larger of counted wrap-arounds vs time ratio to handle
      // cases where wrap detection missed a transition.
      if (fractional > fractionalLoops) fractionalLoops = fractional;
    }

    if (!_hasSentEndEvent &&
        _hasTrackedView &&
        _totalWatchDuration > Duration.zero) {
      // View = playback start: every session needs real playback
      // (not just mount time). Gating on _totalWatchDuration drops the
      // never-played case (isPlaying never true) while still counting
      // sub-second flings (400ms of real playback is a view).
      try {
        _analyticsService.trackDetailedVideoViewWithUser(
          video,
          userId: _authService.currentPublicKeyHex,
          source: 'mobile',
          eventType: 'view_end',
          watchDuration: _totalWatchDuration,
          totalDuration: totalDuration,
          loopCount: fractionalLoops,
          completedVideo:
              fractionalLoops >= 1 ||
              (totalDuration != null &&
                  totalDuration > Duration.zero &&
                  _totalWatchDuration.inMilliseconds >=
                      totalDuration.inMilliseconds * 0.9),
          trafficSource: widget.trafficSource,
          sourceDetail: widget.sourceDetail,
        );

        _hasSentEndEvent = true;
      } catch (e) {
        Log.warning(
          'Failed to send video end event: $e',
          name: 'DivineVideoMetricsTracker',
          category: LogCategory.video,
        );
      }
    }

    if (!_hasRecordedImpression && activeDuration > Duration.zero) {
      _hasRecordedImpression = true;
      unawaited(
        _seenVideosService.recordVideoView(
          video.id,
          loopCount: fractionalLoops.round(),
          watchDuration: _totalWatchDuration,
        ),
      );
    }
  }

  void _resetTracking() {
    _resetViewSession();
    _hasRecordedImpression = false;
  }

  void _resetViewSession() {
    _viewStartTime = null;
    _lastPlayStartTime = null;
    _totalWatchDuration = Duration.zero;
    _lastPosition = null;
    _loopCount = 0.0;
    _hasTrackedView = false;
    _hasSentEndEvent = false;
    _isPlaying = false;
  }

  @override
  void dispose() {
    _finalizeAndPublish();
    unawaited(_stateSubscription?.cancel());
    _analyticsServiceSubscription?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
