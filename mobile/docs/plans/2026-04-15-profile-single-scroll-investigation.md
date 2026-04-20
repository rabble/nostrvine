# Profile Screen: Scroll Behavior Investigation

## Status: CLOSED — Keeping current NestedScrollView

## Problem

The profile screen uses `NestedScrollView` which creates two scroll contexts — the header scrolls first, then the tab content scrolls independently after the header collapses and the tab bar pins.

## Investigation

We explored replacing `NestedScrollView` + `TabBarView` with a single `CustomScrollView` for unified scrolling. However, research revealed that the three requirements are fundamentally incompatible in Flutter:

1. **Single unified vertical scroll** — needs one `CustomScrollView` with all content as slivers
2. **Smooth horizontal swipe between tabs** — needs `TabBarView` which requires independent inner scroll controllers
3. **Per-tab scroll position memory** — needs independent scroll controllers per tab

These cannot coexist. `TabBarView`'s horizontal swipe animation requires its children to have their own scroll contexts. A single `CustomScrollView` cannot contain a `TabBarView`.

## Options Evaluated

| Option | Pros | Cons |
|--------|------|------|
| **Keep NestedScrollView** (chosen) | Standard Flutter pattern, smooth tab swipes, per-tab scroll memory, pagination works | Two-scroll-context behavior |
| Single CustomScrollView | Unified scroll | No smooth swipe, loses per-tab scroll, complex pagination |
| LinkedScrollController coordination | Could smooth the transition | Added complexity, may not fully resolve |

## Decision

Keep the current `NestedScrollView` + `TabBarView` architecture. This is the standard Flutter pattern used by Instagram, Twitter, and most profile+tabs layouts. The two-scroll-context behavior (header collapses → tab bar pins → content scrolls) is expected UX, not a bug.

## Future Improvements (Optional)

- Tune scroll physics to make the transition between header collapse and content scroll smoother
- Consider `LinkedScrollController` (already in pubspec) if users report choppy scroll handoff
