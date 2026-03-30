# Category Navigation Picker Design

**Date:** 2026-03-29

**Goal**

Update the category gallery and fullscreen category feed to match the approved Figma direction: replace the visible segmented sort buttons with a trailing picker sheet, add a fourth category-scoped `For You` option, and show the category label in the fullscreen header.

**Scope**

- Keep the existing category gallery route and pooled fullscreen feed route.
- Replace the category gallery sort control UI with the approved picker interaction.
- Add category-scoped `For You` recommendations alongside `Hot`, `New`, and `Classic`.
- Show the active category label in the fullscreen category feed header.
- Preserve the existing gallery masonry grid, retry flow, refresh behavior, and API-backed pagination where supported.

**User Flow**

1. User opens a category gallery such as `Animals`.
2. The gallery opens in `Hot` by default.
3. The header shows the category title, existing mascot artwork, a back button, and a trailing picker button.
4. Tapping the picker button opens a rounded bottom sheet with four options: `Hot`, `New`, `Classic`, and `For You`.
5. Selecting an option dismisses the sheet and reloads the gallery using that mode.
6. `For You` uses the existing recommendations flow filtered to the current category.
7. If category-scoped `For You` produces no results, the gallery falls back to that category’s `Hot` feed instead of rendering an empty state.
8. Tapping a video opens the pooled fullscreen feed.
9. The fullscreen header shows the category label at the top so the user knows which category they are viewing.
10. Back from fullscreen returns to the same category gallery state.

**Visual Design**

## Category Gallery

- Keep the existing Figma-aligned category gallery header structure and masonry gallery body.
- Remove the visible segmented sort control below the header.
- Add a trailing icon button in the header using the same Divine/Figma pill treatment as the approved comp.
- Keep the category title left-aligned in the gallery header next to the back button.

## Category Picker Sheet

- Open a rounded top sheet from the bottom of the screen.
- Match the approved Figma styling:
  - drag handle at the top
  - dark Divine surface
  - single-select list rows
  - active row highlight
  - trailing checkmark for the selected option
- Add `For You` as a fourth row using the same row treatment as the three Figma-defined options.

## Fullscreen Category Feed

- Keep the transparent fullscreen video app bar treatment.
- Show the category label as the centered header title while viewing category videos.
- Do not add the picker or any other sort control to fullscreen.

**Architecture**

- Keep `CategoriesBloc` as the source of truth for category gallery state.
- Extend the existing gallery mode state so the UI can represent four modes cleanly:
  - `Hot`
  - `New`
  - `Classic`
  - `For You`
- Keep the current route handoff from category gallery to `PooledFullscreenVideoFeedScreen`.
- Continue passing category context into fullscreen through the existing route arguments rather than introducing a new route shape.
- Keep business logic in the bloc/repository/client layers and keep widget code focused on rendering and user interaction.

**Data Rules**

- `Hot` continues to use the existing category endpoint with `sort=trending`.
- `New` continues to use the existing category endpoint with `sort=timestamp`.
- `Classic` continues to use the existing category endpoint with `sort=loops` and `platform=vine`.
- `For You` uses the existing recommendations flow with the current user and `category=<selected category>`.
- If `For You` returns personalized or fallback recommendations with results, render them as the selected mode’s gallery feed.
- If `For You` returns no results, immediately load the category’s `Hot` feed and keep the experience non-empty.
- Pagination remains enabled for the existing category endpoint modes.
- If recommendations do not support clean pagination in the current client flow, do not fake load-more behavior for `For You`.

**Error Handling**

- Keep the current category gallery loading, retry, and error presentation patterns.
- If `For You` request fails, show the existing gallery error state and retry through the selected mode.
- If fallback from `For You` to `Hot` succeeds, do not surface an empty state.
- Preserve the existing invalid-category route handling.

**Testing**

- Update `CategoriesBloc` tests to cover:
  - existing `Hot`, `New`, and `Classic` behavior
  - category-scoped `For You` fetch behavior
  - `For You` fallback to `Hot` when recommendations are empty
- Update category gallery widget tests to cover:
  - absence of the old segmented control
  - presence of the new picker trigger
  - correct active mode labeling and selection behavior
  - existing retry and empty states
- Add or update fullscreen feed tests to cover:
  - category title shown in the fullscreen header
  - existing category context passed through on navigation
- Run focused widget and bloc tests first, then broader verification on touched files.

**Assumptions Locked For Implementation**

- Users are always signed in for this flow.
- The gallery default remains `Hot`, not `For You`.
- `For You` is always visible in the picker.
- The fullscreen category feed must show the category label in the header.
- The fourth picker row should follow the approved Figma sheet styling even though the original comp only showed three options.
