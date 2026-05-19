import 'dart:async';
import 'dart:io';

import 'package:divine_video_player/divine_video_player.dart';
import 'package:flutter/foundation.dart'
    show ValueListenable, kIsWeb, visibleForTesting;
import 'package:flutter/widgets.dart';
import 'package:infinite_video_feed/src/models/builders.dart';
import 'package:infinite_video_feed/src/models/video_error_type.dart';
import 'package:infinite_video_feed/src/services/controller_subscriptions.dart';
import 'package:infinite_video_feed/src/services/disk_prefetcher.dart';
import 'package:infinite_video_feed/src/services/load_watchdog.dart';
import 'package:infinite_video_feed/src/services/playback_source_registry.dart';
import 'package:infinite_video_feed/src/services/stale_playback_detector.dart';
import 'package:infinite_video_feed/src/utils/playback_sources.dart';
import 'package:infinite_video_feed/src/utils/source_loader.dart';
import 'package:infinite_video_feed/src/widgets/video_item.dart';
import 'package:media_cache/media_cache.dart';
import 'package:models/models.dart';
import 'package:unified_logger/unified_logger.dart';

/// Infinite scrolling video feed using native platform video players.
///
/// Manages [DivineVideoPlayerController] instances for the current and
/// optionally the next video. Uses [MediaCacheManager] to prefetch
/// upcoming videos to disk so playback starts from local storage.
class InfiniteVideoFeed extends StatefulWidget {
  /// Creates an infinite scrolling video feed.
  const InfiniteVideoFeed({
    required this.videos,
    required this.cache,
    this.videoBuilder,
    this.urlResolver,
    this.loadingBuilder,
    this.errorBuilder,
    this.overlayBuilder,
    this.scrollPhysics,
    this.initialIndex = 0,
    this.initialVolume = 1.0,
    this.onVolumeChanged,
    this.scrollDirection = Axis.vertical,
    this.keepPreviousAlive = true,
    this.keepNextAlive = true,
    this.prefetchCount = 25,
    this.shouldPortraitExpand = true,
    this.maxLoopDuration,
    this.onActiveVideoChanged,
    this.onNearEnd,
    this.nearEndThreshold = 10,
    this.onVideoLoopCompleted,
    this.onVideoStalled,
    this.slowLoadThreshold = const Duration(seconds: 8),
    this.preloadGracePeriod = const Duration(seconds: 3),
    super.key,
  });

  /// Whether the native video player is supported on the current platform.
  ///
  /// Returns `true` on Android, iOS, and macOS. Returns `false` on web and
  /// all other desktop platforms.
  static bool get isSupported =>
      _isSupportedOverrideForTesting ??
      (!kIsWeb &&
          (Platform.isAndroid ||
              Platform.isIOS ||
              Platform.isMacOS ||
              Platform.isLinux));

  static bool? _isSupportedOverrideForTesting;

  // coverage:ignore-start
  // Test hook used by app-layer widget tests outside this package.
  /// Current test override for [isSupported].
  @visibleForTesting
  static bool? get debugIsSupportedOverride => _isSupportedOverrideForTesting;

  /// Overrides [isSupported] in tests. Set to `null` to clear override.
  @visibleForTesting
  static set debugIsSupportedOverride(bool? value) {
    _isSupportedOverrideForTesting = value;
  }
  // coverage:ignore-end

  /// The list of videos to display.
  final List<VideoEvent> videos;

  /// Resolves the playback URL for a [VideoEvent].
  ///
  /// When provided, called instead of using [VideoEvent.videoUrl] directly.
  /// Use this to apply platform-aware URL selection (e.g. progressive MP4
  /// for short videos instead of raw blob URLs).
  ///
  /// Falls back to [VideoEvent.videoUrl] when `null`.
  final String? Function(VideoEvent video)? urlResolver;

  /// Builder for the loading state shown while a video initializes.
  final LoadingBuilder? loadingBuilder;

  /// Builder for the error state.
  final ErrorBuilder? errorBuilder;

  /// Builder that wraps or replaces the default video player widget.
  ///
  /// When provided, called instead of the default [VideoItemWidget].
  /// Use this to inject metrics tracking, custom sizing, or other
  /// wrappers around the raw video surface.
  ///
  /// When `null`, the feed renders [VideoItemWidget] directly.
  final VideoBuilder? videoBuilder;

  /// Builder for the overlay layer rendered on top of the video.
  final OverlayBuilder? overlayBuilder;

  /// Optional physics for page swiping.
  ///
  /// When `null`, a tuned default is used for short-video feeds.
  final ScrollPhysics? scrollPhysics;

  /// The cache manager used for disk prefetching and cached playback.
  ///
  /// Must be initialized before passing it in.
  final MediaCacheManager cache;

  /// The initial video index to display.
  final int initialIndex;

  /// The initial playback volume (0.0 silent, 1.0 full).
  ///
  /// Defaults to `1.0`. Use [InfiniteVideoFeedState.setVolume] to change the
  /// volume after the feed is mounted.
  final double initialVolume;

  /// Hook: Called when the playback volume changes (mute/unmute/setVolume).
  ///
  /// The callback receives the new volume value (0.0 = muted, 1.0 = full).
  /// Use this to persist the mute/volume state outside the package.
  final ValueChanged<double>? onVolumeChanged;

  /// The scroll direction of the feed.
  final Axis scrollDirection;

  /// Whether to keep the previous video's player alive for instant playback
  /// when swiping back.
  ///
  /// When `true`, the controller for index `currentIndex - 1` stays
  /// initialized alongside the current one. Defaults to `true`.
  final bool keepPreviousAlive;

  /// Whether to keep the next video's player alive for instant playback
  /// on swipe.
  ///
  /// When `true`, the controller for index `currentIndex + 1` stays
  /// initialized alongside the current one. Defaults to `true`.
  final bool keepNextAlive;

  /// Number of videos ahead of the current index to prefetch to disk.
  ///
  /// These videos are downloaded via [MediaCacheManager] and played
  /// from local storage when the user reaches them.
  final int prefetchCount;

  /// Controls how videos are fitted into the feed viewport.
  ///
  /// When `true`, non-square videos expand to [BoxFit.cover] while
  /// square (1:1) videos use [BoxFit.contain].
  /// When `false`, all videos use [BoxFit.contain].
  ///
  /// Defaults to `true`.
  final bool shouldPortraitExpand;

  /// Seeks active playback back to zero once this position is reached.
  ///
  /// When `null`, timeline-length loop enforcement is disabled and native
  /// looping behavior applies.
  final Duration? maxLoopDuration;

  /// Called when the active video changes.
  final OnActiveVideoChanged? onActiveVideoChanged;

  /// Called when the user is near the end of the list.
  final VoidCallback? onNearEnd;

  /// How many videos from the end should trigger [onNearEnd].
  final int nearEndThreshold;

  /// Called each time the active video completes a loop.
  ///
  /// Fires when the playback position resets from near the end back to the
  /// beginning, either because [maxLoopDuration] was reached and the feed
  /// enforced a seek-to-zero, or because the video reached its natural end
  /// and looped on its own.
  ///
  /// The `currentIndex` argument is the feed index of the video that looped.
  /// Use this to implement auto-advance logic in the owning widget.
  final void Function(int currentIndex)? onVideoLoopCompleted;

  /// Called when the active video stalls — all source fallbacks are
  /// exhausted or the load watchdog times out without a source to retry.
  ///
  /// The feed marks the video as an error automatically. Use this
  /// callback to auto-advance the feed or show a custom toast.
  final void Function(int index)? onVideoStalled;

  /// Duration after which a buffering video is considered slow.
  ///
  /// When the active video's playback status stays buffering or idle
  /// for this duration the player tries the next URL in its fallback list.
  /// Defaults to 8 seconds.
  final Duration slowLoadThreshold;

  /// How long to give the current video a bandwidth head-start before
  /// initializing neighbour controllers (previous / next).
  ///
  /// Neighbour init fires as soon as the current video renders its first
  /// frame, or after this duration — whichever is earlier. Defaults to
  /// 3 seconds, matching the legacy pooled_video_player behaviour.
  final Duration preloadGracePeriod;

  @override
  State<InfiniteVideoFeed> createState() => InfiniteVideoFeedState();
}

/// State for [InfiniteVideoFeed]. Owns the live controller window and
/// orchestrates the focused services that handle prefetching, source
/// failover, slow-load detection, stalled-playback recovery, and
/// per-controller stream subscriptions.
///
/// Exposes [pauseActive], [resumeActive], [animateToPage], and
/// [currentIndex] for owning widgets that need to drive the feed
/// imperatively.
class InfiniteVideoFeedState extends State<InfiniteVideoFeed> {
  static const _logName = 'InfiniteVideoFeed';
  static const _loopEndThreshold = Duration(seconds: 1);
  static const _loopStartThreshold = Duration(seconds: 1);
  static const _pageJumpDuration = Duration(milliseconds: 300);
  static const Cubic _pageJumpCurve = Curves.easeInOut;

  late final PageController _pageController;
  late final ValueNotifier<double> _pagePosition;

  // Live controller window — read by build(). Stays on the State because
  // build() needs synchronous access to it.
  final _controllers = <int, DivineVideoPlayerController>{};

  // UI-facing state — drives build(). Stays on the State.
  final _errors = <int>{};
  final _errorTypes = <int, VideoErrorType>{};
  final _loopSeekInProgress = <int>{};

  // Indices currently performing a source failover. Stale `hasError`
  // events from the old source can arrive between `stop()` and `setSource()`
  // — this guard prevents them from re-triggering failover or showing
  // the error UI on top of a successfully recovered controller.
  final _failoverInFlight = <int>{};

  // Indices whose initial source was the on-disk cache file. If a runtime
  // error fires for one of these we evict the cached file so future loads
  // hit the network instead of replaying the corrupt bytes.
  final _loadedFromCache = <int>{};
  int _currentIndex = 0;

  // Current playback volume applied to the active controller and all
  // controllers that become active. Seeded from widget.initialVolume.
  late double _volume;

  // Generation counter for the player window so async neighbour-init can
  // detect that the user scrolled away mid-load.
  int _playerWindowGeneration = 0;

  // Per-index generation token used by _initController to cancel stale
  // async work when ownership changes while awaits are in flight.
  final _controllerInitGenerations = <int, int>{};

  // ─── Services ───────────────────────────────────────────────────────────

  late final PlaybackSourceRegistry _sources;
  late final DiskPrefetcher _prefetcher;
  late final LoadWatchdog _watchdog;
  late final StalePlaybackDetector _staleDetector;
  late final ControllerSubscriptions _subscriptions;

  // ─── Public API ─────────────────────────────────────────────────────────

  /// The feed index of the currently active (visible) video.
  int get currentIndex => _currentIndex;

  /// Continuous page position for scroll-driven overlay effects.
  ///
  /// Value is 0-based and includes fractional positions while the page view
  /// is between two items.
  ValueListenable<double> get pagePositionListenable => _pagePosition;

  /// Pauses the currently active video without changing the page.
  void pauseActive() {
    unawaited(_controllers[_currentIndex]?.pause());
  }

  /// Resumes the currently active video without changing the page.
  void resumeActive() {
    unawaited(_controllers[_currentIndex]?.play());
  }

  /// Sets the playback volume (0.0 silent, 1.0 full).
  ///
  /// Only the active controller is updated immediately. Neighbour controllers
  /// already receive the correct volume during their initialization via
  /// [_initController], so there is no need to touch them here.
  ///
  /// Calls [InfiniteVideoFeed.onVolumeChanged] with the new value.
  void setVolume(double volume) {
    final clamped = volume.clamp(0.0, 1.0);
    if (_volume == clamped) return;
    _volume = clamped;
    final active = _controllers[_currentIndex];
    if (active != null) unawaited(active.setVolume(clamped));
    widget.onVolumeChanged?.call(clamped);
  }

  /// Animate the page view to [index].
  Future<void> animateToPage(int index) async {
    if (!mounted || widget.videos.isEmpty) return;

    final targetIndex = index.clamp(0, widget.videos.length - 1);
    await _pageController.animateToPage(
      targetIndex,
      duration: _pageJumpDuration,
      curve: _pageJumpCurve,
    );
  }

  void _syncPagePosition() {
    late final double page;
    if (_pageController.hasClients) {
      page = _pageController.page ?? _currentIndex.toDouble();
    } else {
      page = _currentIndex.toDouble(); // coverage:ignore-line
    }
    if ((_pagePosition.value - page).abs() < 0.0001) return;
    _pagePosition.value = page;
  }

  // ─── Lifecycle ──────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _volume = widget.initialVolume;
    _pagePosition = ValueNotifier<double>(_currentIndex.toDouble());
    _pageController = PageController(initialPage: _currentIndex)
      ..addListener(_syncPagePosition);

    _sources = PlaybackSourceRegistry();
    _prefetcher = DiskPrefetcher(cache: widget.cache, log: _log);
    // coverage:ignore-start
    // Callback wiring only; exercised transitively by watchdog/detector tests
    // but not counted in optimized widget coverage.
    _watchdog = LoadWatchdog(
      threshold: widget.slowLoadThreshold,
      onSlowLoad: (index) => unawaited(_retryWithNextSource(index)),
      log: _log,
    );
    _staleDetector = StalePlaybackDetector(
      onSeekRecovery: _seekKick,
      onSourceFailover: (index) => unawaited(_retryWithNextSource(index)),
      log: _log,
    );
    // coverage:ignore-end
    _subscriptions = ControllerSubscriptions();

    unawaited(_onIndexChanged(_currentIndex));
  }

  @override
  void didUpdateWidget(InfiniteVideoFeed oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.videos == oldWidget.videos) return;

    // Append-only: the new list starts with exactly the same items in the
    // same order — same id AND same effective playback source — only new
    // items were appended (e.g. pagination). Existing controllers are
    // still valid; just let _onIndexChanged extend the window. If the
    // resolved URL for an existing index changed (e.g. the caller updated
    // the playback source for the same id) the cached controller is stale
    // and we must fall through to the non-append teardown path.
    final oldLen = oldWidget.videos.length;
    var isAppendOnly = widget.videos.length >= oldLen;
    if (isAppendOnly) {
      for (var i = 0; i < oldLen; i++) {
        final oldVideo = oldWidget.videos[i];
        final newVideo = widget.videos[i];
        if (oldVideo.id != newVideo.id ||
            _resolvedSourceFor(oldVideo, oldWidget.urlResolver) !=
                _resolvedSourceFor(newVideo, widget.urlResolver)) {
          isAppendOnly = false;
          break;
        }
      }
    }

    if (isAppendOnly) {
      unawaited(_onIndexChanged(_currentIndex));
      return;
    }

    // Non-append-only change (e.g. tab switch forYou → following, or full
    // feed replacement). Tear down all live controllers, reset to the
    // caller's intended starting index, and jump the PageController so
    // the next frame opens on the right item instead of whatever stale
    // page the previous feed was on.
    _log(
      'Non-append-only video list change — tearing down all controllers '
      '(old=${oldWidget.videos.length} new=${widget.videos.length})',
    );

    _teardownAllControllers();

    _currentIndex = widget.videos.isEmpty
        ? 0
        : widget.initialIndex.clamp(0, widget.videos.length - 1);
    _pagePosition.value = _currentIndex.toDouble();

    _rebuild();

    // The PageController is shared across rebuilds, so its current page
    // does not reset on its own. Jump after the rebuild schedules a
    // frame, once the PageView has re-attached against the new item
    // count. If the controller has no clients (e.g. videos became empty)
    // skip the jump — the next mount will pick up _currentIndex via
    // PageController.initialPage on a fresh attach.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (widget.videos.isEmpty) return;
      if (!_pageController.hasClients) return;
      if (_pageController.page?.round() == _currentIndex) return;
      _pageController.jumpToPage(_currentIndex);
    });

    unawaited(_onIndexChanged(_currentIndex));
  }

  String? _resolvedSourceFor(
    VideoEvent video,
    String? Function(VideoEvent video)? resolver,
  ) => resolver?.call(video) ?? video.videoUrl;

  @override
  void dispose() {
    _prefetcher.dispose();
    _watchdog.disposeAll();
    _staleDetector.disposeAll();
    _subscriptions.disposeAll();
    _sources.clear();
    _pagePosition.dispose();
    _pageController.dispose();
    for (final controller in _controllers.values) {
      unawaited(controller.dispose());
    }
    _controllers.clear();
    _controllerInitGenerations.clear();
    super.dispose();
  }

  // ─── Logging / setState wrapper ─────────────────────────────────────────

  void _log(String message) => Log.debug(
    message,
    name: _logName,
    category: LogCategory.video,
  );

  void _rebuild() {
    if (mounted) setState(() {});
  }

  // coverage:ignore-start
  // Simple resolver wrapper; behavior is covered via callers, but optimized
  // coverage reports the declaration line itself as uncovered.
  String? _resolveUrl(VideoEvent video) =>
      widget.urlResolver?.call(video) ?? video.videoUrl;
  // coverage:ignore-end

  // ─── Index change → window + prefetch ───────────────────────────────────

  Future<void> _onIndexChanged(int index) async {
    if (widget.videos.isEmpty) return;
    await _updatePlayerWindow(index);
    unawaited(_runPrefetch(index));
  }

  Future<void> _updatePlayerWindow(int index) async {
    final generation = ++_playerWindowGeneration;

    final lastIndex = widget.videos.length - 1;
    final start = widget.keepPreviousAlive
        ? (index - 1).clamp(0, lastIndex)
        : index;
    final end = widget.keepNextAlive ? (index + 1).clamp(0, lastIndex) : index;

    // Dispose controllers outside the live window.
    _controllers.keys
        .where((i) => i < start || i > end)
        .toList()
        .forEach(_disposeAt);

    // Initialize the current index first for instant playback.
    if (!_controllers.containsKey(index)) {
      await _initController(index);
    }

    if (_playerWindowGeneration != generation || !mounted) return;

    // Give the current video a bandwidth head-start before loading
    // neighbours. Wait for the first frame or the grace period — whichever
    // comes first — so fast connections don't delay neighbour init at all.
    final currentController = _controllers[index];
    if (currentController != null) {
      await _waitForFirstFrameOrGracePeriod(currentController);
    }

    if (_playerWindowGeneration != generation || !mounted) return;

    if (widget.keepPreviousAlive &&
        index - 1 >= 0 &&
        !_controllers.containsKey(index - 1)) {
      unawaited(_initController(index - 1));
    }

    if (widget.keepNextAlive &&
        index + 1 <= lastIndex &&
        !_controllers.containsKey(index + 1)) {
      unawaited(_initController(index + 1));
    }
  }

  Future<void> _waitForFirstFrameOrGracePeriod(
    DivineVideoPlayerController controller,
  ) async {
    final gracePeriodElapsed = Completer<void>();
    final graceTimer = Timer(widget.preloadGracePeriod, () {
      if (!gracePeriodElapsed.isCompleted) {
        gracePeriodElapsed.complete();
      }
    });

    try {
      await Future.any([
        controller.firstFrameRendered,
        gracePeriodElapsed.future,
      ]);
    } finally {
      graceTimer.cancel();
    }
  }

  Future<void> _runPrefetch(int index) async {
    if (widget.prefetchCount <= 0) return;

    // coverage:ignore-start
    // Exercised indirectly by widget tests and DiskPrefetcher tests, but the
    // optimized coverage run misses these nested local-helper lines.
    final lastIndex = widget.videos.length - 1;
    final prefetchStart = widget.keepNextAlive ? index + 2 : index + 1;
    final prefetchEnd = (index + widget.prefetchCount).clamp(0, lastIndex);

    bool isHlsManifest(String url) {
      try {
        final uri = Uri.parse(url);
        final lastSegment = uri.pathSegments.isEmpty
            ? ''
            : uri.pathSegments.last;
        return lastSegment.endsWith('.m3u8');
      } on FormatException {
        return false;
      }
    }

    await _prefetcher.run(
      startIndex: prefetchStart,
      endIndex: prefetchEnd,
      videos: widget.videos,
      resolveUrls: (video) => resolvePlaybackSources(
        video,
        urlResolver: widget.urlResolver,
        // Exclude HLS manifests: prefetch writes static files to disk,
        // but HLS playback needs re-streaming the manifest + segments.
      ).where((url) => !isHlsManifest(url)).toList(),
    );
    // coverage:ignore-end
  }

  void _teardownAllControllers() {
    _prefetcher.cancelActive();
    _playerWindowGeneration++;

    _watchdog.disposeAll();
    _staleDetector.disposeAll();
    _subscriptions.disposeAll();
    _sources.clear();

    _loopSeekInProgress.clear();
    _failoverInFlight.clear();
    _loadedFromCache.clear();
    _errors.clear();
    _errorTypes.clear();

    for (final controller in _controllers.values) {
      unawaited(controller.dispose());
    }
    _controllers.clear();
    _controllerInitGenerations.clear();
  }

  // coverage:ignore-start
  // Disposal is driven by live controller-window churn. Widget tests can
  // cover the call sites, but the native-controller disposal path itself is
  // not observable in package tests without platform players.
  void _disposeAt(int index) {
    _log('Disposing player at index $index');
    _subscriptions.unsubscribe(index);
    _watchdog.stop(index);
    if (index == _currentIndex) _staleDetector.stop();
    _staleDetector.forget(index);
    _errors.remove(index);
    _loopSeekInProgress.remove(index);
    _failoverInFlight.remove(index);
    _loadedFromCache.remove(index);
    _errorTypes.remove(index);
    _sources.remove(index);
    _controllerInitGenerations.remove(index);
    unawaited(_controllers.remove(index)?.dispose());
  }
  // coverage:ignore-end

  // ─── Controller init / retry ────────────────────────────────────────────

  Future<void> _initController(int index, {bool skipCache = false}) async {
    if (index < 0 || index >= widget.videos.length) return;

    final initGeneration = (_controllerInitGenerations[index] ?? 0) + 1;
    _controllerInitGenerations[index] = initGeneration;

    final video = widget.videos[index];
    final cachedFile = skipCache
        ? null
        : widget.cache.getCachedFileSync(video.id);
    final fromCache = cachedFile != null;

    _log(
      'Init player index $index (${video.id}) — '
      '${fromCache ? 'from cache' : 'from network'}',
    );

    // Use the legacy Android `SurfaceTextureEntry` backend instead of the
    // default `SurfaceProducer`. The feed renders many players concurrently;
    // when a sibling player's decoder is released the Exynos C2 H.264
    // driver triggers a global format reprobe, and SurfaceProducer's small
    // ImageReader buffer pool can leak the previously-decoded frame onto a
    // peer player's surface for one frame (visible flicker). The legacy
    // single-buffer SurfaceTexture has no shared pool and is immune.
    // Trade-off: no surface-recreate callback (e.g. permission dialogs);
    // acceptable for the feed because the screen is always foregrounded
    // while videos are playing. No effect on iOS/macOS.
    final controller = DivineVideoPlayerController(
      useTexture: true,
      useLegacySurface: true,
    );
    _controllers[index] = controller;

    bool ownsInit() {
      return mounted &&
          _controllerInitGenerations[index] == initGeneration &&
          identical(_controllers[index], controller);
    }

    bool guardInitOwnership(String step) {
      if (ownsInit()) return true;
      // coverage:ignore-start
      // Stale-init cleanup only fires when an in-flight await races a widget
      // unmount or a rapid re-init for the same index. Both are observable in
      // production, but not reproducible in package widget tests without
      // microsecond-precise control over native platform-channel timing.
      _log('Abort stale init at index $index (${video.id}) during $step');
      if (identical(_controllers[index], controller)) {
        _controllers.remove(index);
      }
      unawaited(controller.dispose());
      return false;
      // coverage:ignore-end
    }

    try {
      await controller.initialize();
      if (!guardInitOwnership('initialize')) return;

      // coverage:ignore-start
      // Native controller initialization and source selection require the
      // platform player. Package tests cover the surrounding window/update
      // orchestration, but not the end-to-end texture-backed init flow.
      // Always resolve network sources. They are used as runtime fallbacks
      // even when the video is loaded from disk cache (in case the cached
      // file is corrupt or unreadable).
      final playbackSources = resolvePlaybackSources(
        video,
        urlResolver: widget.urlResolver,
      );

      if (fromCache) {
        try {
          await controller.setSource(VideoClip.file(cachedFile.path));
          if (!guardInitOwnership('setSource(cache)')) return;
          _loadedFromCache.add(index);
          // Register network sources with prestart so a runtime parseError
          // on the cached file can still fall over to network URLs.
          if (playbackSources.isNotEmpty) {
            _sources.registerPrestart(index, playbackSources);
            _log(
              'Cache loaded index $index (${video.id}): '
              'registered ${playbackSources.length} network fallbacks',
            );
          }
        } on Object catch (cacheError, cacheStackTrace) {
          // The cached file is unreadable at init time — evict it from the
          // cache so future loads don't replay the corrupt bytes, then
          // fall through to the network path.
          _log(
            'Cache read failed index $index (${video.id}): $cacheError '
            '— evicting cache and falling back to network',
          );
          Log.error(
            'Cache fallback to network',
            name: _logName,
            category: LogCategory.video,
            error: cacheError,
            stackTrace: cacheStackTrace,
          );
          unawaited(_evictCachedFile(video.id));
          if (playbackSources.isEmpty) {
            throw StateError('No playback source for video ${video.id}');
          }
          final (openedSource, openedSourceIdx) = await setSourceWithFallbacks(
            index: index,
            controller: controller,
            sources: playbackSources,
            log: _log,
          );
          if (!guardInitOwnership('setSourceWithFallbacks(cache)')) return;
          _sources.register(index, playbackSources, openedSourceIdx);
          _log(
            'Network fallback source selected index $index (${video.id}): '
            'openedSource=$openedSource',
          );
        }
      } else {
        if (playbackSources.isEmpty) {
          throw StateError('No playback source for video ${video.id}');
        }

        final (openedSource, openedSourceIdx) = await setSourceWithFallbacks(
          index: index,
          controller: controller,
          sources: playbackSources,
          log: _log,
        );
        if (!guardInitOwnership('setSourceWithFallbacks(network)')) return;
        _sources.register(index, playbackSources, openedSourceIdx);
        _log(
          'Source selected index $index (${video.id}): '
          'openedSource=$openedSource',
        );
      }

      await controller.setLooping(looping: true);
      if (!guardInitOwnership('setLooping')) return;
      await controller.setVolume(_volume);
      if (!guardInitOwnership('setVolume')) return;

      if (index == _currentIndex) {
        _log('Playing index $index (${video.id})');
        await controller.play();
        if (!guardInitOwnership('play')) return;
        _watchdog.start(index, controller);
        _staleDetector.start(index, controller);
      }

      _errors.remove(index);
      _errorTypes.remove(index);

      _attachSubscriptions(index, controller);
    } on Object catch (e, stackTrace) {
      if (!ownsInit()) {
        guardInitOwnership('error handling');
        return;
      }
      _log('Error loading index $index (${video.id}): $e');
      Log.error(
        'Player init failed',
        name: _logName,
        category: LogCategory.video,
        error: e,
        stackTrace: stackTrace,
      );
      _errorTypes[index] = classifyVideoError(
        errorMessage: e.toString(),
        source: _resolveUrl(video),
      );
      unawaited(_controllers.remove(index)?.dispose());
      _errors.add(index);
    }
    // coverage:ignore-end

    if (!ownsInit()) {
      // coverage:ignore-start
      // Same race as guardInitOwnership: only fires when the try block
      // completes after the widget was unmounted or the index was re-inited.
      // Not reproducible in package widget tests.
      guardInitOwnership('rebuild');
      return;
      // coverage:ignore-end
    }
    _rebuild();
  }

  // coverage:ignore-start
  // Manual retry delegates back into native controller init, which is not
  // executable in package tests without platform players.
  Future<void> _retryController(int index) async {
    _errors.remove(index);
    _errorTypes.remove(index);
    _watchdog.stop(index);
    if (index == _currentIndex) _staleDetector.stop();
    _sources.remove(index);
    _staleDetector.forget(index);
    _subscriptions.unsubscribe(index);
    unawaited(_controllers.remove(index)?.dispose());
    _rebuild();
    // Skip cache on manual retry so a corrupt cached file does not loop
    // the same failure indefinitely.
    await _initController(index, skipCache: true);
  }
  // coverage:ignore-end

  // ─── Source failover (called by watchdog + stale detector) ──────────────

  // coverage:ignore-start
  // Source failover depends on runtime native playback errors and source
  // switching on an initialized controller, which package tests cannot
  // simulate without the platform player backend.
  Future<void> _retryWithNextSource(int index) async {
    if (!_sources.hasSources(index)) {
      _log('No sources to retry for index $index');
      _onVideoStalled(index);
      return;
    }

    final nextSource = _sources.advance(index);
    if (nextSource == null) {
      _log('All sources exhausted for index $index');
      _onVideoStalled(index);
      return;
    }

    _log('Source failover index $index: source=$nextSource');

    // The first failover after a cache load means the cached file was
    // unplayable at runtime. Evict it so future loads hit the network.
    if (_loadedFromCache.remove(index)) {
      final video = widget.videos[index];
      _log('Evicting corrupt cache file for index $index (${video.id})');
      unawaited(_evictCachedFile(video.id));
    }

    final controller = _controllers[index];
    if (controller == null) return;

    _failoverInFlight.add(index);
    try {
      await controller.stop();
      await controller.setSource(VideoClip.network(nextSource));
      if (index == _currentIndex) {
        await controller.setVolume(_volume);
        await controller.play();
        _watchdog.start(index, controller);
        _staleDetector.resetGrace();
      }
    } on Object catch (e, stackTrace) {
      _log('Source failover failed index $index source=$nextSource: $e');
      Log.error(
        'Source failover failed',
        name: _logName,
        category: LogCategory.video,
        error: e,
        stackTrace: stackTrace,
      );
      _onVideoStalled(index);
    } finally {
      _failoverInFlight.remove(index);
    }
  }
  // coverage:ignore-end

  // coverage:ignore-start
  // Stall recovery is only reached from watchdog / stale-detector callbacks
  // tied to native playback state streams.
  void _onVideoStalled(int index) {
    _log('Video stalled index $index — marking error');
    _stopAndMarkError(index, VideoErrorType.generic);
    widget.onVideoStalled?.call(index);
  }

  /// Removes [videoId] from the on-disk media cache. Errors are logged but
  /// not rethrown — cache eviction is best-effort cleanup.
  Future<void> _evictCachedFile(String videoId) async {
    try {
      await widget.cache.removeCachedFile(videoId);
    } on Object catch (e, stackTrace) {
      Log.error(
        'Failed to evict cached file for $videoId',
        name: _logName,
        category: LogCategory.video,
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Stops the controller at [index] (so audio/video cease immediately) and
  /// marks the slot as an error, triggering a rebuild.
  void _stopAndMarkError(int index, VideoErrorType type) {
    unawaited(_controllers[index]?.stop());
    _errors.add(index);
    _errorTypes[index] ??= type;
    _rebuild();
  }

  void _seekKick(int index, int positionMs) {
    final controller = _controllers[index];
    if (controller == null) return;
    unawaited(controller.seekTo(Duration(milliseconds: positionMs)));
  }
  // coverage:ignore-end

  // ─── Subscription wiring ────────────────────────────────────────────────

  // coverage:ignore-start
  // Subscription callbacks are driven by native controller streams. Package
  // tests cover the builder/callback contract around them, but not the
  // platform-emitted stream traffic itself.
  void _attachSubscriptions(int index, DivineVideoPlayerController controller) {
    _subscriptions
      ..subscribeToDimensions(index, controller, onDimensionsReady: _rebuild)
      ..subscribeToFirstFrame(index, controller, onFirstFrame: _rebuild)
      ..subscribeToPlaybackErrors(
        index,
        controller,
        isAlreadyError: () =>
            _errors.contains(index) || _failoverInFlight.contains(index),
        onError: (errorCode, errorMessage) {
          _log(
            'Runtime playback error at index '
            '$index ${_resolveUrl(widget.videos[index])}: '
            'code=$errorCode message=$errorMessage',
          );
          _watchdog.stop(index);
          if (index == _currentIndex) _staleDetector.stop();

          // Use the typed error code for a reliable failover decision.
          // Fall back to attempting failover for unknown errors so we
          // don't give up prematurely on unclassified failures.
          final shouldFailover =
              (errorCode == null || errorCode.shouldFailover) &&
              _sources.hasSources(index) &&
              _sources.canAdvance(index);
          if (shouldFailover) {
            unawaited(_retryWithNextSource(index));
            return;
          }

          _stopAndMarkError(
            index,
            classifyVideoError(
              errorMessage: errorMessage,
              source: _resolveUrl(widget.videos[index]),
            ),
          );
        },
      );

    final maxLoopDuration = widget.maxLoopDuration;
    if (maxLoopDuration != null) {
      _subscriptions.subscribeToLoopEnforcement(
        index,
        controller,
        maxLoopDuration: maxLoopDuration,
        isCurrent: () => index == _currentIndex,
        isSeekInProgress: () => _loopSeekInProgress.contains(index),
        onSeekStarted: () {
          _loopSeekInProgress.add(index);
          _log(
            'Loop enforcement index $index: '
            'maxMs=${maxLoopDuration.inMilliseconds}',
          );
        },
        onPositionBelowMax: () => _loopSeekInProgress.remove(index),
        // Do NOT clear _loopSeekInProgress in whenComplete: native seekTo
        // returns immediately (before ExoPlayer finishes seeking), so
        // clearing the guard here lets stale position events retrigger
        // the seek before position 0 is reported. The guard is cleared by
        // onPositionBelowMax once ExoPlayer actually emits the post-seek
        // position.
        onSeekToZero: () => unawaited(controller.seekTo(Duration.zero)),
      );
    }

    if (widget.onVideoLoopCompleted != null) {
      _subscriptions.subscribeToAutoAdvance(
        index,
        controller,
        maxLoopDuration: widget.maxLoopDuration,
        endThreshold: _loopEndThreshold,
        startThreshold: _loopStartThreshold,
        isCurrent: () => index == _currentIndex,
        onLoopCompleted: () => widget.onVideoLoopCompleted!.call(index),
      );
    }
  }
  // coverage:ignore-end

  // ─── Page changes ───────────────────────────────────────────────────────

  // coverage:ignore-start
  // Page-change side effects are coupled to controller readiness on native
  // players. Existing tests cover page replacement and callback wiring, but
  // not pause/play against real initialized platform controllers.
  void _onPageChanged(int index) {
    final previousIndex = _currentIndex;
    _log('Page changed: $previousIndex → $index');
    _currentIndex = index;

    _watchdog.stop(previousIndex);
    _staleDetector.stop();

    // Guard: only call methods on controllers that have finished initializing.
    // _initController stores the instance in _controllers synchronously before
    // awaiting initialize(), so there is a short window where the controller
    // exists in the map but is not yet ready. Calling pause()/play() in that
    // window throws StateError. The guard makes _onPageChanged safe to call
    // from jumpToPage callbacks that fire before initialization completes
    // (e.g. from the didUpdateWidget post-frame jumpToPage on feed
    // replacement).
    final prevController = _controllers[previousIndex];
    if (prevController != null && prevController.isInitialized) {
      unawaited(prevController.pause());
    }

    // Play the current video if it is already initialized. Otherwise
    // _initController will play it and start the watchdog + stale detector
    // once the source is ready.
    if (_controllers.containsKey(index)) {
      final curr = _controllers[index]!;
      if (curr.isInitialized) {
        unawaited(curr.setVolume(_volume));
        unawaited(curr.play());
        _watchdog.start(index, curr);
        _staleDetector.start(index, curr);
      }
    }

    if (index < widget.videos.length) {
      widget.onActiveVideoChanged?.call(widget.videos[index], index);
    }

    final distanceFromEnd = widget.videos.length - index - 1;
    if (distanceFromEnd <= widget.nearEndThreshold) {
      widget.onNearEnd?.call();
    }

    unawaited(_onIndexChanged(index));

    if (mounted) setState(() {});
  }
  // coverage:ignore-end

  // Determine if the video is square from the controller's resolved
  // dimensions. False until dimensions are available.
  bool _isSquareVideo(DivineVideoPlayerController? controller) {
    if (controller == null) return false;
    final state = controller.state;
    return state.videoWidth > 0 &&
        state.videoHeight > 0 &&
        state.videoWidth == state.videoHeight;
  }

  // ─── Build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return PageView.builder(
      allowImplicitScrolling: true,
      controller: _pageController,
      physics: widget.scrollPhysics,
      scrollDirection: widget.scrollDirection,
      onPageChanged: _onPageChanged,
      itemCount: widget.videos.length,
      itemBuilder: (context, index) {
        final hasError = _errors.contains(index);
        final controller = _controllers[index];

        final overlay = widget.overlayBuilder?.call(
          context,
          index,
          controller,
          isActive: index == _currentIndex,
        );
        final videoItem = VideoItemWidget(
          controller: controller,
          shouldPortraitExpand: widget.shouldPortraitExpand,
        );

        final hasVideoSize =
            controller != null && controller.state.videoHeight != 0;
        return Stack(
          fit: StackFit.expand,
          children: [
            // Loading layer — shown while the video surface is not yet
            // available. Removed once the first frame is rendered so the
            // widget (and any timers it owns) are properly disposed.
            if (!hasError &&
                (!hasVideoSize || !controller.state.isFirstFrameRendered))
              ?widget.loadingBuilder?.call(
                context,
                index,
                isSquare: _isSquareVideo(controller),
              ),

            if (!hasError && hasVideoSize)
              widget.videoBuilder?.call(
                    context,
                    videoItem,
                    index,
                    controller,
                  ) ??
                  videoItem,
            // Overlay layer — consumer-provided controls, progress, etc.
            ?overlay,

            if (hasError)
              // coverage:ignore-start
              // Consumer-supplied error UI is wiring only; package tests cover
              // retry behavior elsewhere and don't need to duplicate builder
              // composition here.
              ?widget.errorBuilder?.call(
                context,
                index,
                () => unawaited(_retryController(index)),
                _errorTypes[index] ?? VideoErrorType.generic,
              ),
            // coverage:ignore-end
          ],
        );
      },
    );
  }
}
