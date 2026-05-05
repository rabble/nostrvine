---
name: flutter-pageview-scroll-position-preservation
description: |
  Fix Flutter PageView "snap back" or scroll position reset issues on provider/state rebuilds.
  Use when: (1) PageView scrolls then snaps back to previous page after state update,
  (2) Scroll position resets when Riverpod/Provider rebuilds, (3) Feed scrolls back to top
  on data refresh, (4) PageView loses position after orientation change or widget rebuild.
author: Claude Code
version: 1.1.0
date: 2026-01-31
---

# Flutter PageView Scroll Position Preservation

## Problem

Users scrolling through a PageView-based feed report that the scroll position resets or
"snaps back" to a previous page, especially after state updates from providers (Riverpod,
Provider, BLoC) or widget rebuilds.

## Context / Trigger Conditions

- PageView with dynamic content from state management
- Provider/Riverpod state updates causing widget rebuilds
- Pagination that changes itemCount
- Orientation changes
- Tab switching and returning to the PageView

## Root Cause

When Flutter rebuilds the widget tree (due to state changes), the PageView may lose its
scroll position if:

1. No `PageStorageKey` is provided to persist state
2. The PageController is recreated during rebuilds
3. `PageController.keepPage` is set to `false`

**Note:** `allowImplicitScrolling` is for **accessibility focus navigation**, NOT scroll
position preservation. A specific bug (#76569) involving TextField focus was fixed in Flutter.

## Solution

### 1. Add PageStorageKey (PRIMARY FIX)

```dart
PageView.builder(
  // This key tells Flutter to persist scroll state across rebuilds
  key: const PageStorageKey<String>('my_page_view'),
  itemCount: videos.length,
  controller: _pageController,
  ...
)
```

### 2. Keep PageController in State (not build)

```dart
class _MyScreenState extends State<MyScreen> {
  // Create in initState, NOT in build()
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();  // Created once
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Use the same controller instance
    return PageView.builder(
      controller: _pageController,
      ...
    );
  }
}
```

### 3. Ensure keepPage is true (default)

```dart
_pageController = PageController(
  keepPage: true,  // This is the default, but be explicit if needed
  initialPage: 0,
);
```

### 4. For complex state: Use PageStorage widget

```dart
PageStorage(
  bucket: PageStorageBucket(),
  child: PageView.builder(
    key: const PageStorageKey<String>('feed'),
    ...
  ),
)
```

## What allowImplicitScrolling Actually Does

This is for **accessibility**, not scroll position:

- `false` (default): Accessibility focus exits PageView at page boundaries
- `true`: Accessibility focus moves to next page instead of exiting widget

It does NOT cause scroll position issues. Keep it `true` for better accessibility.

## Verification

1. Scroll to page 10+ in the feed
2. Trigger a state update (like new data arriving)
3. Verify scroll position is preserved
4. Rotate device - verify position preserved
5. Switch tabs and return - verify position preserved

## Example

Full pattern for a Riverpod-based feed:

```dart
class _VideoFeedScreenState extends ConsumerState<VideoFeedScreen> {
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final videos = ref.watch(videoFeedProvider);

    return PageView.builder(
      key: const PageStorageKey<String>('video_feed'),
      controller: _pageController,
      itemCount: videos.length,
      allowImplicitScrolling: true,  // For accessibility
      itemBuilder: (context, index) => VideoItem(videos[index]),
    );
  }
}
```

## Notes

- The Riverpod 3.2.0 issue #4661 about ProviderScope rebuilds is separate
- If using tabs, wrap in `AutomaticKeepAliveClientMixin` to preserve state
- For very long lists, consider using `restorationId` for app restart persistence

## References

- [PageView class - Flutter docs](https://api.flutter.dev/flutter/widgets/PageView-class.html)
- [PageStorageKey usage - Medium](https://medium.com/codex/maintaining-pageviews-current-page-after-orientation-changes-using-keys-ac0769234e09)
- [allowImplicitScrolling property](https://api.flutter.dev/flutter/widgets/PageView/allowImplicitScrolling.html)
- [GitHub #76569 - TextField snap-back bug (FIXED)](https://github.com/flutter/flutter/issues/76569)
