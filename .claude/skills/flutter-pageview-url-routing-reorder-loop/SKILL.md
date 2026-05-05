---
name: flutter-pageview-url-routing-reorder-loop
description: |
  Fix infinite rebuild loop in Flutter when using PageView with URL-based routing (GoRouter)
  and reactive state management (Riverpod/BLoC). Use when: (1) RAPID REBUILD warnings appear
  in console (#20+), (2) "setState() or markNeedsBuild() called during build" errors from
  ValueListenableBuilder, (3) Video feed or list-based PageView is frozen and won't swipe,
  (4) Overlay or UI elements flicker between visible/invisible rapidly, (5) Logs show item
  "moved from index X to Y" repeatedly. Caused by tracking items by ID and updating URL
  when reactive list reorders.
author: Claude Code
version: 1.0.0
date: 2026-02-06
---

# Flutter PageView + URL Routing Reorder Detection Loop

## Problem
When a PageView is synced bidirectionally with URL-based routing (e.g., GoRouter `/home/:index`)
and the data source is a reactive provider (Riverpod, BLoC stream), attempting to track the
currently-viewed item by its ID and update the URL when the item moves to a different index
in the list creates an infinite feedback loop.

## Context / Trigger Conditions

**Symptoms:**
- Console shows `RAPID REBUILD #42!` warnings (build count growing rapidly)
- `setState() or markNeedsBuild() called during build` errors from `ValueListenableBuilder`
- PageView is frozen - user swipes but page bounces back to same position
- UI overlay (social buttons, controls) flickers between visible and invisible
- Logs show repeated pattern: `Video X moved from index 4 -> 3, updating URL`

**Architecture that triggers this:**
- `PageView.builder` with `onPageChanged` updating URL via `context.go('/feed/$index')`
- URL-derived index synced back to PageController via `jumpToPage()` during build
- Reactive data source (Riverpod provider, stream) that can re-emit with reordered items
- Item tracking: `_currentItemId` compared against list to detect "moves"

**Example of the anti-pattern:**
```dart
// IN BUILD METHOD - creates feedback loop!
if (_currentVideoStableId != null && videos.isNotEmpty) {
  final currentVideoIndex = videos.indexWhere(
    (v) => v.stableId == _currentVideoStableId,
  );
  if (currentVideoIndex != -1 && currentVideoIndex != urlIndex) {
    // This triggers URL update -> rebuild -> PageController sync ->
    // onPageChanged -> URL update -> INFINITE LOOP
    context.go('/home/$currentVideoIndex');
  }
}
```

## Solution

**Remove item-tracking reorder detection entirely.** The PageController should be the sole
source of truth for which page the user is viewing.

### Step 1: Remove tracking state
```dart
// REMOVE these fields:
// String? _currentVideoStableId;
// bool _urlUpdateScheduled = false;
```

### Step 2: Remove reorder detection block
Remove any code in `build()` that:
- Searches for a tracked item ID in the current list
- Compares found index against URL index
- Schedules URL updates when indices differ

### Step 3: Keep only one-way sync patterns

**User swipe -> URL (one-way):**
```dart
onPageChanged: (newIndex) {
  if (newIndex != urlIndex) {
    context.go('/home/$newIndex');
  }
}
```

**External navigation -> PageController (one-way):**
```dart
if (urlIndex != _lastUrlIndex) {
  _lastUrlIndex = urlIndex;
  controller.jumpToPage(urlIndex);
}
```

These two paths don't create loops because:
- User swipe: URL updates, next build sees matching urlIndex -> no sync needed
- External nav: URL changes, sync fires, onPageChanged fires but `newIndex == urlIndex` -> no URL update

## The Feedback Loop Explained

```
┌─ Reactive provider re-emits (new data from server) ─┐
│                                                       │
▼                                                       │
Build runs with new video list                          │
│                                                       │
▼                                                       │
Reorder detection: "Video X moved from idx 4 to 3"     │
│                                                       │
▼                                                       │
Schedule URL update: context.go('/home/3')              │
│                                                       │
▼                                                       │
Build runs: urlIndex=3, PageController at page 4        │
│                                                       │
▼                                                       │
Sync: jumpToPage(3)                                     │
│                                                       │
▼                                                       │
onPageChanged(3) fires → context.go('/home/3')          │
│                                                       │
▼                                                       │
But PageController was at 4, which showed different     │
video → _currentVideoStableId mismatches → detects      │
"move" again → URL update to /home/4                    │
│                                                       │
└───────── INFINITE LOOP ──────────────────────────────┘
```

## Verification

After removing reorder detection:
1. No more `RAPID REBUILD` warnings in console
2. No `setState() called during build` errors
3. Swiping between pages works smoothly
4. UI overlays stay visible on the active page
5. No "moved from index X to Y" log spam

## Notes

- **Why reorder detection seems needed:** When a reactive list reorders (e.g., new items
  prepended), the user's current page index points to a different item. However, trying to
  "follow" the item creates worse UX (infinite loop) than staying on the same page index.

- **Alternative if position preservation is critical:** Instead of URL-based reorder detection,
  stabilize the list order. Either:
  - Don't reorder while the user is actively viewing (batch updates)
  - Use a stable sort that preserves relative positions of existing items
  - Only prepend/append new items, never reorder existing ones

- **Related pattern:** `flutter-pageview-implicit-scrolling-snapback` addresses a different
  PageView issue (snap-back on state rebuild) but can co-occur with this loop.

- **Framework-agnostic:** While this was discovered with GoRouter + Riverpod, the same
  pattern applies to any PageView + URL routing + reactive state combination (Navigator 2.0,
  auto_route, BLoC streams, etc.)
