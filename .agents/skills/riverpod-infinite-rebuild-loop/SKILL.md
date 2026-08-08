---
name: riverpod-infinite-rebuild-loop
description: |
  Debug and fix infinite widget rebuild loops in Flutter apps using Riverpod state management.
  Use when: (1) Logs show "RAPID REBUILD" warnings or 50+ rebuilds in seconds, (2) UI becomes
  unresponsive or shows same content repeatedly, (3) Bug only affects slower devices or poor
  network conditions, (4) Provider watching creates circular dependencies with router/URL state.
  Covers ref.watch() overuse, watch+listener redundancy, and transitive dependency chains.
author: Claude Code
version: 1.0.0
date: 2026-02-02
---

# Riverpod Infinite Rebuild Loop

## Problem

Flutter widgets using Riverpod enter an infinite rebuild loop, causing:
- 50+ widget rebuilds in seconds
- UI becomes unresponsive
- Same content rendered repeatedly
- Bug manifests primarily on slower devices or poor network connections

## Context / Trigger Conditions

**Symptoms in logs:**
```
⚠️ RAPID REBUILD #54! Only 15ms since last build
⚠️ RAPID REBUILD DETECTED! Only 6ms since last build
```

**User-reported symptoms:**
- "Endless scroll loop" - same video/content keeps appearing
- "App freezes" or becomes unresponsive
- "Works on my phone but not on older devices"

**Trigger scenarios:**
1. Multiple async providers completing at staggered times
2. Provider that watches route/URL state AND updates URL in build
3. Using `ref.watch()` AND adding manual listeners to same provider
4. Transitive watches: Widget watches A, A watches B, Widget also watches B

## Root Cause Analysis

### Pattern 1: URL Update Feedback Loop

```dart
// BAD: Creates infinite loop
Widget build(BuildContext context) {
  final pageContext = ref.watch(pageContextProvider);  // Watches URL
  final videos = ref.watch(videosProvider);

  // Detect video moved position and "silently" update URL
  if (currentVideoIndex != urlIndex) {
    context.go('/home/$currentVideoIndex');  // URL change triggers rebuild!
  }
}
```

**Loop:** Videos reorder → URL updated → pageContextProvider emits → rebuild → videos may reorder again → repeat

### Pattern 2: Watch + Listener Redundancy

```dart
// BAD: Double-subscribing causes double rebuilds
final cache = ref.watch(cacheProvider);  // Watch triggers rebuild
cache.addListener(onCacheChanged);        // Listener ALSO triggers action
```

### Pattern 3: Transitive Watch Dependencies

```dart
// BAD: Double-watching same source
Widget build() {
  ref.watch(pageContextProvider);           // Watch #1
  ref.watch(derivedProvider);               // derivedProvider ALSO watches pageContextProvider!
}
```

### Pattern 4: Staggered Async Provider Loading

```dart
// PROBLEMATIC on slow devices: Each watch triggers rebuild when provider completes
final a = ref.watch(asyncProviderA);  // Completes at T=100ms → rebuild
final b = ref.watch(asyncProviderB);  // Completes at T=200ms → rebuild
final c = ref.watch(asyncProviderC);  // Completes at T=350ms → rebuild
final d = ref.watch(asyncProviderD);  // Completes at T=500ms → rebuild
// On fast devices: all complete ~simultaneously, 1-2 rebuilds
// On slow devices: staggered completion, 4+ rebuilds
```

## Solution

### Step 1: Audit `ref.watch()` Usage

For each `ref.watch()` in build methods, ask:
- Does this provider change frequently?
- Do I need to REBUILD when it changes, or just REACT?
- Am I also manually listening to this provider?

**Riverpod Methods:**
| Method | Behavior |
|--------|----------|
| `ref.watch()` | Subscribe + **REBUILD** on change |
| `ref.read()` | Read once, **NO rebuild** |
| `ref.listen()` | Subscribe + callback, **NO rebuild** |

### Step 2: Convert Unnecessary Watches

```dart
// BEFORE: Rebuilds on every change
final videoService = ref.watch(videoServiceProvider);

// AFTER: Read once, use listener for reactions
final videoService = ref.read(videoServiceProvider);
ref.listen(videoServiceProvider, (prev, next) {
  // React to changes without rebuilding
  if (next.hasNewVideos) refreshUI();
});
```

### Step 3: Remove Watch + Listener Redundancy

```dart
// BEFORE: Double-subscription
final cache = ref.watch(cacheProvider);
cache.addListener(onCacheChanged);

// AFTER: Choose one approach
// Option A: Just watch (if rebuild is needed)
final cache = ref.watch(cacheProvider);

// Option B: Read + listen (if rebuild not needed)
final cache = ref.read(cacheProvider);
ref.listen(cacheProvider, (_, __) => onCacheChanged());
```

### Step 4: Break URL Update Loops

```dart
// BEFORE: URL update in build causes loop
if (currentVideoIndex != urlIndex) {
  context.go('/home/$currentVideoIndex');
}

// AFTER: Don't update URL on content reorder
// Just track position with PageController, not URL
// OR use content ID in URL instead of index: /home/video/abc123
```

### Step 5: Batch Initial Load

```dart
// BEFORE: Watch each async provider (N rebuilds on slow devices)
final a = ref.watch(asyncA);
final b = ref.watch(asyncB);

// AFTER: Create combined provider that waits for all
@riverpod
Future<CombinedState> combinedState(Ref ref) async {
  final a = await ref.watch(asyncA.future);
  final b = await ref.watch(asyncB.future);
  return CombinedState(a, b);
}
// Widget watches only the combined provider (1 rebuild)
```

## Verification

After fixes:
1. Run app on slow device or use network throttling
2. Check logs for rebuild warnings - should see ≤5 rebuilds on startup
3. Scroll/navigate and verify UI remains responsive
4. No "RAPID REBUILD" warnings in logs

## Example: Full Fix

**Before (problematic):**
```dart
class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    final pageContext = ref.watch(pageContextProvider);
    final videos = ref.watch(videosProvider);  // Also watches pageContextProvider internally!

    // URL update loop
    if (videos.currentIndex != pageContext.index) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.go('/home/${videos.currentIndex}');
      });
    }

    return PageView(...);
  }
}
```

**After (fixed):**
```dart
class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    // Only watch videos, read page context
    final pageContext = ref.read(pageContextProvider).requireValue;
    final videos = ref.watch(videosProvider);

    // Don't update URL on reorder - track with PageController only
    // URL only changes on explicit user navigation

    return PageView(...);
  }
}
```

## Notes

- This bug is **timing-dependent** - may not reproduce on fast devices
- Test on physical devices with network throttling to catch issues
- Add rebuild detection logging during development:
  ```dart
  static int _buildCount = 0;
  static DateTime? _lastBuild;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    if (_lastBuild != null && now.difference(_lastBuild!).inMilliseconds < 100) {
      Log.warning('RAPID REBUILD #${++_buildCount}!');
    }
    _lastBuild = now;
    // ...
  }
  ```

## References

- [Riverpod: Reading Providers](https://riverpod.dev/docs/concepts/reading)
- [Riverpod: ref.watch vs ref.read vs ref.listen](https://riverpod.dev/docs/essentials/combining_providers)
- [Flutter DevTools: Identify Rebuilds](https://docs.flutter.dev/tools/devtools/performance)
