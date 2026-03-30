# Feed Pagination Hardening Implementation Plan

**Goal:** Make every current infinite-scroll feed/list reliably request and render more content, with consistent pagination triggers and correct `hasMore` semantics for profile feeds.

**Architecture:** Introduce a shared controller-based scroll pagination helper, migrate paginated feed surfaces onto that helper or its contract, and normalize `ProfileFeed` REST `hasMoreContent` behavior to use the server page size rather than filtered visible counts. Cover the nested profile route with regression tests so the bug cannot regress silently.

**Tech Stack:** Flutter, Riverpod, flutter_bloc, flutter_test, mocktail

---

## Chunks

1. **Shared Scroll Pagination Helper** — `ScrollPaginationController` with tests
2. **Migrate Shared Feed/List Surfaces** — composable grid, classic vines, discover lists, notifications, inbox, user search
3. **Migrate Profile Tabs** — profile videos, liked, reposts, collabs, comments grids
4. **Fix ProfileFeed REST hasMoreContent** — use `paginationBatchSize` instead of filtered count
5. **Wire ForYou Tab** — pass load-more to composable grid
6. **Add Regression Tests** — scroll pagination controller, profile feed contract, profile grid navigation, inbox scroll
