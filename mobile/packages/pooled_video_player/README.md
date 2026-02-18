# pooled_video_player

Efficient video playback with object pooling for short-form video feeds. Built on [media_kit](https://pub.dev/packages/media_kit).

## Overview

`pooled_video_player` manages a shared pool of native video players with LRU eviction, so scrolling through a feed reuses players instead of creating and destroying them on every swipe. It handles preloading adjacent videos, buffer management, and playback lifecycle automatically.

### Key components

| Component | Role |
|---|---|
| `PlayerPool` | Singleton pool of native `media_kit` players with LRU eviction |
| `VideoFeedController` | Manages preloading, play/pause, and page changes for a feed |
| `PooledVideoFeed` | Drop-in `PageView` widget with automatic preloading |
| `PooledVideoPlayer` | Renders a single video slot (video, loading, error, or disabled state) |
| `SingleVideoPlayer` | Standalone player that shares the pool (for detail pages) |

## Setup

Initialize once at app startup, after `WidgetsFlutterBinding.ensureInitialized()`:

```dart
import 'package:pooled_video_player/pooled_video_player.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  await PlayerPool.init(config: VideoPoolConfig(maxPlayers: 5));

  runApp(MyApp());
}
```

## Basic usage

### Using `PooledVideoFeed`

The simplest way to create a video feed with automatic preloading:

```dart
PooledVideoFeed(
  videos: videos,
  initialIndex: 0,
  preloadAhead: 2,
  preloadBehind: 1,
  onActiveVideoChanged: (video, index) {
    // Track active video
  },
  onNearEnd: (index) {
    // Load more videos (pagination)
  },
  itemBuilder: (context, video, index, {required isActive}) {
    return PooledVideoPlayer(
      index: index,
      thumbnailUrl: video.thumbnailUrl,
      videoBuilder: (context, videoController, player) {
        return Video(
          controller: videoController,
          fit: BoxFit.cover,
          controls: NoVideoControls,
        );
      },
      overlayBuilder: (context, videoController, player) {
        return MyOverlay(video: video, isActive: isActive);
      },
      loadingBuilder: (context) {
        return MyLoadingPlaceholder(thumbnailUrl: video.thumbnailUrl);
      },
    );
  },
)
```

### Using `VideoFeedController` directly

For full control, create and manage the controller yourself:

```dart
final controller = VideoFeedController(
  videos: videoItems,
  pool: PlayerPool.instance,
  initialIndex: 0,
  onVideoReady: (index, player) {
    // Trigger background caching, analytics, etc.
  },
  positionCallback: (index, position) {
    // Loop enforcement, progress tracking, etc.
  },
);

// Wire to your PageView
controller.onPageChanged(newIndex);
controller.play();
controller.pause();
controller.togglePlayPause();
controller.seek(Duration(seconds: 5));

// Add more videos (pagination)
controller.addVideos(newVideos);

// Pause/release all players (e.g., navigating away)
controller.setActive(active: false);

// Resume
controller.setActive(active: true);
```

### Using `SingleVideoPlayer`

For detail pages where you need a single video but still want pool sharing:

```dart
SingleVideoPlayer(
  video: VideoItem(id: 'abc', url: 'https://example.com/video.mp4'),
  autoPlay: true,
  videoBuilder: (context, videoController, player) {
    return Video(controller: videoController, fit: BoxFit.contain);
  },
)
```

## Hooks

`VideoFeedController` supports hooks for integrating with caching, analytics,
and playback control without subclassing:

| Hook | Purpose |
|---|---|
| `mediaSourceResolver` | Return a cached file path instead of the original URL |
| `onVideoReady` | Trigger background caching or analytics when a video is buffered |
| `positionCallback` | Periodic position updates for loop enforcement or progress tracking |

```dart
VideoFeedController(
  videos: videos,
  mediaSourceResolver: (video) {
    // Return cached path or null to use original URL
    return cacheService.getCachedPath(video.url);
  },
  onVideoReady: (index, player) {
    bloc.add(VideoCacheStarted(index: index));
  },
  positionCallback: (index, position) {
    bloc.add(PositionUpdated(index: index, position: position));
  },
  positionCallbackInterval: Duration(milliseconds: 100),
)
```

## Per-index state

Use `VideoFeedController.getIndexNotifier(index)` for granular widget updates.
Each index gets its own `ValueNotifier<VideoIndexState>` so only the affected
video widget rebuilds when its state changes:

```dart
ValueListenableBuilder<VideoIndexState>(
  valueListenable: controller.getIndexNotifier(index),
  builder: (context, state, _) {
    if (state.isReady) {
      return Video(controller: state.videoController!);
    }
    if (state.isLoading) {
      return LoadingSpinner();
    }
    return Placeholder();
  },
)
```

## iOS Simulator

`media_kit` uses software video decoding on the iOS simulator, which is unstable
and causes native-level crashes (even with a single player). To allow developers
to test the rest of the app, `VideoFeedController` automatically detects the iOS
simulator via `device_info_plus` and skips native player creation entirely.

When running on the iOS simulator:

- **Feed navigation works** — `PageView` swiping, thumbnails, and overlays are
  fully functional.
- **Video playback is disabled** — videos show their thumbnail instead of
  playing. The `LoadState` is set to `disabled`.
- **Overlay actions are visible** — the `overlayBuilder` receives `null` for
  `videoController` and `player`, but UI elements like like/comment/repost
  buttons render normally.

No configuration is needed. The detection is automatic and cached after the
first check.

### Testing on simulator

The overlay builder signature accepts nullable player params to support this:

```dart
overlayBuilder: (context, videoController, player) {
  // videoController and player are null on iOS simulator.
  // UI-only overlays (likes, comments, etc.) work without them.
  return MyOverlayActions(video: video);
},
```

## Testing

`PlayerPool` and `VideoFeedController` are designed for testability:

```dart
// Use a custom pool instance (not the singleton)
final pool = PlayerPool(maxPlayers: 3);

// Create controller with injected pool
final controller = VideoFeedController(
  videos: testVideos,
  pool: pool,
);

// Reset simulator detection cache between tests
VideoFeedController.resetSimulatorDetection();

// Replace the singleton for integration tests
PlayerPool.instanceForTesting = mockPool;
```
