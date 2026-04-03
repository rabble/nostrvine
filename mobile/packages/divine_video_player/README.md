# divine_video_player

Seamless multi-clip video player using native platform APIs.

## Features

- Seamless playback across multiple video clips with no delay
- Continuous timeline with global position tracking
- Native implementations: Media3/ExoPlayer (Android), AVFoundation (iOS/macOS)
- Preloading and buffering handled natively
- Looping, clip jumping, and playback speed control
- Multi-track audio overlays synced to the video timeline
- Optional texture rendering for Flutter widget compositing (e.g. `ColorFiltered`)
- Placeholder widget support to hide black frames before first frame renders
- Native video caching
- App lifecycle handling (auto-pause on background, resume on foreground)

## Usage

```dart
import 'package:divine_video_player/divine_video_player.dart';

// Create controller
final controller = DivineVideoPlayerController();
await controller.initialize();

// Single video
await controller.setSource(
  VideoClip(uri: '/path/to/video.mp4'),
);

// Network URL
await controller.setSource(
  VideoClip(uri: 'https://example.com/video.mp4'),
);

// Flutter asset (copies to temp file)
await controller.setSource(
  await VideoClip.asset('assets/intro.mp4'),
);

// In-memory bytes (writes to temp file)
await controller.setSource(
  await VideoClip.memory(bytes, fileName: 'clip.mp4'),
);

// Or multiple clips as a continuous timeline
await controller.setClips([
  VideoClip(
    uri: '/path/to/video1.mp4',
    start: Duration.zero,
    end: const Duration(seconds: 5),
  ),
  VideoClip(
    uri: '/path/to/video2.mp4',
    start: const Duration(seconds: 2),
    end: const Duration(seconds: 8),
  ),
]);

// Playback
await controller.play();
await controller.pause();
await controller.stop();         // clears surface, resets position
await controller.seekTo(const Duration(seconds: 10));
await controller.jumpToClip(1);  // jump to clip at index
await controller.setPlaybackSpeed(1.5);
await controller.setLooping(looping: true);

// Audio overlays (e.g. background music, synced to video timeline)
await controller.setAudioTracks([
  AudioTrack(
    uri: 'https://cdn.com/music.mp3',
    videoStartTime: const Duration(seconds: 5),
    videoEndTime: const Duration(seconds: 35),
    trackStart: const Duration(seconds: 10),
    trackEnd: const Duration(seconds: 40),
    volume: 0.8,
  ),
]);

// Independent volume control
await controller.setVolume(0.5);              // video audio
await controller.setAudioTrackVolume(0, 0.8); // overlay track at index

// Remove all overlay audio
await controller.removeAllAudioTracks();

// Render with a placeholder while the first frame loads
DivineVideoPlayerWidget(
  controller: controller,
  placeholder: const Center(child: CircularProgressIndicator()),
);

// Listen to state changes
controller.stateStream.listen((state) {
  print('Position: ${state.position}');
  print('Status: ${state.status}');
  print('Clip: ${state.currentClipIndex}/${state.clipCount}');
});

// Wait for first frame
await controller.firstFrameRendered;

// Dispose when done
await controller.dispose();
```

### Preloading & caching

Pre-buffer upcoming videos so playback starts instantly:

```dart
// Configure the native cache (call once at app startup)
await DivineVideoPlayerController.configureCache(
  maxSizeBytes: 500 * 1024 * 1024, // 500 MB
);

// Preload into the cache without creating a player
await DivineVideoPlayerController.preload([
  VideoClip(uri: 'https://example.com/next-video.mp4'),
]);
```

### Texture rendering

By default the player renders via a native platform view. When you need
Flutter widgets like `ColorFiltered` to affect the video pixels — for
example in a video editor — enable texture mode:

```dart
final controller = DivineVideoPlayerController(useTexture: true);
await controller.initialize();
```

The widget automatically uses a `Texture` widget when `useTexture` is
enabled and falls back to the platform view otherwise.

## Platform Requirements

- Android: API 28+
- iOS: 16.0+
- macOS: 13.0+
