import 'dart:async';
import 'dart:io';

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
  /// messages for the active cycle. [stallTimeout] caps how long a single
  /// download attempt may sit without completing before it is cancelled
  /// and the next fallback URL is tried. Mobile networks can leave HTTP
  /// connections silently idle (no bytes, no error event); without this
  /// guard a stalled stream would block the entire prefetch cycle.
  DiskPrefetcher({
    required MediaCacheManager cache,
    required void Function(String message) log,
    Duration stallTimeout = const Duration(seconds: 8),
  }) : _cache = cache,
       _log = log,
       _stallTimeout = stallTimeout;

  final MediaCacheManager _cache;
  final void Function(String) _log;
  final Duration _stallTimeout;

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
  // coverage:ignore-start
  PrefetchUrlsResolver _cycleResolveUrls = (_) => const [];
  // coverage:ignore-end

  /// Cancels the in-flight HTTP download (if any) and clears the active
  /// operation. Subsequent [run] calls start fresh.
  ///
  /// Note: this only stops the current download. A cycle started by [run] is
  /// driven by a loop that keeps advancing to the next index unless the
  /// generation changes — so on its own this does not halt an in-flight
  /// cycle, it just makes the running download return early before the loop
  /// moves on. Callers that need the whole cycle to stop (e.g. pausing
  /// prefetch while a feed is backgrounded) must use [cancelCycle].
  void cancelActive() {
    _active?.cancel();
    _active = null;
    _activeIndex = null;
  }

  /// Cancels the in-flight download and halts the running cycle so no further
  /// videos are fetched until the next [run].
  ///
  /// Bumps the generation, which the [run] loop checks on every iteration, so
  /// the loop exits instead of advancing to the next index after the current
  /// download is cancelled.
  void cancelCycle() {
    _generation++;
    cancelActive();
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
        _log('Prefetch cycle #$generation aborted (stale)');
        return;
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

  /// Tries each URL in [urls] in sequence.
  /// Returns as soon as one succeeds or all URLs are exhausted.
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

      // Use a unique cache key per fallback attempt so a partially or
      // incorrectly cached entry from a previous URL can never be
      // returned by `getFileStream` for a later fallback URL. The alias
      // key (videoId) keeps the synchronous manifest lookup stable for
      // consumers regardless of which attempt eventually succeeded.
      final downloadKey = isRetry ? '${videoId}__fb$attempt' : videoId;

      _log(
        'Prefetch ${isRetry ? 'fallback ' : ''}downloading index $index '
        '($videoId) url=$url key=$downloadKey',
      );

      final op = _cache.cacheFileCancellable(
        url,
        key: downloadKey,
        aliasKey: isRetry ? videoId : null,
      );
      _active = op;
      _activeIndex = index;

      File? file;
      var didStall = false;
      try {
        file = await op.file.timeout(_stallTimeout);
      } on TimeoutException {
        didStall = true;
        op.cancel();
        _log(
          'Prefetch stalled index $index ($videoId) url=$url '
          '— cancelling after ${_stallTimeout.inSeconds}s',
        );
      }

      if (op.isCancelled && !didStall) {
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
