# Categories Redesign Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the Explore categories grid with the approved list/gallery/fullscreen redesign while preserving visible category-level `Hot / New / Classic` sorting after a category is opened.

**Architecture:** Keep the Explore `Categories` tab as a pure discovery surface and push into a dedicated category gallery route for per-category sorting and video browsing. Split categories list concerns from category-detail concerns so the discovery screen handles ordering and rendering while the detail layer handles sort, video loading, refresh, and pagination.

**Tech Stack:** Flutter, flutter_bloc, go_router, divine_ui, existing pooled fullscreen feed flow, widget tests, bloc tests

---

## Chunk 1: Discovery List Redesign

### Task 1: Add list ordering and presentation data for categories

**Files:**
- Modify: `mobile/lib/models/video_category.dart`
- Test: `mobile/test/blocs/categories/categories_bloc_test.dart`

- [ ] **Step 1: Write the failing tests for pinned ordering and fallback presentation**

Add assertions covering:
- pinned design categories sort first in curated order
- additional fetched categories remain after the pinned set
- extra categories can derive fallback presentation metadata without bespoke artwork

Run: `flutter test test/blocs/categories/categories_bloc_test.dart`
Expected: FAIL because the current model/bloc do not provide the new ordering/presentation behavior.

- [ ] **Step 2: Implement the minimal model and ordering support**

Add the smallest production code needed for:
- curated category ordering metadata
- fallback accent/icon presentation metadata for non-featured categories

- [ ] **Step 3: Re-run the bloc tests**

Run: `flutter test test/blocs/categories/categories_bloc_test.dart`
Expected: PASS

### Task 2: Redesign the Explore categories tab into a scrollable tile list

**Files:**
- Modify: `mobile/lib/widgets/categories_tab.dart`
- Test: `mobile/test/widgets/categories_tab_test.dart`

- [ ] **Step 1: Write the failing widget tests for the new discovery list**

Add assertions covering:
- vertical full-width tile list instead of grid rendering
- pinned categories appear before non-pinned categories
- list remains a pure discovery surface with no inline selected-category state

Run: `flutter test test/widgets/categories_tab_test.dart`
Expected: FAIL because the widget still renders the old grid and inline detail state.

- [ ] **Step 2: Implement the list redesign**

Build the new discovery screen using:
- Figma-inspired full-width category tiles
- pinned-first ordering from the updated model/bloc data
- deterministic fallback styling for extra categories
- tap navigation into a dedicated category screen

- [ ] **Step 3: Re-run the widget tests**

Run: `flutter test test/widgets/categories_tab_test.dart`
Expected: PASS

## Chunk 2: Category Gallery Route And Visible Sort

### Task 3: Add a dedicated category gallery route and state flow

**Files:**
- Modify: `mobile/lib/router/app_router.dart`
- Modify: `mobile/lib/blocs/categories/categories_bloc.dart`
- Modify: `mobile/lib/blocs/categories/categories_event.dart`
- Modify: `mobile/lib/blocs/categories/categories_state.dart`
- Create: `mobile/lib/screens/category_gallery_screen.dart`
- Test: `mobile/test/blocs/categories/categories_bloc_test.dart`

- [ ] **Step 1: Write the failing tests for category-detail sorting and reload behavior**

Add assertions covering:
- entering a category loads videos for the selected category
- switching to `Hot`, `New`, and `Classic` reloads with the correct API parameters
- pagination continues to use the selected sort

Run: `flutter test test/blocs/categories/categories_bloc_test.dart`
Expected: FAIL because the current state flow is still shaped around inline selection and older UI assumptions.

- [ ] **Step 2: Implement the route and detail-state changes**

Add:
- a pushed route for the category gallery screen
- state/event updates needed for explicit category-detail ownership
- minimal navigation arguments needed to open the gallery from the discovery list

- [ ] **Step 3: Re-run the bloc tests**

Run: `flutter test test/blocs/categories/categories_bloc_test.dart`
Expected: PASS

### Task 4: Build the category gallery screen with visible `Hot / New / Classic`

**Files:**
- Create: `mobile/lib/screens/category_gallery_screen.dart`
- Modify: `mobile/lib/widgets/categories_tab.dart`
- Test: `mobile/test/screens/category_gallery_screen_test.dart`

- [ ] **Step 1: Write the failing widget tests for the gallery screen**

Create tests covering:
- header/title/category context rendering
- visible `Hot / New / Classic` segmented control
- masonry video gallery rendering
- retry and empty states

Run: `flutter test test/screens/category_gallery_screen_test.dart`
Expected: FAIL because the screen does not exist yet.

- [ ] **Step 2: Implement the gallery UI**

Build the screen using:
- Figma-aligned header and hero art treatment
- a visible segmented control under the header
- existing composable video grid/masonry behavior
- existing refresh and pagination behavior

- [ ] **Step 3: Re-run the new widget test**

Run: `flutter test test/screens/category_gallery_screen_test.dart`
Expected: PASS

## Chunk 3: Fullscreen Context And Final Verification

### Task 5: Preserve category + sort context into fullscreen feed

**Files:**
- Modify: `mobile/lib/screens/category_gallery_screen.dart`
- Modify: `mobile/lib/screens/feed/pooled_fullscreen_video_feed_screen.dart`
- Test: `mobile/test/screens/category_gallery_screen_test.dart`
- Test: `mobile/test/screens/feed/pooled_fullscreen_video_feed_screen_test.dart`

- [ ] **Step 1: Write the failing tests for fullscreen context handoff**

Add assertions covering:
- tapping a gallery video opens fullscreen with the selected category context
- fullscreen keeps the gallery state intact when popping back

Run: `flutter test test/screens/category_gallery_screen_test.dart`
Run: `flutter test test/screens/feed/pooled_fullscreen_video_feed_screen_test.dart`
Expected: FAIL because the redesigned category context is not wired through yet.

- [ ] **Step 2: Implement the fullscreen context plumbing**

Pass the selected category title and selected sort context through the existing pooled fullscreen flow without adding a second visible sort control.

- [ ] **Step 3: Re-run the focused fullscreen tests**

Run: `flutter test test/screens/category_gallery_screen_test.dart`
Run: `flutter test test/screens/feed/pooled_fullscreen_video_feed_screen_test.dart`
Expected: PASS

### Task 6: Run focused verification and prepare branch state

**Files:**
- Verify only

- [ ] **Step 1: Run focused verification**

Run:
- `flutter test test/widgets/categories_tab_test.dart`
- `flutter test test/blocs/categories/categories_bloc_test.dart`
- `flutter test test/screens/category_gallery_screen_test.dart`
- `flutter test test/screens/feed/pooled_fullscreen_video_feed_screen_test.dart`

Expected: PASS

- [ ] **Step 2: Run analysis on touched files if needed**

Run: `flutter analyze`
Expected: PASS, or capture any unrelated baseline issues explicitly if they occur.

- [ ] **Step 3: Review the diff and commit**

Run:
- `git status --short`
- `git diff --stat`
- `git add <task files>`
- `git commit -m "feat(categories): redesign category discovery and detail flow"`

Expected: clean staged task diff and committed branch state.
