/// A reusable media caching package built on flutter_cache_manager.
///
/// Provides configurable caching for videos, images, and other media files
/// with corrupt cache recovery and optional synchronous file lookups.
///
/// ## Features
///
/// - **Configurable cache**: Size, stale period, timeouts, and connection
///   limits
/// - **Corrupt cache recovery**: Automatically handles corrupted cache files
/// - **Sync manifest**: Optional in-memory manifest for instant file lookups
/// - **Preset configurations**: Optimized defaults for videos and images
///
/// ## Quick Start
///
/// ```dart
/// // Create a video cache with sync manifest for instant playback
/// final videoCache = MediaCacheManager(
///   config: MediaCacheConfig.video(cacheKey: 'my_video_cache'),
/// );
///
/// // Initialize on app startup (loads manifest for sync lookups)
/// await videoCache.initialize();
///
/// // Get cached file synchronously (no async overhead)
/// final file = videoCache.getCachedFileSync('video_123');
/// if (file != null) {
///   // Use cached file immediately
///   videoController = VideoPlayerController.file(file);
/// } else {
///   // Fall back to network
///   videoController = VideoPlayerController.networkUrl(Uri.parse(url));
///   // Cache in background for next time
///   unawaited(videoCache.cacheFile(url, key: 'video_123'));
/// }
/// ```
///
/// ## Image Caching with CachedNetworkImage
///
/// ```dart
/// final imageCache = MediaCacheManager(
///   config: MediaCacheConfig.image(cacheKey: 'my_image_cache'),
/// );
///
/// // Use with CachedNetworkImage widget
/// CachedNetworkImage(
///   imageUrl: 'https://example.com/image.jpg',
///   cacheManager: imageCache,
/// )
/// ```
library;

export 'src/media_cache_manager.dart' show MediaCacheConfig, MediaCacheManager;
export 'src/safe_cache_info_repository.dart'
    show DirectoryProvider, SafeCacheInfoRepository;
