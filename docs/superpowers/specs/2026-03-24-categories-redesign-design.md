# Categories Redesign Design

**Date:** 2026-03-24

**Goal**

Implement the three approved Figma category designs while preserving the existing category-level `Hot / New / Classic` behavior in a visible way.

**Scope**

- Redesign the Explore `Categories` tab into a dedicated discovery list.
- Add a pushed category gallery screen based on the Figma detail design.
- Keep the fullscreen category feed visually aligned with the Figma fullscreen comp.
- Preserve category sorting with a visible control on the category gallery screen only.

**User Flow**

1. User opens Explore and lands on the `Categories` tab.
2. The tab shows a vertically scrollable category list.
3. The eight categories from the approved Figma design are pinned first, in the curated order defined by the design, when those categories are present in API results.
4. Additional fetched categories appear below the pinned set as the user scrolls.
5. Tapping a category pushes a dedicated category gallery screen.
6. The category gallery screen exposes a visible `Hot / New / Classic` segmented control under the header.
7. Tapping a video opens the pooled fullscreen feed while preserving the selected category and sort context.
8. Back from fullscreen returns to the same category gallery state. Back from the category gallery returns to the categories list with its scroll position intact.

**Visual Design**

## Categories List

- Replace the current 3-column grid with full-width rounded category tiles matching the Figma look and spacing.
- The pinned eight categories use the Figma-inspired accent backgrounds, text colors, and large right-aligned artwork treatment.
- Additional categories reuse the same tile component and sizing, but use deterministic fallback styling:
  - category-specific emoji/icon treatment rather than bespoke artwork
  - rotating accent palette derived from existing Divine theme colors
- The list remains scrollable and is not capped at eight categories.

## Category Gallery

- Use a dedicated pushed screen with a Figma-aligned header, category title, hero artwork, and masonry gallery.
- Add a visible segmented control for `Hot`, `New`, and `Classic` directly under the header. This is an intentional product override of the provided Figma because sort discoverability is important.
- The gallery keeps the Figma two-column masonry feel and existing pagination behavior.

## Fullscreen Feed

- Preserve the chosen category and sort context when opening fullscreen.
- Keep the fullscreen visual chrome close to the Figma comp.
- Do not add a second visible sort control in fullscreen.

**Architecture**

- The Explore `Categories` tab becomes a pure discovery surface and no longer owns inline “selected category” UI state.
- Split the current categories feature responsibilities:
  - discovery/list state for loading, pinning, ordering, and rendering the categories list
  - category-detail state for selected category sort, video loading, refresh, pagination, and retry
- Reuse the existing pooled fullscreen feed route and pass the chosen category context into it.
- Keep business logic in BLoC/repository layers and keep UI widgets Flutter-only.

**Data Rules**

- Categories continue to come from the Funnelcake API.
- Only categories returned by the API are shown.
- If one or more pinned design categories are missing from the API response, show only the pinned categories that exist; do not render placeholders.
- Pinned categories are ordered by the approved design list, then all remaining categories are appended in fetched order.
- Sorting behavior remains:
  - `Hot` -> existing trending sort
  - `New` -> existing timestamp sort
  - `Classic` -> existing classic/vine filter behavior

**Error Handling**

- Categories list keeps the existing retry behavior for load failures.
- Category gallery keeps the existing retry behavior for video fetch failures.
- Empty states remain explicit for both no categories and no videos in the selected category.

**Testing**

- Update widget tests to cover the redesigned categories discovery list, including pinned-first ordering and fallback rendering for additional categories.
- Add tests for the pushed category gallery screen and visible `Hot / New / Classic` segmented control.
- Update bloc tests to reflect the split responsibilities and preserved sort behavior.
- Run focused widget/bloc tests first, then broaden to relevant analysis or visual verification if the final diff requires it.

**Assumptions Locked For Implementation**

- The categories entry screen does not show sort controls.
- Sort controls appear only after entering a category.
- The current product requirement to preserve `Classic` overrides the literal Figma omission.
- The eight Figma categories are brand-priority categories, not a hard limit.
