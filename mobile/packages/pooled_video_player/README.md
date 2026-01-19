# Pooled Video Player

Headless video controller pool manager for Flutter short-form video feeds.

## Features

- 🎯 **Singleton Pattern** - Global pool manager with ChangeNotifier
- 🔄 **LRU Eviction** - Priority-based management (active > prewarm > cached)
- ⚡ **Smart Preloading** - Active + next + previous videos
- 💾 **Memory Pressure** - Progressive controller release
- 🔋 **Lifecycle Management** - Background/foreground handling
- 📱 **Optimized** - 7-second Vine-style videos
- 🎨 **Headless** - Bring your own UI via builder callbacks
- 🚫 **No BLoC** - Uses singleton + ChangeNotifier pattern

## Why Headless?

This package **does NOT provide any UI** - it only manages video controller pooling. You provide your own UI via builder callbacks. This allows:
- Complete UI customization
- No opinionated styling
- Easy integration into existing apps
- Standard Flutter patterns (builders, callbacks)

## Installation

```yaml
dependencies:
  pooled_video_player:
    path: mobile/packages/pooled_video_player
```

## Quick Start

### 1. Initialize the Pool (in main.dart)

```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Determine pool size based on device memory
  final tier = await DeviceMemoryUtil.getMemoryTier();
  final poolSize = switch (tier) {
    MemoryTier.low => 2,      // ≤2GB Android, ≤3GB iOS
    MemoryTier.medium => 3,   // 3-4GB RAM
    MemoryTier.high => 4,     // >4GB RAM
  };

  // Initialize singleton pool
  await VideoControllerPoolManager.initialize(poolSize: poolSize);

  runApp(MyApp());
}
```

### 2. Implement PooledVideo Interface

```dart
import 'package:pooled_video_player/pooled_video_player.dart';

class MyVideo implements PooledVideo {
  @override
  String get id => myVideoId;

  @override
  String get videoUrl => myPlayableUrl;

  @override
  String? get thumbnailUrl => myThumbnail;
}
```

### 3. Use PooledVideoPlayer (Standalone)

The `PooledVideoPlayer` widget is **headless** - it manages the controller lifecycle but requires you to provide UI via the `builder` callback:

```dart
PooledVideoPlayer(
  video: myVideo,
  autoPlay: true,
  builder: (context, controller, child) {
    // controller is null while loading
    if (controller == null || !controller.value.isInitialized) {
      return MyLoadingUI(); // Your loading UI
    }

    // Render your custom UI with the controller
    return Stack(
      children: [
        AspectRatio(
          aspectRatio: controller.value.aspectRatio,
          child: VideoPlayer(controller), // from video_player package
        ),
        // Your custom overlay, controls, etc.
        MyCustomControls(controller: controller),
        MyVideoMetadata(video: myVideo),
      ],
    );
  },
)
```

### 4. Use PooledVideoFeed (Swipeable Feed)

The `PooledVideoFeed` widget is also **headless** - it manages navigation and preloading but requires you to render each item:

```dart
PooledVideoFeed(
  videos: myVideos,
  initialIndex: 0,
  onActiveVideoChanged: (video, index) {
    print('Now showing: ${video.id} at index $index');
  },
  itemBuilder: (context, video, index, isActive) {
    // You render each item however you want
    return MyCustomVideoItem(
      video: video,
      isActive: isActive,
      // Inside MyCustomVideoItem, you can use PooledVideoPlayer
      // or directly access the pool via VideoControllerPoolManager.instance
    );
  },
)
```

## Advanced Usage

### Listen to Pool State Changes

```dart
final pool = VideoControllerPoolManager.instance;

pool.addListener(() {
  // Pool state changed (controller assigned, evicted, etc.)
  final controller = pool.getController('video-id');
  // Update your UI
});
```

### Access Pool Directly

```dart
final pool = VideoControllerPoolManager.instance;

// Acquire controller manually
final pooled = await pool.acquireController(
  videoId: 'my-video-id',
  videoUrl: 'https://example.com/video.mp4',
);

// Get controller
final controller = pool.getController('video-id');

// Release controller
pool.releaseController('video-id');

// Set active video (highest priority, won't be evicted)
pool.setActiveVideo('video-id');

// Prewarm videos (preload next/previous)
pool.setPrewarmVideos(['next-id', 'previous-id']);
```

### Handle Memory Pressure

```dart
// The pool automatically handles memory pressure, but you can trigger manually:
await VideoControllerPoolManager.instance.handleMemoryPressure();
```

### Clear Pool on Feed Refresh

```dart
// When refreshing the feed (pull-to-refresh), clear the pool:
await VideoControllerPoolManager.instance.clearPool();
```

## Architecture

### Components

- **VideoControllerPoolManager** - Singleton managing the controller pool with ChangeNotifier
- **PooledVideoPlayer** - Headless widget for single video playback (requires `builder`)
- **PooledVideoFeed** - Headless PageView-based feed with preloading (requires `itemBuilder`)
- **PooledVideo** - Interface your video models implement

### How It Works

1. **Pool Initialization** - Singleton created with fixed size (2-4 controllers)
2. **Controller Acquisition** - Videos request controllers from the pool
3. **LRU Eviction** - When pool is full, least recently used controller is evicted
4. **Priority System** - Active video > Prewarmed videos > Cached videos
5. **Preloading** - Next + previous videos are preloaded automatically
6. **State Notifications** - Pool notifies listeners when controllers change

### video_player Limitation

The `video_player` package (v2.9.1) does NOT support changing URLs after controller creation. This package uses a hybrid approach:
- Fixed pool size prevents unbounded memory growth
- Controllers are disposed/recreated when reassigned to new URLs
- For 7-second videos, codec overhead is minimal (~50-100ms)

For true controller reuse, consider the `media_kit` package.

## Testing

```dart
// Reset pool between tests
await VideoControllerPoolManager.reset();

// Initialize with test pool size
await VideoControllerPoolManager.initialize(poolSize: 2);
```

## Migration from BLoC Version

If migrating from the old BLoC-based version:

1. **Remove BLoC dependencies** - No more `flutter_bloc`, `bloc_test`, or `BlocProvider`
2. **Initialize pool in main()** - Use `VideoControllerPoolManager.initialize()`
3. **Update widget usage** - Add required `builder` callback to `PooledVideoPlayer`
4. **Update feed usage** - Add required `itemBuilder` callback to `PooledVideoFeed`
5. **Remove BLoC providers** - No need to wrap widgets in `BlocProvider`

## License

MIT
