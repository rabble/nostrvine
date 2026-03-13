# Comments REST Streaming Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Bootstrap video comments from FunnelCake REST without blocking the sheet on relay query completion, then merge live WebSocket comments immediately with ID-based dedupe.

**Architecture:** Add a typed REST client for `/api/videos/{id}/comments`, inject it into `CommentsRepository`, and make the comments flow progressive instead of query-complete-driven. `CommentsBloc` should start the live subscription immediately, merge REST and relay comments into one `commentsById` map, use EOSE only to mark the end of historical backlog, and keep REST pagination state separate from live inserts.

**Tech Stack:** Flutter, Dart, Riverpod, BLoC, `funnelcake_api_client`, `comments_repository`, Nostr WebSocket subscriptions, package tests, bloc tests

---

## Chunk 1: FunnelCake Comments Endpoint

### Task 1: Add typed REST support for `/api/videos/{id}/comments`

**Files:**
- Create: `mobile/packages/funnelcake_api_client/lib/src/models/video_comment.dart`
- Create: `mobile/packages/funnelcake_api_client/lib/src/models/video_comments_response.dart`
- Create: `mobile/packages/funnelcake_api_client/lib/src/models/models.dart`
- Modify: `mobile/packages/funnelcake_api_client/lib/src/funnelcake_api_client.dart`
- Modify: `mobile/packages/funnelcake_api_client/lib/funnelcake_api_client.dart`
- Modify: `mobile/packages/funnelcake_api_client/test/src/funnelcake_api_client_test.dart`

- [ ] **Step 1: Write the failing REST client tests**

Cover:
- successful parse of `comments` plus `total`
- `sort`, `limit`, and `offset` query parameters
- `404` and non-200 API errors
- timeout handling

- [ ] **Step 2: Run the targeted REST client tests and watch them fail**

Run: `flutter test test/src/funnelcake_api_client_test.dart`

- [ ] **Step 3: Add minimal DTOs and client method**

Implement:
- `VideoComment` DTO for the documented response shape
- `VideoCommentsResponse` DTO for `comments` + `total`
- `FunnelcakeApiClient.getVideoComments({required String videoId, String sort = 'newest', int limit = 25, int offset = 0})`

- [ ] **Step 4: Re-run the REST client tests until green**

Run: `flutter test test/src/funnelcake_api_client_test.dart`

## Chunk 2: Comments Repository REST-First Read Path

### Task 2: Make `CommentsRepository` REST-first with relay fallback

**Files:**
- Modify: `mobile/packages/comments_repository/pubspec.yaml`
- Modify: `mobile/packages/comments_repository/lib/src/comments_repository.dart`
- Modify: `mobile/packages/comments_repository/test/src/comments_repository_test.dart`

- [ ] **Step 1: Write the failing repository tests**

Cover:
- REST bootstrap returns a `CommentThread` built from `/api/videos/{id}/comments`
- repository falls back to the relay query when REST is unavailable or throws
- REST and relay duplicate IDs collapse to one comment
- `watchComments` can subscribe without `since` and forwards `onEose`

- [ ] **Step 2: Run the targeted repository tests and watch them fail**

Run: `flutter test test/src/comments_repository_test.dart`

- [ ] **Step 3: Implement the repository changes**

Implement:
- add optional `FunnelcakeApiClient` dependency to `CommentsRepository`
- map REST DTOs into existing `Comment` objects
- keep relay query logic as the fallback path
- update `watchComments` so `since` is optional and `onEose` can be forwarded to the underlying Nostr subscription

Notes:
- keep write operations (`postComment`, `deleteComment`) unchanged
- keep `loadCommentsByAuthor` unchanged

- [ ] **Step 4: Re-run the repository package tests until green**

Run: `flutter test test/src/comments_repository_test.dart test/src/load_comments_by_author_test.dart`

## Chunk 3: Provider Wiring And Progressive Bloc State

### Task 3: Inject the REST client into the app comments flow

**Files:**
- Modify: `mobile/lib/providers/app_providers.dart`

- [ ] **Step 1: Write or extend the smallest test only if provider construction changes require coverage**

If no provider test is practical, capture this in the implementation notes and rely on bloc integration coverage below.

- [ ] **Step 2: Wire `funnelcakeApiClientProvider` into `commentsRepositoryProvider`**

Implement:
- pass the typed FunnelCake client into `CommentsRepository`
- keep the provider `keepAlive` behavior unchanged

- [ ] **Step 3: Run the smallest relevant app-level test or analyzer check**

Run: `flutter analyze lib/providers/app_providers.dart`

### Task 4: Make `CommentsBloc` render progressively and classify historical vs live stream events

**Files:**
- Modify: `mobile/lib/blocs/comments/comments_bloc.dart`
- Modify: `mobile/lib/blocs/comments/comments_event.dart`
- Modify: `mobile/lib/blocs/comments/comments_state.dart`
- Modify: `mobile/test/blocs/comments/comments_bloc_test.dart`

- [ ] **Step 1: Write the failing bloc tests**

Cover:
- a streamed historical comment can move the bloc to visible `success` state before REST/relay query completion
- streamed comments received before EOSE do not increment `newCommentCount`
- streamed comments received after EOSE do increment `newCommentCount`
- REST-loaded comments merge with already-streamed comments by ID without duplication
- REST pagination offset is tracked separately from live inserts so `load more` does not skip older comments

- [ ] **Step 2: Run the targeted bloc tests and watch them fail**

Run: `flutter test test/blocs/comments/comments_bloc_test.dart`

- [ ] **Step 3: Implement the bloc changes**

Implement:
- start `watchComments` immediately in `_onLoadRequested` instead of after the initial fetch succeeds
- subscribe without `since` for the initial sheet load so backlog events stream immediately
- use an `onEose` callback/event only to mark "historical backlog complete"
- merge any arriving comment into `commentsById` immediately
- only increment `newCommentCount` after the initial backlog is complete
- keep a separate REST pagination counter/offset so live comments do not affect `load more`
- preserve existing dedupe and blocklist behavior

- [ ] **Step 4: Re-run the targeted bloc tests until green**

Run: `flutter test test/blocs/comments/comments_bloc_test.dart`

## Chunk 4: Regression Verification And Commit

### Task 5: Run focused regressions, review the diff, and commit

**Files:**
- Review: `mobile/packages/funnelcake_api_client/lib/src/funnelcake_api_client.dart`
- Review: `mobile/packages/comments_repository/lib/src/comments_repository.dart`
- Review: `mobile/lib/blocs/comments/comments_bloc.dart`
- Review: `mobile/lib/providers/app_providers.dart`

- [ ] **Step 1: Run focused verification across package and app layers**

Run:
- `flutter test test/src/funnelcake_api_client_test.dart` from `mobile/packages/funnelcake_api_client`
- `flutter test test/src/comments_repository_test.dart test/src/load_comments_by_author_test.dart` from `mobile/packages/comments_repository`
- `flutter test test/blocs/comments/comments_bloc_test.dart test/screens/comments/comments_screen_test.dart test/screens/comments/comments_list_test.dart` from `mobile`

- [ ] **Step 2: Run a targeted analyzer pass**

Run: `flutter analyze lib/blocs/comments lib/providers/app_providers.dart test/blocs/comments/comments_bloc_test.dart`

- [ ] **Step 3: Review the final diff for scope**

Check:
- no unrelated provider churn
- no accidental `pubspec.lock` or generated-file noise
- no REST writes added for comments

- [ ] **Step 4: Commit the implementation**

Run:
- `git add mobile/packages/funnelcake_api_client mobile/packages/comments_repository mobile/lib/providers/app_providers.dart mobile/lib/blocs/comments mobile/test/blocs/comments/comments_bloc_test.dart docs/superpowers/plans/2026-03-12-comments-rest-streaming.md`
- `git commit -m "feat(comments): bootstrap video comments from rest"`
