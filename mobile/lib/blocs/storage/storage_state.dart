part of 'storage_cubit.dart';

/// Lifecycle of the cache section.
enum StorageCacheStatus {
  /// Not loaded yet.
  initial,

  /// Computing the current cache size.
  loading,

  /// Size known and idle.
  ready,

  /// A clear operation is running.
  clearing,

  /// A clear operation just finished. Idle like [ready], but distinct so the
  /// UI can announce the clear to screen readers without inferring it from a
  /// zero size (which also happens when an already-empty cache is loaded).
  cleared,

  /// The last cache operation failed.
  failure,
}

/// Lifecycle of the clip-library audit section.
enum StorageLibraryStatus {
  /// Not scanned yet.
  idle,

  /// A scan is running.
  scanning,

  /// Scan complete; see [StorageState.brokenClips].
  scanned,

  /// Removing the broken clips.
  cleaning,

  /// Broken clips removed.
  cleaned,

  /// The last library operation failed.
  failure,
}

/// State for the settings "Storage" screen.
class StorageState extends Equatable {
  /// Creates a state.
  const StorageState({
    this.cacheStatus = StorageCacheStatus.initial,
    this.cacheSizeBytes = 0,
    this.cacheLimitBytes = kCacheLimitDefaultBytes,
    this.libraryStatus = StorageLibraryStatus.idle,
    this.brokenClips = const [],
  });

  /// Lifecycle of the cache section.
  final StorageCacheStatus cacheStatus;

  /// Bytes currently held by the clearable caches.
  final int cacheSizeBytes;

  /// The configured maximum video-cache size, in bytes.
  final int cacheLimitBytes;

  /// Lifecycle of the clip-library audit section.
  final StorageLibraryStatus libraryStatus;

  /// Library clips whose backing file is missing (populated after a scan).
  final List<DivineVideoClip> brokenClips;

  /// Returns a copy with the given fields replaced.
  StorageState copyWith({
    StorageCacheStatus? cacheStatus,
    int? cacheSizeBytes,
    int? cacheLimitBytes,
    StorageLibraryStatus? libraryStatus,
    List<DivineVideoClip>? brokenClips,
  }) {
    return StorageState(
      cacheStatus: cacheStatus ?? this.cacheStatus,
      cacheSizeBytes: cacheSizeBytes ?? this.cacheSizeBytes,
      cacheLimitBytes: cacheLimitBytes ?? this.cacheLimitBytes,
      libraryStatus: libraryStatus ?? this.libraryStatus,
      brokenClips: brokenClips ?? this.brokenClips,
    );
  }

  @override
  List<Object?> get props => [
    cacheStatus,
    cacheSizeBytes,
    cacheLimitBytes,
    libraryStatus,
    brokenClips,
  ];
}
