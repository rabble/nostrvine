# Category Navigation Picker Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the category gallery sort buttons with the approved picker sheet, add category-scoped `For You` recommendations with `Hot` fallback, and show the category label in the fullscreen category feed header.

**Architecture:** Keep `CategoriesBloc` as the source of truth for the category gallery and extend it to support a fourth gallery mode backed by existing recommendations infrastructure. Keep routing unchanged, implement the new picker UI inside the category gallery flow, and use the already-passed category context to render a visible fullscreen header title.

**Tech Stack:** Flutter, flutter_bloc, flutter_riverpod, go_router, divine_ui, funnelcake_api_client, videos_repository, widget tests, bloc tests

---

## File Map

- Modify: `mobile/lib/blocs/categories/categories_bloc.dart`
  Add category-scoped `For You` loading, `Hot` fallback, and per-mode pagination rules.
- Modify: `mobile/lib/blocs/categories/categories_state.dart`
  Represent the active category gallery mode cleanly enough for picker rendering and branching.
- Modify: `mobile/lib/blocs/categories/categories_event.dart`
  Keep the sort-change event aligned with the expanded gallery mode behavior.
- Modify: `mobile/lib/screens/category_gallery_screen.dart`
  Replace the segmented control with the Figma picker trigger and bottom sheet.
- Modify: `mobile/lib/screens/feed/pooled_fullscreen_video_feed_screen.dart`
  Render the category label in the transparent app bar.
- Modify: `mobile/test/blocs/categories/categories_bloc_test.dart`
  Cover the new `For You` behavior and fallback.
- Modify: `mobile/test/screens/category_gallery_screen_test.dart`
  Cover the new picker UI and removal of the old segmented control.
- Modify: `mobile/test/screens/feed/pooled_fullscreen_video_feed_screen_test.dart`
  Cover the visible fullscreen category header title.

## Chunk 1: Category Mode And Data Loading

### Task 1: Add failing bloc coverage for `For You` and fallback behavior

**Files:**
- Modify: `mobile/test/blocs/categories/categories_bloc_test.dart`

- [ ] **Step 1: Write the failing tests for the expanded category gallery modes**

Add test coverage for:
- selecting `For You` calls recommendations with the current user pubkey and category name
- empty `For You` recommendations fall back to `Hot`
- existing `Hot`, `New`, and `Classic` behavior still maps to the current API parameters
- pagination remains enabled for category-endpoint modes and is guarded correctly for recommendations mode

Run: `flutter test test/blocs/categories/categories_bloc_test.dart`
Expected: FAIL because the bloc currently only supports API sort modes and has no recommendations path.

- [ ] **Step 2: Verify the failures are for the intended missing behavior**

Confirm the failing assertions point to missing `For You` mode support or incorrect fallback/pagination behavior, not test harness issues.

### Task 2: Implement category-scoped `For You` loading in `CategoriesBloc`

**Files:**
- Modify: `mobile/lib/blocs/categories/categories_bloc.dart`
- Modify: `mobile/lib/blocs/categories/categories_state.dart`
- Modify: `mobile/lib/blocs/categories/categories_event.dart`

- [ ] **Step 1: Add the minimal mode representation needed by the bloc and UI**

Introduce the smallest production change that makes the four gallery modes explicit and stable for both tests and widgets.

- [ ] **Step 2: Implement recommendations loading with `Hot` fallback**

Update the bloc to:
- branch between category endpoint loading and recommendations loading
- call existing recommendations infrastructure with the selected category
- fall back to category `Hot` when recommendations return no videos
- preserve the selected mode for UI state even when using `Hot` fallback data

- [ ] **Step 3: Implement mode-aware pagination rules**

Keep current pagination for `Hot`, `New`, and `Classic`. Disable or guard pagination for `For You` if the current recommendations flow does not support clean incremental loading for this screen.

- [ ] **Step 4: Re-run the bloc tests**

Run: `flutter test test/blocs/categories/categories_bloc_test.dart`
Expected: PASS

## Chunk 2: Category Gallery UI And Picker Sheet

### Task 3: Add failing widget coverage for the new gallery picker UI

**Files:**
- Modify: `mobile/test/screens/category_gallery_screen_test.dart`

- [ ] **Step 1: Write the failing widget tests for the picker-driven gallery**

Add coverage for:
- old segmented `Hot / New / Classic` control is no longer rendered inline
- header still shows the category title
- trailing picker trigger is visible
- picker shows `Hot`, `New`, `Classic`, and `For You`
- selecting `For You` calls back with the new mode

Run: `flutter test test/screens/category_gallery_screen_test.dart`
Expected: FAIL because the screen still renders the old segmented control and has no picker sheet.

- [ ] **Step 2: Verify the failures reflect the intended UI delta**

Confirm the failing assertions point to the missing picker trigger/sheet or old control still being present.

### Task 4: Implement the Figma picker interaction in the category gallery

**Files:**
- Modify: `mobile/lib/screens/category_gallery_screen.dart`

- [ ] **Step 1: Replace the segmented control with the header picker action**

Update the gallery header to keep:
- back button
- category title
- mascot/artwork treatment

Add the new trailing picker action using existing Divine theme components and the approved Figma spacing/treatment.

- [ ] **Step 2: Add the bottom sheet selection UI**

Implement the picker sheet with:
- drag handle
- single-select rows
- active-row highlight
- trailing checkmark
- `Hot`, `New`, `Classic`, and `For You` labels

- [ ] **Step 3: Keep the rest of the gallery behavior intact**

Preserve:
- masonry gallery rendering
- retry state
- empty state for non-recommendation modes
- refresh and load-more callbacks

- [ ] **Step 4: Re-run the gallery widget tests**

Run: `flutter test test/screens/category_gallery_screen_test.dart`
Expected: PASS

## Chunk 3: Fullscreen Header Context And Verification

### Task 5: Add failing fullscreen header coverage

**Files:**
- Modify: `mobile/test/screens/feed/pooled_fullscreen_video_feed_screen_test.dart`

- [ ] **Step 1: Write the failing fullscreen header test**

Add coverage asserting that when `FullscreenFeedContent` or `PooledFullscreenVideoFeedScreen` receives a category `contextTitle`, the transparent app bar renders that title visibly in the header.

Run: `flutter test test/screens/feed/pooled_fullscreen_video_feed_screen_test.dart`
Expected: FAIL because the fullscreen app bar currently renders an empty title.

- [ ] **Step 2: Verify the failure is a true missing-title failure**

Confirm the failing assertion is specifically about the app bar title not being rendered.

### Task 6: Implement the fullscreen category label and run focused verification

**Files:**
- Modify: `mobile/lib/screens/feed/pooled_fullscreen_video_feed_screen.dart`
- Modify: `mobile/test/screens/feed/pooled_fullscreen_video_feed_screen_test.dart`

- [ ] **Step 1: Render the visible category title in the fullscreen app bar**

Use the existing `contextTitle` handoff so the category label appears at the top of the fullscreen category feed while preserving the transparent visual treatment and back navigation.

- [ ] **Step 2: Re-run the fullscreen test**

Run: `flutter test test/screens/feed/pooled_fullscreen_video_feed_screen_test.dart`
Expected: PASS

- [ ] **Step 3: Run focused end-to-end verification for the touched area**

Run:
- `flutter test test/blocs/categories/categories_bloc_test.dart`
- `flutter test test/screens/category_gallery_screen_test.dart`
- `flutter test test/screens/feed/pooled_fullscreen_video_feed_screen_test.dart`

Expected: PASS

- [ ] **Step 4: Run final analysis and review the task diff**

Run:
- `flutter analyze`
- `git status --short`
- `git diff --stat`

Expected: touched files only, no unreviewed junk, and no new analyzer failures from the feature diff.

- [ ] **Step 5: Commit the completed feature work**

Run:
- `git add mobile/lib/blocs/categories/categories_bloc.dart mobile/lib/blocs/categories/categories_state.dart mobile/lib/blocs/categories/categories_event.dart mobile/lib/screens/category_gallery_screen.dart mobile/lib/screens/feed/pooled_fullscreen_video_feed_screen.dart mobile/test/blocs/categories/categories_bloc_test.dart mobile/test/screens/category_gallery_screen_test.dart mobile/test/screens/feed/pooled_fullscreen_video_feed_screen_test.dart`
- `git commit -m "feat(categories): add category picker and fullscreen title"`

Expected: clean committed branch state ready for PR creation.
