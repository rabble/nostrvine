# media_cache

A reusable media caching package built on `flutter_cache_manager`.

## Features

- **Configurable cache** - Size, stale period, timeouts, and connection limits
- **Corrupt cache recovery** - Automatically handles corrupted cache files via `SafeCacheInfoRepository`
- **Sync manifest** - Optional in-memory manifest for instant file lookups (no async overhead)
- **Preset configurations** - Optimized defaults for videos and images

## Usage

### Video Caching with Sync Manifest

For video players that need instant file access:

```dart
// Create a video cache with sync manifest enabled
final videoCache = MediaCacheManager(
  config: MediaCacheConfig.video(cacheKey: 'my_video_cache'),
);

// Initialize on app startup (loads manifest for sync lookups)
await videoCache.initialize();

// Get cached file synchronously - no async overhead
final file = videoCache.getCachedFileSync('video_123');
if (file != null) {
  // Use cached file immediately
  controller = VideoPlayerController.file(file);
} else {
  // Fall back to network
  controller = VideoPlayerController.networkUrl(Uri.parse(url));
  // Cache in background for next time
  unawaited(videoCache.cacheFile(url, key: 'video_123'));
}
```

### Image Caching with CachedNetworkImage

```dart
final imageCache = MediaCacheManager(
  config: MediaCacheConfig.image(cacheKey: 'my_image_cache'),
);

// Use with CachedNetworkImage widget
CachedNetworkImage(
  imageUrl: 'https://example.com/image.jpg',
  cacheManager: imageCache,
)
```

### Custom Configuration

```dart
final customCache = MediaCacheManager(
  config: MediaCacheConfig(
    cacheKey: 'custom_cache',
    stalePeriod: Duration(days: 7),
    maxNrOfCacheObjects: 100,
    connectionTimeout: Duration(seconds: 20),
    enableSyncManifest: true,
    onInfo: (msg) => log.info(msg),
    onError: (msg) => log.error(msg),
  ),
);
```

### Pre-caching Multiple Files

```dart
await videoCache.preCacheFiles(
  [
    (url: 'https://example.com/video1.mp4', key: 'video_1'),
    (url: 'https://example.com/video2.mp4', key: 'video_2'),
    (url: 'https://example.com/video3.mp4', key: 'video_3'),
  ],
  batchSize: 3, // Concurrent downloads
);
```

## Configuration Presets

### Video Preset (`MediaCacheConfig.video`)

Optimized for large video files:
- Stale period: 30 days
- Max objects: 1000
- Connection timeout: 30 seconds
- Idle timeout: 2 minutes
- Max connections per host: 4
- Sync manifest: enabled

### Image Preset (`MediaCacheConfig.image`)

Optimized for smaller image files:
- Stale period: 7 days
- Max objects: 200
- Connection timeout: 10 seconds
- Idle timeout: 30 seconds
- Max connections per host: 6
- Sync manifest: disabled