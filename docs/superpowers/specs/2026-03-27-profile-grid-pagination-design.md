# Profile Grid Pagination Design

**Date:** 2026-03-27
**Status:** Approved

## Goal

Load additional profile videos when the user scrolls to the bottom of the profile grid, without changing fullscreen profile pagination behavior.

## Current Behavior

- `ProfileFeed.loadMore()` already exists and supports profile pagination.
- Fullscreen profile playback calls `loadMore()` when the user reaches the last video.
- The profile grid uses its own `CustomScrollView` and `SliverGrid`, but does not listen for near-bottom scroll position.
- Result: profile grids stop after the first page, currently 50 videos.

## Chosen Approach

Add bottom-of-scroll pagination to `ProfileVideosGrid` only.

- Keep the existing `ProfileFeed` provider contract and `loadMore()` logic unchanged.
- Detect when the profile grid scroll position is near the end.
- Trigger the existing provider `loadMore()` callback only when:
  - the videos tab has more content,
  - a load is not already in flight,
  - the user is near the bottom of the scroll extent.
- Show the existing grid content model unchanged, including upload placeholders for the owner profile.

## Why This Approach

- It fixes the specific missing behavior instead of reworking shared pagination.
- It preserves the already-working fullscreen load-more path.
- It follows the existing repository pattern used in other scroll-driven pagination widgets.

## Testing

- Add a widget test that reproduces the grid bug: scrolling near the bottom should call the profile feed notifier `loadMore()`.
- Keep the scope narrow to the videos grid path.
