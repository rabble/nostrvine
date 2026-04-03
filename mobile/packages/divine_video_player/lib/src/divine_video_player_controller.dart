import 'dart:async';
import 'dart:developer' as developer;

import 'package:divine_video_player/src/audio_track.dart';
import 'package:divine_video_player/src/video_clip.dart';
import 'package:divine_video_player/src/video_player_state.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Default maximum cache size on disk (500 MB).
const int kDefaultCacheMaxSizeBytes = 500 * 1024 * 1024;

/// Controls a native multi-clip video player that treats multiple clips
/// as a single continuous timeline.
///
/// Usage:
/// ```dart
/// final controller = DivineVideoPlayerController();
/// await controller.initialize();
/// await controller.setSource(VideoClip(uri: '/path/to/video.mp4'));
/// await controller.play();
/// // ...
/// await controller.dispose();
/// ```
class DivineVideoPlayerController {
  /// Creates a controller. Call [initialize] before using playback methods.
  ///
  /// When [useTexture] is `true` the native side renders frames into a
  /// Flutter texture instead of a platform view. This allows Flutter
  /// widgets like `ColorFiltered` to affect the video pixels — required
  /// on iOS/macOS where `UiKitView`/`AppKitView` are composited as
  /// separate `CALayer`s that bypass Flutter's rendering pipeline.
  /// Defaults to `false` (platform view).
  DivineVideoPlayerController({this.useTexture = false});

  /// Whether this player renders via a Flutter texture instead of a
  /// platform view. When `true` the widget should use the [Texture]
  /// widget with [textureId].
  final bool useTexture;

  static const _globalChannel = MethodChannel('divine_video_player');
  static int _nextId = 0;

  /// The next player ID that will be assigned by [initialize].
  ///
  /// Exposed so tests can set up mock channels before calling
  /// [initialize].
  @visibleForTesting
  static int get nextId => _nextId;

  /// Resets the player ID counter to 0.
  ///
  /// Call in test `setUp` to make IDs deterministic regardless of
  /// test ordering.
  @visibleForTesting
  static void resetIdCounterForTesting() => _nextId = 0;

  /// Configures the native video cache.
  ///
  /// Call once at app startup before creating any controllers.
  /// On Android this sets up ExoPlayer's disk-backed `SimpleCache`
  /// that allows progressive caching (stream and cache simultaneously).
  /// On iOS/macOS it configures the shared `URLCache` disk capacity.
  ///
  /// [maxSizeBytes] is the maximum cache size on disk. Defaults to
  /// [kDefaultCacheMaxSizeBytes] (500 MB). Least-recently-used entries
  /// are evicted automatically when the cache is full.
  ///
  /// ```dart
  /// void main() async {
  ///   WidgetsFlutterBinding.ensureInitialized();
  ///   await DivineVideoPlayerController.configureCache();
  ///   runApp(MyApp());
  /// }
  /// ```
  static Future<void> configureCache({
    int maxSizeBytes = kDefaultCacheMaxSizeBytes,
  }) {
    return _globalChannel.invokeMethod<void>(
      'configureCache',
      {'maxSizeBytes': maxSizeBytes},
    );
  }

  /// Pre-loads video metadata and initial buffer data into the native
  /// cache without creating a player instance.
  ///
  /// Call this for upcoming videos (e.g. the next item in a feed) so
  /// that playback starts instantly when the user reaches them.
  /// No controller needs to be alive — the work happens on the native
  /// side and the OS-level cache retains the result.
  ///
  /// ```dart
  /// await DivineVideoPlayerController.preload([
  ///   VideoClip.network('https://example.com/next.mp4'),
  /// ]);
  /// ```
  static Future<void> preload(List<VideoClip> clips) {
    return _globalChannel.invokeMethod<void>(
      'preload',
      {'clips': clips.map((c) => c.toMap()).toList()},
    );
  }

  late final int _playerId;
  late final MethodChannel _methodChannel;
  late final EventChannel _eventChannel;

  final _stateController = StreamController<DivineVideoPlayerState>.broadcast();

  StreamSubscription<dynamic>? _eventSubscription;

  var _state = const DivineVideoPlayerState();
  var _initialized = false;
  var _disposed = false;
  var _firstFrameCompleter = Completer<bool>();

  /// The texture ID returned by the native side when [useTexture] is
  /// `true`. `null` when using platform views.
  int? _textureId;

  /// The texture ID for use with the [Texture] widget.
  ///
  /// Only non-null after [initialize] completes when [useTexture] is
  /// `true`.
  int? get textureId => _textureId;

  /// The current player state.
  DivineVideoPlayerState get state => _state;

  /// Stream of player state updates.
  ///
  /// Emits whenever position, status, or clip index changes.
  Stream<DivineVideoPlayerState> get stateStream => _stateController.stream;

  /// Completes when the first video frame has been rendered to the
  /// native surface.
  ///
  /// Resets each time [setClips] or [setSource] loads new media.
  /// Safe to await multiple times — a completed future stays completed
  /// until the next source change.
  Future<bool> get firstFrameRendered => _firstFrameCompleter.future;

  /// Whether [initialize] has completed successfully.
  bool get isInitialized => _initialized;

  /// The platform view type identifier used to render this player's video.
  String get viewType => 'divine_video_player_view';

  /// The player ID passed to the native platform view as a creation parameter.
  int get playerId => _playerId;

  /// Creates the native player instance. Must be called before any
  /// other method.
  ///
  /// Throws [StateError] if called more than once.
  Future<void> initialize() async {
    if (_initialized) {
      throw StateError('Controller is already initialized.');
    }

    _playerId = _nextId++;
    _methodChannel = MethodChannel('divine_video_player/player_$_playerId');
    _eventChannel = EventChannel(
      'divine_video_player/player_$_playerId/events',
    );

    final result = await _globalChannel.invokeMethod<Map<Object?, Object?>>(
      'create',
      {'id': _playerId, 'useTexture': useTexture},
    );
    if (useTexture && result != null) {
      _textureId = result['textureId'] as int?;
    }

    _eventSubscription = _eventChannel.receiveBroadcastStream().listen(
      _handleEvent,
      onError: _handleEventError,
    );

    _initialized = true;
  }

  /// Sets a single video source.
  ///
  /// Convenience wrapper around [setClips] for the common single-video
  /// case. Replaces any previously loaded clips.
  Future<void> setSource(VideoClip clip) => setClips([clip]);

  /// Sets the list of clips to play as a continuous timeline.
  ///
  /// Replaces any previously loaded clips. The player must be
  /// [isInitialized] before calling this.
  Future<void> setClips(List<VideoClip> clips) async {
    _ensureInitialized();
    if (_firstFrameCompleter.isCompleted) {
      _firstFrameCompleter = Completer<bool>();
    }
    await _methodChannel.invokeMethod<void>(
      'setClips',
      {'clips': clips.map((c) => c.toMap()).toList()},
    );
  }

  /// Starts or resumes playback.
  Future<void> play() async {
    _ensureInitialized();
    await _methodChannel.invokeMethod<void>('play');
  }

  /// Pauses playback.
  Future<void> pause() async {
    _ensureInitialized();
    await _methodChannel.invokeMethod<void>('pause');
  }

  /// Stops playback and clears the current media.
  ///
  /// After calling this the player surface is blank (no stale frame)
  /// and position resets to zero.  The player remains alive and can
  /// be reused by calling [setSource] or [setClips] again.
  Future<void> stop() async {
    _ensureInitialized();
    await _methodChannel.invokeMethod<void>('stop');
  }

  /// Seeks to [position] on the global timeline.
  Future<void> seekTo(Duration position) async {
    _ensureInitialized();
    await _methodChannel.invokeMethod<void>('seekTo', {
      'positionMs': position.inMilliseconds,
    });
  }

  /// Sets the volume (0.0 silent, 1.0 full).
  Future<void> setVolume(double volume) async {
    _ensureInitialized();
    await _methodChannel.invokeMethod<void>('setVolume', {
      'volume': volume.clamp(0.0, 1.0),
    });
  }

  /// Sets the playback speed multiplier.
  Future<void> setPlaybackSpeed(double speed) async {
    _ensureInitialized();
    await _methodChannel.invokeMethod<void>(
      'setPlaybackSpeed',
      {'speed': speed},
    );
  }

  /// Enables or disables looping.
  ///
  /// When enabled, playback restarts from the beginning after all
  /// clips finish.
  Future<void> setLooping({required bool looping}) async {
    _ensureInitialized();
    await _methodChannel.invokeMethod<void>('setLooping', {'looping': looping});
  }

  /// Jumps playback to the start of the clip at [index].
  Future<void> jumpToClip(int index) async {
    _ensureInitialized();
    await _methodChannel.invokeMethod<void>('jumpToClip', {'index': index});
  }

  /// Sets overlay audio tracks that play in sync with the video.
  ///
  /// Each track is mixed on top of the video's original audio with
  /// independent volume, video-timeline range, and track range.
  ///
  /// Replaces any previously set audio tracks.
  Future<void> setAudioTracks(List<AudioTrack> tracks) async {
    _ensureInitialized();
    await _methodChannel.invokeMethod<void>(
      'setAudioTracks',
      {'tracks': tracks.map((t) => t.toMap()).toList()},
    );
  }

  /// Removes all overlay audio tracks.
  Future<void> removeAllAudioTracks() async {
    _ensureInitialized();
    await _methodChannel.invokeMethod<void>('removeAllAudioTracks');
  }

  /// Sets the volume of the overlay audio track at [index]
  /// (0.0 silent, 1.0 full).
  ///
  /// Has no effect if [index] is out of range.
  Future<void> setAudioTrackVolume(int index, double volume) async {
    _ensureInitialized();
    await _methodChannel.invokeMethod<void>('setAudioTrackVolume', {
      'index': index,
      'volume': volume.clamp(0.0, 1.0),
    });
  }

  /// Releases all native resources. The controller cannot be reused
  /// after disposal.
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;

    await Future.wait<void>([
      if (_eventSubscription != null) _eventSubscription!.cancel(),
      if (_initialized)
        _globalChannel.invokeMethod<void>('dispose', {'id': _playerId}),
      _stateController.close(),
    ]);
    _eventSubscription = null;
  }

  // -- internals --

  void _ensureInitialized() {
    if (!_initialized) {
      throw StateError(
        'Controller is not initialized. Call initialize() first.',
      );
    }
    if (_disposed) {
      throw StateError('Controller has been disposed.');
    }
  }

  void _handleEvent(dynamic event) {
    if (event is! Map) return;
    final map = event.cast<Object?, Object?>();
    _state = DivineVideoPlayerState.fromMap(map);

    // Log native error details rather than storing them in state.
    if (_state.status == PlaybackStatus.error) {
      final nativeError = map['errorMessage'] as String?;
      if (nativeError != null) {
        developer.log(
          'Native player error: $nativeError',
          name: 'DivineVideoPlayer',
          level: 1000,
        );
      }
    }

    if (_state.isFirstFrameRendered && !_firstFrameCompleter.isCompleted) {
      _firstFrameCompleter.complete(true);
    }
    if (!_stateController.isClosed) {
      _stateController.add(_state);
    }
  }

  void _handleEventError(Object error) {
    _state = _state.copyWith(status: PlaybackStatus.error);
    if (!_stateController.isClosed) {
      _stateController.add(_state);
    }
  }
}
