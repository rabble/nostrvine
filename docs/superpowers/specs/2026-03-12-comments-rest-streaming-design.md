# Comments REST Streaming Design

**Date:** 2026-03-12

**Goal**

Load video comments from FunnelCake REST first for fast initial rendering, start live WebSocket updates immediately without waiting for EOSE, and merge both sources by comment ID so duplicate historical events collapse naturally.

**Current State**

- `CommentsScreen` creates `CommentsBloc` and immediately dispatches `CommentsLoadRequested`.
- `CommentsBloc` awaits `CommentsRepository.loadComments()` before rendering any loaded comments.
- `CommentsRepository.loadComments()` is relay-only and waits for one-shot Nostr queries to complete.
- Under the current Nostr stack, one-shot queries resolve on relay completion/timeout, so the comments sheet can feel blocked by slower relays even when some comments have already arrived.
- Author names and avatars can fill in later through profile fetches, but the comment thread itself does not currently use FunnelCake REST at all.

**Design**

1. Add a REST-backed bootstrap path for comments.
   - Extend the FunnelCake REST client with a typed `GET /api/videos/{id}/comments` reader.
   - Map the relay response into the existing `Comment` model, preserving NIP-22 threading fields from the response payload.
   - Return both the initial comments list and the server-reported `total` count so pagination can use authoritative totals.

2. Make comment loading progressive instead of blocking on relay query completion.
   - Start the live WebSocket subscription immediately when the comments sheet opens.
   - Kick off the REST bootstrap in parallel.
   - Emit comments into bloc state as soon as each source produces them.
   - Do not wait for EOSE before showing comments. EOSE is treated only as "stored backlog finished for now," not as a prerequisite for initial render.

3. Merge REST and WebSocket results by comment event ID.
   - Maintain a single in-memory `commentsById` map in the bloc/repository boundary.
   - If both REST and WebSocket deliver the same event, keep one entry.
   - Prefer richer data when merging. REST can provide author metadata early; WebSocket preserves the raw Nostr event flow for live updates and fallback behavior.

4. Keep comment writes on Nostr only.
   - Posting, deleting, and live watch behavior continue to use the existing WebSocket/Nostr path.
   - This change only affects read/bootstrap behavior and pagination.

5. Prefer REST for older-page pagination.
   - The first page and "load more" use `/api/videos/{id}/comments` with `limit` and `offset` when FunnelCake is available.
   - Relay pagination remains as the fallback path if REST is unavailable or fails.

**Data Flow**

1. `CommentsScreen` creates `CommentsBloc`.
2. `CommentsBloc` starts the live comment subscription immediately.
3. `CommentsBloc` or `CommentsRepository` kicks off REST bootstrap for page 1 in parallel.
4. Any live WebSocket comment is merged into state immediately.
5. When REST returns, its page is merged into the same comment map, deduping any comments already received live.
6. The bloc recomputes sorted/threaded output from the merged map and emits updated UI state.
7. Pagination uses REST `offset/limit` and `total` when possible, otherwise falls back to relay pagination.

**State Rules**

- Initial UI should move from `loading` to visible content as soon as the first comments arrive from either source.
- `hasMoreContent` should use REST `total` when available instead of page-size heuristics.
- `newCommentCount` should continue to track only comments that arrive after the sheet is opened.
- Sorting modes (`newest`, `oldest`, `top`) continue to operate on the merged in-memory set, not on a source-specific list.

**Error Handling**

- If REST bootstrap fails, continue with the live WebSocket path and log the REST failure.
- If WebSocket subscription fails, continue showing the REST-loaded page and disable live updates for that session.
- If both sources fail, preserve the current `loadFailed` UI.
- REST availability must be capability-driven, using the existing FunnelCake availability wiring rather than hard-coded assumptions.

**Testing**

- Add REST client tests for `/api/videos/{id}/comments`, including parsing, totals, and API error handling.
- Add `CommentsRepository` tests for:
  - REST-first success
  - REST failure with relay fallback
  - REST + WebSocket duplicate merge by ID
  - REST total driving pagination state
- Add `CommentsBloc` tests proving:
  - live comments can render without waiting for EOSE
  - REST and WebSocket results merge into a single thread
  - `load more` prefers REST pagination when available
- Keep existing comment-post/delete tests unchanged except where constructor wiring changes require updates.

**Non-Goals**

- Changing how comments are authored or deleted.
- Reworking comment item UI styling.
- Replacing user profile enrichment for unrelated surfaces.
- Changing the broader Nostr query semantics app-wide in this PR beyond what the comments flow needs.

**Follow-Up**

- If the streaming-first pattern works well for comments, apply the same non-blocking relay delivery pattern to other relay-backed read paths that still wait for one-shot query completion before rendering.
