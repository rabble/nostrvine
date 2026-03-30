# Feed Pagination Hardening Design

**Date:** 2026-03-30
**Status:** Approved
**Supersedes:** `docs/superpowers/specs/2026-03-27-profile-grid-pagination-design.md`

## Goal

Make every scroll-paginated feed or list in the mobile app reliably request and render additional pages, with profile surfaces fixed first and shared pagination behavior standardized across the current UI.

## Current Behavior

- `ProfileFeed` already supports REST cursor pagination and Nostr historical pagination.
- Fullscreen profile playback can already call `loadMore()` when the user reaches the last video.
- Several profile tabs still depend on `NotificationListener<ScrollNotification>` inside nested/tabbed scroll layouts.
- Shared feed surfaces use a mix of controller-based pagination and notification-based pagination, so behavior is inconsistent by screen.
- `ProfileFeed` uses inconsistent `hasMoreContent` heuristics across build/refresh paths:
  - some states derive `hasMoreContent` from the filtered visible count
  - one REST refresh path still uses the 10-item threshold instead of the 50-item REST page size

## Problems To Solve

1. Profile routes can stop after the first page even though the provider and backend support more pages.
2. Nested scroll/tab layouts make notification-only pagination triggers brittle.
3. Different feeds use different near-bottom logic and duplicate-call guards.
4. Provider `hasMoreContent` can drift from the backend pagination contract after refreshes or filtering.
5. Existing tests cover standalone pieces, but not enough routed/nested-scroll behavior.

## Chosen Approach

Introduce a shared scroll-pagination trigger based on explicit `ScrollController` ownership, apply it to all current infinite-scroll surfaces that should auto-load more, and normalize `hasMoreContent` semantics for the REST-backed profile feed.

### Design Details

- Add a shared helper that:
  - owns or observes a `ScrollController`
  - triggers `onLoadMore` near the bottom threshold
  - blocks duplicate calls while a load is in flight
  - respects `hasMore` and current loading state
- Convert current paginated profile tabs to the shared controller-driven pattern:
  - profile videos
  - liked videos
  - reposts
  - collabs
  - comments
- Align shared feed/list widgets that already paginate on scroll with the same helper so feed behavior is consistent across the app.
- Fix `ProfileFeed` so REST-backed `hasMoreContent` is based on the backend page contract (`AppConstants.paginationBatchSize`) instead of the filtered visible count or the 10-item threshold.
- Add regression coverage at the routed/profile-screen level and unit/widget coverage for the shared helper and profile provider contract.

## Scope

- `mobile/lib/widgets/profile/*grid.dart` pagination triggers
- shared paginated feed/list widgets that auto-load on scroll
- `mobile/lib/providers/profile_feed_provider.dart`
- targeted pagination tests for shared scroll triggering and routed profile screens

## Non-Goals

- Rebuild the entire feed architecture
- Change Funnelcake or relay pagination contracts
- Add pagination to screens that intentionally return finite results
- Rework fullscreen feed pagination beyond compatibility with the new trigger behavior

## Why This Approach

- It addresses the current user-visible bug instead of only adding another narrow profile-only patch.
- It reduces duplicated pagination logic and makes future feed work less fragile.
- It keeps repository ownership where it already belongs: UI decides when to request more, providers/blocs decide whether more exists.
- It stays reviewable by focusing on the current infinite-scroll surfaces instead of a full feed rewrite.

## Testing Strategy

- Add a failing regression test for routed profile scrolling in the real nested-scroll path.
- Add helper tests that prove near-bottom triggering, duplicate-call prevention, and `hasMore`/loading guards.
- Add provider tests that prove REST-backed `ProfileFeed` sets `hasMoreContent` from page-size semantics on initial load and refresh.
- Run targeted Flutter tests for the touched profile/feed widgets and providers.
