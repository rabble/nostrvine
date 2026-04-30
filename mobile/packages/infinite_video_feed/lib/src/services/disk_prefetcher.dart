import 'package:media_cache/media_cache.dart';
import 'package:models/models.dart';

/// Resolves the URL to download for [video], or `null` to skip.
typedef PrefetchUrlResolver = String? Function(VideoEvent video);

/// Resolves an ordered list of cacheable URLs to attempt for [video].
///
/// The prefetcher tries each URL in sequence with a per-URL timeout,
/// moving to the next on failure. Return an empty list to skip the video.
typedef PrefetchUrlsResolver = List<String> Function(VideoEvent video);

/// Sequentially prefetches videos to disk via a [MediaCacheManager],
/// nearest first, with at most one active HTTP download at a time.
///
/// Each call to [run] cancels any in-flight cycle and starts a new one
/// scoped to the requested range. Cycles bump an internal generation so
/// late-arriving completions can detect they are stale and exit early.
class DiskPrefetcher {
  /// Creates a prefetcher backed by [cache]. [log] receives diagnostic
  /// messages for the active cycle.
  DiskPrefetcher({
    required MediaCacheManager cache,
    required void Function(String message) log,
  }) : _cache = cache,
       _log = log;

  /// Per-download stall timeout. If the underlying HTTP stream stops
  /// emitting events (progress or completion) for this long, the download
  /// is treated as hung, cancelled, and the next URL/index is tried.
  /// Slow but steadily-progressing downloads are not affected.
  static const _stallTimeout = Duration(seconds: 5);

  final MediaCacheManager _cache;
  final void Function(String) _log;

  CancellableCacheOperation? _active;
  int _generation = 0;
  int? _activeIndex;

  /// Whether [dispose] has been called. Once `true`, no new downloads start.
  bool isDisposed = false;

  // Mutable cycle parameters — the running loop reads these on each
  // iteration so a skipped `run()` can extend the range or swap in a
  // freshly-appended video list without restarting the download.
  int _cycleEndIndex = -1;
  List<VideoEvent> _cycleVideos = const [];
  PrefetchUrlsResolver _cycleResolveUrls = (_) => const [];

  /// Cancels the in-flight HTTP download (if any) and clears the active
  /// operation. Subsequent [run] calls start fresh.
  void cancelActive() {
    _active?.cancel();
    _active = null;
    _activeIndex = null;
  }

  /// Starts a new prefetch cycle covering `[startIndex..endIndex]`
  /// (inclusive). Indices outside `[0, videos.length)` are silently ignored.
  ///
  /// If there is already an active download whose index falls within
  /// `[startIndex..endIndex]`, the cycle is kept alive and the new call
  /// returns immediately instead of cancelling the in-flight download.
  ///
  /// Resolves each video's download URLs via [resolveUrls]. Skips entries
  /// that are already cached or that resolve to an empty URL list.
  Future<void> run({
    required int startIndex,
    required int endIndex,
    required List<VideoEvent> videos,
    required PrefetchUrlsResolver resolveUrls,
  }) async {
    // If the in-flight download is at most one position before the new
    // start and still within the end, let it finish — the running cycle
    // will continue into the overlapping range. This avoids restarting
    // the cycle on every single-step scroll.
    final activeIdx = _activeIndex;
    if (activeIdx != null &&
        activeIdx >= startIndex - 1 &&
        activeIdx <= endIndex &&
        _active != null &&
        !_active!.isCancelled) {
      // Extend the running cycle so it covers the new (potentially larger)
      // end and picks up freshly-appended videos.
      if (endIndex > _cycleEndIndex) _cycleEndIndex = endIndex;
      _cycleVideos = videos;
      _cycleResolveUrls = resolveUrls;
      _log(
        'Prefetch cycle still active — downloading index $activeIdx '
        'is near [$startIndex..$endIndex], extending end to '
        '$_cycleEndIndex',
      );
      return;
    }

    cancelActive();
    final generation = ++_generation;

    _cycleEndIndex = endIndex;
    _cycleVideos = videos;
    _cycleResolveUrls = resolveUrls;

    _log(
      'Prefetch cycle #$generation: range=[$startIndex..$endIndex]',
    );

    for (var i = startIndex; i <= _cycleEndIndex; i++) {
      if (isDisposed) return;

      if (_generation != generation) {
        // coverage:ignore-start
        _log(
          'Prefetch cycle #$generation aborted (stale)',
        );
        return;
        // coverage:ignore-end
      }
      if (i < 0 || i >= _cycleVideos.length) continue;

      final video = _cycleVideos[i];
      if (_cache.getCachedFileSync(video.id) != null) {
        _log('Prefetch skip index $i — already cached (${video.id})');
        continue;
      }

      final urls = _cycleResolveUrls(video);
      if (urls.isEmpty) {
        _log('Prefetch skip index $i — no URLs');
        continue;
      }

      await _downloadWithFallbacks(i, video.id, urls, generation);
    }

    _log('Prefetch cycle #$generation finished');
    _active = null;
    _activeIndex = null;
  }

  /// Tries each URL in [urls] in sequence, applying a stall timeout per
  /// attempt. Returns as soon as one succeeds or all URLs are exhausted.
  Future<void> _downloadWithFallbacks(
    int index,
    String videoId,
    List<String> urls,
    int generation,
  ) async {
    for (var attempt = 0; attempt < urls.length; attempt++) {
      if (_generation != generation || isDisposed) return;

      final url = urls[attempt];
      final isRetry = attempt > 0;

      _log(
        'Prefetch ${isRetry ? 'fallback ' : ''}downloading index $index '
        '($videoId) url=$url',
      );

      final op = _cache.cacheFileCancellable(
        url,
        key: videoId,
        stallTimeout: _stallTimeout,
      );
      _active = op;
      _activeIndex = index;

      final file = await op.file;

      if (op.didStall) {
        _log(
          'Prefetch stalled index $index ($videoId) url=$url '
          '(no progress for ${_stallTimeout.inSeconds}s)',
        );
        // Stall counts as a failed attempt — try next URL.
        continue;
      }

      if (op.isCancelled) {
        // Cancelled externally (new cycle started).
        _log('Prefetch download cancelled at index $index ($videoId)');
        return;
      }

      if (file != null) {
        _log('Prefetch completed index $index ($videoId)');
        return;
      }

      // file == null but not cancelled → download failed (e.g. 404).
      _log(
        'Prefetch failed index $index ($videoId) url=$url'
        '${attempt < urls.length - 1 ? ' — trying next URL' : ''}',
      );
    }
  }

  /// Releases the active download. Safe to call from `State.dispose`.
  void dispose() {
    isDisposed = true;
    cancelActive();
  }
}
