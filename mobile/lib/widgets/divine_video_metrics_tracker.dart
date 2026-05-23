// ABOUTME: Widget that tracks native DivineVideoPlayerController playback metrics
// ABOUTME: Publishes view analytics for native InfiniteVideoFeed playback sessions

import 'dart:async';

import 'package:divine_video_player/divine_video_player.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart' hide LogCategory;
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/services/analytics_service.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/seen_videos_service.dart';
import 'package:openvine/services/view_event_publisher.dart'
    show ViewTrafficSource;
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
  int _loopCount = 0;
  bool _hasTrackedView = false;
  bool _hasSentEndEvent = false;
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
    if (_lastPosition != null &&
        position < _lastPosition! &&
        position < const Duration(seconds: 1) &&
        duration > Duration.zero &&
        _lastPosition!.inMilliseconds > duration.inMilliseconds - 1000) {
      _loopCount++;
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
    if (!_hasTrackedView || _hasSentEndEvent) return;
    if (_viewStartTime == null) return;

    if (_isPlaying && _lastPlayStartTime != null) {
      _totalWatchDuration += widget._clock().difference(_lastPlayStartTime!);
      _lastPlayStartTime = null;
    }
    _isPlaying = false;

    final video = finalizedVideo ?? widget.video;
    _publishEvents(video);
  }

  void _publishEvents(VideoEvent video) {
    if (_hasSentEndEvent) return;
    if (_totalWatchDuration.inSeconds < 1) return;

    Duration? totalDuration;
    try {
      totalDuration = widget.controller?.state.duration;
    } catch (_) {
      totalDuration = null;
    }

    try {
      _analyticsService.trackDetailedVideoViewWithUser(
        video,
        userId: _authService.currentPublicKeyHex,
        source: 'mobile',
        eventType: 'view_end',
        watchDuration: _totalWatchDuration,
        totalDuration: totalDuration,
        loopCount: _loopCount,
        completedVideo:
            _loopCount > 0 ||
            (totalDuration != null &&
                totalDuration > Duration.zero &&
                _totalWatchDuration.inMilliseconds >=
                    totalDuration.inMilliseconds * 0.9),
        trafficSource: widget.trafficSource,
        sourceDetail: widget.sourceDetail,
      );

      _seenVideosService.recordVideoView(
        video.id,
        loopCount: _loopCount,
        watchDuration: _totalWatchDuration,
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

  void _resetTracking() {
    _viewStartTime = null;
    _lastPlayStartTime = null;
    _totalWatchDuration = Duration.zero;
    _lastPosition = null;
    _loopCount = 0;
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
