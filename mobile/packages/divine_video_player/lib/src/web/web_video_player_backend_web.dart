// Web-only implementation. Imports `dart:ui_web` and `package:web`, so this
// file MUST only be reachable from a conditional import gated on
// `dart.library.js_interop`.

import 'dart:async';
import 'dart:js_interop';
import 'dart:math' as math;
import 'dart:ui_web' as ui_web;

import 'package:divine_video_player/src/audio_track.dart' as divine;
import 'package:divine_video_player/src/video_clip.dart';
import 'package:divine_video_player/src/video_player_state.dart';
import 'package:divine_video_player/src/web/web_video_player_backend.dart';
import 'package:flutter/widgets.dart';
import 'package:unified_logger/unified_logger.dart';
import 'package:web/web.dart' as web;

/// Web backend powered by an `<video>` element rendered through
/// `HtmlElementView`.
///
/// Limitations: multi-clip playback, subrange clipping, overlay audio tracks,
/// and [jumpToClip] beyond index 0 are no-ops (video-editor features not
/// supported on web). `rotationDegrees` is always `0`.
class HtmlVideoElementBackend implements WebVideoPlayerBackend {
  /// Creates a web backend that owns its own `<video>` element.
  HtmlVideoElementBackend() : _viewType = _nextViewType();

  static int _viewTypeCounter = 0;
  static String _nextViewType() {
    _viewTypeCounter += 1;
    return 'divine_video_player_view_$_viewTypeCounter';
  }

  // Lookup table that lets the registered view-factory closure resolve the
  // current element without capturing `this`. Entries are removed on dispose,
  // but the platform-view factory itself remains registered for the session
  // because `platformViewRegistry` does not expose an unregister API.
  static final Map<String, web.HTMLVideoElement> _elementRegistry = {};

  final String _viewType;
  late web.HTMLVideoElement _videoElement;
  final List<StreamSubscription<web.Event>> _subscriptions =
      <StreamSubscription<web.Event>>[];

  void Function(DivineVideoPlayerState state)? _onStateChanged;
  void Function(Object error)? _onError;

  DivineVideoPlayerState _state = const DivineVideoPlayerState();
  bool _initialized = false;
  bool _disposed = false;
  bool _didLogUnsupportedMultiClip = false;
  bool _didLogUnsupportedAudioTrack = false;

  // Subrange handling: when a clip has a non-zero start we apply it as the
  // initial seek. We track the start offset to translate browser
  // `currentTime` back to the player's global timeline.
  Duration _clipStart = Duration.zero;
  Duration? _clipEnd;

  /// Exposes the owned video element to browser tests.
  ///
  /// The production abstraction deliberately hides DOM details, but the web
  /// backend's core behavior is coupled to native `HTMLVideoElement` events.
  @visibleForTesting
  web.HTMLVideoElement get debugVideoElement => _videoElement;

  static web.HTMLVideoElement _createVideoElement() {
    final element = web.document.createElement('video') as web.HTMLVideoElement
      ..autoplay = false
      ..controls = false
      ..playsInline = true
      ..muted = false
      ..preload = 'auto';
    element.style
      ..width = '100%'
      ..height = '100%'
      ..objectFit = 'cover'
      ..backgroundColor = '#000';
    return element;
  }

  static double _toSeconds(Duration d) =>
      d.inMicroseconds / Duration.microsecondsPerSecond;

  @override
  Future<void> initialize({
    required void Function(DivineVideoPlayerState state) onStateChanged,
    required void Function(Object error) onError,
  }) async {
    _onStateChanged = onStateChanged;
    _onError = onError;
    _videoElement = _createVideoElement();
    _registerViewFactory();
    _listenToVideoElement();
    _initialized = true;
  }

  void _registerViewFactory() {
    if (_elementRegistry.containsKey(_viewType)) return;
    _elementRegistry[_viewType] = _videoElement;
    ui_web.platformViewRegistry.registerViewFactory(
      _viewType,
      (int _) => _elementRegistry[_viewType]!,
    );
  }

  void _listenToVideoElement() {
    _subscriptions
      ..add(
        web.EventStreamProviders.loadedMetadataEvent
            .forTarget(_videoElement)
            .listen((_) => _refreshState()),
      )
      ..add(
        web.EventStreamProviders.loadedDataEvent
            .forTarget(_videoElement)
            .listen(
              (_) => _emitState(_state.copyWith(isFirstFrameRendered: true)),
            ),
      )
      ..add(
        web.EventStreamProviders.canPlayEvent
            .forTarget(_videoElement)
            .listen((_) => _refreshState()),
      )
      ..add(
        web.EventStreamProviders.playEvent
            .forTarget(_videoElement)
            .listen((_) => _refreshState()),
      )
      ..add(
        web.EventStreamProviders.playingEvent
            .forTarget(_videoElement)
            .listen((_) => _refreshState()),
      )
      ..add(
        web.EventStreamProviders.pauseEvent
            .forTarget(_videoElement)
            .listen((_) => _refreshState()),
      )
      ..add(
        web.EventStreamProviders.waitingEvent
            .forTarget(_videoElement)
            .listen((_) => _refreshState()),
      )
      ..add(
        web.EventStreamProviders.timeUpdateEvent
            .forTarget(_videoElement)
            .listen((_) => _onTimeUpdate()),
      )
      ..add(
        web.EventStreamProviders.durationChangeEvent
            .forTarget(_videoElement)
            .listen((_) => _refreshState()),
      )
      ..add(
        web.EventStreamProviders.progressEvent
            .forTarget(_videoElement)
            .listen((_) => _refreshState()),
      )
      ..add(
        web.EventStreamProviders.endedEvent
            .forTarget(_videoElement)
            .listen((_) => _onEnded()),
      )
      ..add(
        web.EventStreamProviders.volumeChangeEvent
            .forTarget(_videoElement)
            .listen((_) => _refreshState()),
      )
      ..add(
        web.EventStreamProviders.rateChangeEvent
            .forTarget(_videoElement)
            .listen((_) => _refreshState()),
      )
      ..add(
        web.EventStreamProviders.errorEvent
            .forTarget(_videoElement)
            .listen((_) => _handleVideoError()),
      );
  }

  @override
  Future<void> setClips(
    List<VideoClip> clips, {
    Duration? startPosition,
  }) async {
    _ensureReady();
    if (clips.isEmpty) {
      _videoElement
        ..removeAttribute('src')
        ..load();
      _clipStart = Duration.zero;
      _clipEnd = null;
      _emitState(const DivineVideoPlayerState());
      return;
    }

    if (clips.length > 1 && !_didLogUnsupportedMultiClip) {
      Log.warning(
        'Web backend does not support multi-clip playback; '
        'playing only the first clip.',
        name: 'divine_video_player',
        category: LogCategory.video,
      );
      _didLogUnsupportedMultiClip = true;
    }

    final clip = clips.first;
    _clipStart = clip.start;
    _clipEnd = clip.end;
    final clipVolume = clip.volume.clamp(0.0, 1.0);

    _emitState(
      _state.copyWith(
        status: PlaybackStatus.buffering,
        clipCount: 1,
        currentClipIndex: 0,
        position: Duration.zero,
        bufferedPosition: Duration.zero,
        volume: clipVolume,
        playbackSpeed: clip.playbackSpeed,
        isFirstFrameRendered: false,
        clearError: true,
      ),
    );

    _videoElement
      ..volume = clipVolume
      ..muted = clipVolume == 0
      ..src = clip.uri
      ..load()
      ..playbackRate = clip.playbackSpeed;

    // Apply initial seek: respect the clip's `start`, then layer the
    // controller-supplied `startPosition` on top.
    final globalStart = startPosition ?? Duration.zero;
    final sourceSeek = _clipStart + globalStart;
    if (sourceSeek > Duration.zero) {
      _videoElement.currentTime = _toSeconds(sourceSeek);
    }
  }

  void _onTimeUpdate() {
    // Web: enforce optional clip.end as a soft clamp by pausing when the
    // source-time crosses the end mark.
    final clipEnd = _clipEnd;
    if (clipEnd != null) {
      final endSeconds = _toSeconds(clipEnd);
      if (_videoElement.currentTime >= endSeconds) {
        final clampedPosition = clipEnd > _clipStart
            ? clipEnd - _clipStart
            : Duration.zero;
        if (_videoElement.loop) {
          _videoElement.currentTime = _toSeconds(_clipStart);
          _emitState(
            _state.copyWith(
              status: _videoElement.paused
                  ? PlaybackStatus.paused
                  : PlaybackStatus.playing,
              position: Duration.zero,
            ),
          );
          return;
        }
        _videoElement.pause();
        _emitState(
          _state.copyWith(
            status: PlaybackStatus.completed,
            position: clampedPosition,
          ),
        );
        return;
      }
    }
    _refreshState();
  }

  void _onEnded() {
    if (_videoElement.loop) {
      // Browser will restart the source itself; just refresh state.
      _refreshState();
      return;
    }
    _emitState(_state.copyWith(status: PlaybackStatus.completed));
  }

  @override
  Future<void> play() async {
    _ensureReady();
    try {
      await _videoElement.play().toDart;
    } on Object catch (error) {
      // Common cause: browser autoplay policy. Surface as an error event so
      // the controller can react.
      Log.warning(
        'HTMLVideoElement.play() rejected: $error',
        name: 'divine_video_player',
        category: LogCategory.video,
      );
      _onError?.call(error);
      return;
    }
    _refreshState();
  }

  @override
  Future<void> pause() async {
    _ensureReady();
    _videoElement.pause();
    _refreshState();
  }

  @override
  Future<void> stop() async {
    _ensureReady();
    _videoElement
      ..pause()
      ..removeAttribute('src')
      ..load();
    _clipStart = Duration.zero;
    _clipEnd = null;
    _emitState(const DivineVideoPlayerState());
  }

  @override
  Future<void> seekTo(Duration position) async {
    _ensureReady();
    final clampedPosition = position < Duration.zero ? Duration.zero : position;
    final sourceTime = _clipStart + clampedPosition;
    _videoElement.currentTime = _toSeconds(sourceTime);
    _refreshState();
  }

  @override
  Future<void> setVolume(double volume) async {
    _ensureReady();
    final clamped = volume.clamp(0.0, 1.0);
    _videoElement.volume = clamped;
    // Setting volume to 0 also mutes the element so the browser doesn't
    // un-mute it if the volume is raised again while autoplay policies apply.
    _videoElement.muted = clamped == 0;
    // State is refreshed by the volumechange event listener.
  }

  @override
  Future<void> setPlaybackSpeed(double speed) async {
    _ensureReady();
    _videoElement.playbackRate = speed;
    _emitState(_state.copyWith(playbackSpeed: speed));
  }

  @override
  Future<void> setLooping({required bool looping}) async {
    _ensureReady();
    _videoElement.loop = looping;
    _emitState(_state.copyWith(isLooping: looping));
  }

  @override
  Future<void> jumpToClip(int index) async {
    _ensureReady();
    // Web: only a single clip is loaded. Jumping to any other index is a
    // no-op; jumping to index 0 rewinds to the clip start.
    if (index != 0) return;
    await seekTo(Duration.zero);
  }

  @override
  Future<void> setAudioTracks(List<divine.AudioTrack> tracks) async {
    if (tracks.isEmpty) return;
    _logUnsupportedAudioTrackOperation();
  }

  @override
  Future<void> removeAllAudioTracks() async {
    _logUnsupportedAudioTrackOperation();
  }

  @override
  Future<void> setAudioTrackVolume(int index, double volume) async {
    _logUnsupportedAudioTrackOperation();
  }

  @override
  Widget buildView() {
    _ensureReady();
    return HtmlElementView(viewType: _viewType);
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _elementRegistry.remove(_viewType);
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();
    _videoElement
      ..pause()
      ..removeAttribute('src')
      ..load();
  }

  void _ensureReady() {
    if (_disposed) {
      throw StateError('HtmlVideoElementBackend has been disposed');
    }
    if (!_initialized) {
      throw StateError('HtmlVideoElementBackend has not been initialized');
    }
  }

  void _refreshState() {
    if (_disposed) return;
    final element = _videoElement;
    final positionSeconds = element.currentTime - _toSeconds(_clipStart);
    final position = Duration(
      microseconds: math.max(0, (positionSeconds * 1e6).round()),
    );
    final rawDurationSeconds = element.duration;
    final hasDuration =
        !rawDurationSeconds.isNaN && rawDurationSeconds.isFinite;
    final clipEnd = _clipEnd;
    final effectiveDurationSeconds = clipEnd != null
        ? _toSeconds(clipEnd) - _toSeconds(_clipStart)
        : hasDuration
        ? rawDurationSeconds - _toSeconds(_clipStart)
        : 0.0;
    final duration = Duration(
      microseconds: math.max(0, (effectiveDurationSeconds * 1e6).round()),
    );

    var bufferedPosition = position;
    final buffered = element.buffered;
    if (buffered.length > 0) {
      final lastEnd = buffered.end(buffered.length - 1);
      final bufferedSeconds = lastEnd - _toSeconds(_clipStart);
      bufferedPosition = Duration(
        microseconds: math.max(0, (bufferedSeconds * 1e6).round()),
      );
    }

    PlaybackStatus status;
    if (element.error != null) {
      status = PlaybackStatus.error;
    } else if (element.ended) {
      status = PlaybackStatus.completed;
    } else if (element.paused) {
      status = element.readyState >= 3
          ? PlaybackStatus.paused
          : PlaybackStatus.idle;
    } else if (element.readyState < 3) {
      status = PlaybackStatus.buffering;
    } else {
      status = PlaybackStatus.playing;
    }

    _emitState(
      _state.copyWith(
        status: status,
        position: position,
        duration: duration,
        bufferedPosition: bufferedPosition,
        volume: element.volume,
        playbackSpeed: element.playbackRate,
        isLooping: element.loop,
        videoWidth: element.videoWidth,
        videoHeight: element.videoHeight,
      ),
    );
  }

  void _handleVideoError() {
    final error = _videoElement.error;
    final message = error?.message ?? 'Unknown HTMLVideoElement error';
    Log.error(
      'HTMLVideoElement error: $message',
      name: 'divine_video_player',
      category: LogCategory.video,
    );
    _emitState(_state.copyWith(status: PlaybackStatus.error));
    _onError?.call(StateError(message));
  }

  void _emitState(DivineVideoPlayerState next) {
    _state = next;
    _onStateChanged?.call(next);
  }

  void _logUnsupportedAudioTrackOperation() {
    if (_didLogUnsupportedAudioTrack) return;
    _didLogUnsupportedAudioTrack = true;
    Log.warning(
      'Web backend does not support overlay audio tracks; '
      'setAudioTracks / removeAllAudioTracks / setAudioTrackVolume are no-ops.',
      name: 'divine_video_player',
      category: LogCategory.video,
    );
  }
}
