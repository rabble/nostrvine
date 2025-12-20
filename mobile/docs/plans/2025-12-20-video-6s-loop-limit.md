# Video 6.3s Playback Loop Limit

## Summary

Enforce a 6.3 second maximum playback duration for feed videos. Videos longer than 6.3 seconds will loop back to the beginning at the 6.3s mark.

## Background

- Recording already enforces 6.3s limit at capture time
- This adds playback enforcement for any videos that exceed the limit
- Matches original Vine behavior (6 second loops)

## Implementation

### Location

`lib/providers/individual_video_providers.dart` in `individualVideoControllerProvider`

### Approach: Throttled Position Check

Use `Timer.periodic` with 200ms interval to check video position.

### Constants (add near top of file)

```dart
/// Maximum playback duration before looping (6.3 seconds)
const maxPlaybackDuration = Duration(milliseconds: 6300);

/// Interval for checking playback position (200ms = 5 checks/sec)
const loopCheckInterval = Duration(milliseconds: 200);
```

### Timer Declaration (inside provider function, ~line 203)

```dart
Timer? loopEnforcementTimer;  // Declare with other timers
```

### Timer Start (in initFuture.then(), AFTER setLooping(true) ~line 444)

```dart
controller.setLooping(true);  // Existing line 444

// Start loop enforcement timer for long videos only
final videoDuration = controller.value.duration;
if (videoDuration > maxPlaybackDuration) {
  loopEnforcementTimer = Timer.periodic(loopCheckInterval, (timer) {
    if (!controller.value.isPlaying) return;

    if (controller.value.position >= maxPlaybackDuration) {
      Log.debug(
        '🔄 Loop enforcement: ${params.videoId} at ${controller.value.position.inMilliseconds}ms',
        name: 'LoopEnforcement',
        category: LogCategory.video,
      );
      safeSeekTo(controller, params.videoId, Duration.zero);
    }
  });
}
```

### Timer Cleanup (in ref.onDispose(), add before existing cleanup)

```dart
ref.onDispose(() {
  loopEnforcementTimer?.cancel();  // Add this line
  cacheTimer?.cancel();
  // ... existing cleanup
});
```

### Timer Cleanup on Controller Recreation (before ref.invalidateSelf() ~line 568)

```dart
if (_isCacheCorruption(errorMessage) && !kIsWeb) {
  loopEnforcementTimer?.cancel();  // Cancel timer before invalidating
  openVineVideoCache.removeCorruptedVideo(params.videoId).then((_) {
    if (ref.mounted) {
      ref.invalidateSelf();
    }
  });
}
```

### Key Design Decisions

**Why Timer.periodic instead of per-frame listener?**
Per-frame listeners fire ~60 times/second causing potential jank. Periodic timer at 200ms = 5 checks/second (92% reduction).

**Why not single timer at 6.3s?**
A single timer breaks when video buffers/stalls, user seeks, or playback rate changes. Periodic position check handles all correctly.

**Why check duration once at timer creation?**
Video duration is static after initialization. No need to check 5 times/second.

**Why safeSeekTo instead of controller.seekTo?**
Handles controller disposal gracefully (user scrolls away mid-seek).

### Scope

- **Affected:** Feed videos via `individualVideoControllerProvider`
- **Not affected:** Local clip editing/preview (they create own controllers)

### Edge Cases

| Case | Behavior |
|------|----------|
| Video < 6.3s | No timer created, native loop handles it |
| Video paused | Timer skips position check |
| Rapid pause/unpause | Timer keeps running, checks are cheap |
| Buffering | Position check reads actual position, not elapsed time |
| Seek to 5s | Next check at 5.2s, loops at 6.3s correctly |
| Controller recreation | Timer cancelled before invalidateSelf |
| Controller disposed | safeSeekTo handles gracefully |

### Tolerance

Worst case: video loops at 6.5s instead of 6.3s (200ms tolerance). Acceptable for UX.

## Files to Modify

1. `lib/providers/individual_video_providers.dart` - Add timer logic

## Testing

### Manual Tests
1. Play video longer than 6.3s - should loop at ~6.3s
2. Play video shorter than 6.3s - should loop naturally at end
3. Pause at 5s, wait, unpause - should loop at 6.3s
4. Rapid pause/unpause - no jank or missed loops
5. Scroll away during playback - no crashes

### Unit Tests Required
1. Timer cancellation on disposal
2. No timer created for videos < 6.3s
3. safeSeekTo called when position >= 6.3s

### Integration Tests Required
1. Video loops at 6.3s mark (not at natural end)
2. Timer survives pause/unpause cycles
3. Multiple videos don't interfere with each other's timers
