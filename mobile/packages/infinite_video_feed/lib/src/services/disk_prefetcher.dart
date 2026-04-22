import 'package:media_cache/media_cache.dart';
import 'package:models/models.dart';

/// Resolves the URL to download for [video], or `null` to skip.
typedef PrefetchUrlResolver = String? Function(VideoEvent video);

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

  final MediaCacheManager _cache;
  final void Function(String) _log;

  CancellableCacheOperation? _active;
  int _generation = 0;

  /// Cancels the in-flight HTTP download (if any) and clears the active
  /// operation. Subsequent [run] calls start fresh.
  void cancelActive() {
    _active?.cancel();
    _active = null;
  }

  /// Starts a new prefetch cycle covering `[startIndex..endIndex]`
  /// (inclusive). Indices outside `[0, videos.length)` are silently ignored.
  ///
  /// Resolves each video's download URL via [resolveUrl]. Skips entries
  /// that are already cached or that resolve to a missing URL.
  Future<void> run({
    required int startIndex,
    required int endIndex,
    required List<VideoEvent> videos,
    required PrefetchUrlResolver resolveUrl,
  }) async {
    cancelActive();
    final generation = ++_generation;

    _log(
      'Prefetch cycle #$generation: range=[$startIndex..$endIndex]',
    );

    for (var i = startIndex; i <= endIndex; i++) {
      if (_generation != generation) {
        // coverage:ignore-start
        _log(
          'Prefetch cycle #$generation aborted (stale)',
        );
        return;
        // coverage:ignore-end
      }
      if (i < 0 || i >= videos.length) continue;

      final video = videos[i];
      if (_cache.getCachedFileSync(video.id) != null) {
        _log('Prefetch skip index $i — already cached (${video.id})');
        continue;
      }

      final url = resolveUrl(video);
      if (url == null || url.isEmpty) {
        _log('Prefetch skip index $i — no URL');
        continue;
      }

      _log('Prefetch downloading index $i (${video.id})');
      final op = _cache.cacheFileCancellable(url, key: video.id);
      _active = op;

      final file = await op.file;

      if (op.isCancelled) {
        _log('Prefetch download cancelled at index $i (${video.id})');
        return;
      }

      _log(
        file != null
            ? 'Prefetch completed index $i (${video.id})'
            : 'Prefetch failed index $i (${video.id})',
      );
    }

    _log('Prefetch cycle #$generation finished');
    _active = null;
  }

  /// Releases the active download. Safe to call from `State.dispose`.
  void dispose() => cancelActive();
}
