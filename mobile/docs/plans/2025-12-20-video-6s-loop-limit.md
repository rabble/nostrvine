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

Use `Timer.periodic` with 200ms interval to check video position:

```dart
const maxPlaybackDuration = Duration(milliseconds: 6300);
const checkInterval = Duration(milliseconds: 200);

Timer? loopEnforcementTimer;

loopEnforcementTimer = Timer.periodic(checkInterval, (timer) {
  // Skip if not playing
  if (!controller.value.isPlaying) return;

  // Skip if video is shorter than limit (native loop handles it)
  if (controller.value.duration <= maxPlaybackDuration) return;

  // Enforce loop at 6.3s
  if (controller.value.position >= maxPlaybackDuration) {
    controller.seekTo(Duration.zero);
  }
});
```

### Why Not Per-Frame Listener?

Per-frame listeners fire ~60 times/second causing potential jank. Periodic timer at 200ms = 5 checks/second (92% reduction).

### Why Not Single Timer?

A single timer approach (fire once at 6.3s) breaks when:
- Video buffers/stalls (timer keeps running, video doesn't)
- User seeks to different position
- Playback rate changes

Periodic position check handles all these correctly.

### Cleanup

Cancel timer in `ref.onDispose()`:

```dart
ref.onDispose(() {
  loopEnforcementTimer?.cancel();
  // ... existing cleanup
});
```

### Scope

- **Affected:** Feed videos via `individualVideoControllerProvider`
- **Not affected:** Local clip editing/preview (they create own controllers)

### Edge Cases

| Case | Behavior |
|------|----------|
| Video < 6.3s | Skip enforcement, native loop handles it |
| Video paused | Skip position check |
| Rapid pause/unpause | Timer keeps running, checks are cheap |
| Buffering | Position check reads actual position, not elapsed time |
| Seek to 5s | Next check at 5.2s, loops at 6.3s correctly |

### Tolerance

Worst case: video loops at 6.5s instead of 6.3s (200ms tolerance). Acceptable for UX.

## Files to Modify

1. `lib/providers/individual_video_providers.dart` - Add timer logic

## Testing

1. Play video longer than 6.3s - should loop at ~6.3s
2. Play video shorter than 6.3s - should loop naturally at end
3. Pause at 5s, wait, unpause - should loop at 6.3s
4. Rapid pause/unpause - no jank or missed loops
