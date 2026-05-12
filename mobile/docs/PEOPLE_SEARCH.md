# People search: data sources, degradation, and UI contract

This document is the canonical reference for how user-profile search
works in the mobile app. It is the partial implementation answer to
the parent epic's "explicit data-source strategy" requirement
(#3801, #3627) and pins the contract that the bloc and UI rely on.

If you change behavior in `ProfileRepository.searchUsersProgressive`,
`UserSearchBloc`, or `PeopleSection`, update this file at the same
time.

## Layered flow

```
Explore / SearchResultsAppBar (UI)
  └── UserSearchQueryChanged event
        ↓
UserSearchBloc                              mobile/lib/blocs/user_search/
  • debounceRestartable transformer
  • outer .timeout(userSearchOuterTimeout)  mobile/lib/constants/search_constants.dart
  • on TimeoutException → promote pending sources to failed(timeout),
    emit `success` with `sourceOutcomes` populated
  • on Exception → Reportable wrap + `failure` state
  • per-yield: forward each newly-terminal source to
    FeedPerformanceTracker.trackSearchSource
        ↓
ProfileRepository.searchUsersProgressive    mobile/packages/profile_repository/
  Phase 1 (offset==0): searchUsersLocally        SQLite cache, no timeout
  Phase 2:             funnelcake.searchProfiles REST, no explicit timeout
  Phase 3 (offset==0): nostrClient.queryUsers    NIP-50 WS, .timeout(5s)
  Each phase records a SearchSourceStatus in the result envelope.
  Final yield: _enrichFromCache + _applyFilter (block filter + boost)
        ↓
NostrClient.queryUsers                      mobile/packages/nostr_client/
  • tempRelays = [relay.nostr.band, search.nos.today, nostr.wine]
```

## Source consultation order

The repository consults sources in a fixed, sequential order:

1. **localCache** — SQLite profile cache. Instant. Consulted only on
   the first page (`offset == 0`).
2. **funnelcakeApi** — Funnelcake REST `/api/profiles/search`. Fast.
   Consulted on every page. Skipped (`SearchSourceSkipped`) when the
   client is configured without a base URL.
3. **nip50Relay** — Federated NIP-50 search across three hardcoded
   relays. Consulted only on the first page (`offset == 0`). Hard
   timeout of `_nip50SearchTimeout` (5 s).

After each phase that produced new profiles, the repository yields a
`ProgressiveSearchResult` carrying:

- the accumulated deduplicated profile list
- the running `Map<SearchSource, SearchSourceStatus>`
- `isComplete: false` for intermediate yields, `true` for the final

A query with no matches still gets a final yield with
`profiles: []`, `isComplete: true`, and per-source outcomes — so the
bloc can always distinguish "true empty" from "everything failed".

## Source statuses

`SearchSourceStatus` is sealed:

| status | meaning | latency? |
|---|---|---|
| `SearchSourcePending` | Source has not yet reported. Internal/initial state, normally not visible in a terminal envelope. | — |
| `SearchSourceSkipped` | Source was intentionally not consulted (`offset > 0` for local/NIP-50, or Funnelcake unconfigured). | — |
| `SearchSourceSuccess` | Source returned successfully. Carries `resultCount` (new distinct profiles this source contributed to the accumulated result set) and `latencyMs`. | yes |
| `SearchSourceFailed` | Source threw / timed out. Carries `SearchSourceFailureReason` (`timeout` / `network` / `other`) and `latencyMs`. | yes |

The bloc never re-derives or invents source statuses — it forwards
the repository's view, except when the outer 20 s timeout fires (see
below).

## Outer-timeout contract

`UserSearchBloc` wraps the entire progressive stream in
`searchTimeout`, defaulting to `userSearchOuterTimeout` (20 s). When
it fires:

1. The bloc takes the latest snapshot of `state.sourceOutcomes`.
2. For each source still in `SearchSourcePending` (or absent from the
   snapshot defensively), it writes
   `SearchSourceFailed(reason: timeout, latencyMs: <outer timeout>)`.
3. Sources that already reported a terminal status keep that status.
4. The bloc emits `UserSearchStatus.success` with the updated map.

This means after an outer timeout, `state.isDegradedEmpty` is `true`
iff `state.results` is empty — which is the case the UI cares about.

## `isDegradedEmpty` getter

```dart
bool get isDegradedEmpty =>
    results.isEmpty &&
    sourceOutcomes.values.any((s) => s is SearchSourceFailed);
```

True iff (1) we have no profiles to show, AND (2) at least one source
reported failure. This is the single switch the UI uses to decide
between "true empty" (show empty-state with copy) and "degraded
empty" (show error-with-retry).

## UI contract (`PeopleSection`)

Branch order in `_PeopleContent.build`:

1. `status == initial || (status == loading && results.isEmpty)` →
   `_PeopleSkeletonLoader`
2. `status == failure || isDegradedEmpty` →
   `SearchSectionErrorState` (retry button)
3. `results.isEmpty && showAll` → `SearchSectionEmptyState`
4. `results.isEmpty && !showAll` → hidden section
5. otherwise → render the list

Outer `PeopleSection.build` also hides the entire section in the All-
tab preview when the result is truly empty
(`!showAll && status == success && results.isEmpty && !isDegradedEmpty`).
Degraded-empty intentionally bypasses the hide so the user can retry
even from the All tab. This is the #3791 fix.

## Instrumentation

`FeedPerformanceTracker.trackSearchSource(SearchSource, SearchSourceStatus)`
fires exactly once per source per query, when the source transitions
from pending into a terminal state. Pending statuses produce no
event.

Analytics event name: `user_search_source`. Parameters:

- `source`: `localCache` / `funnelcakeApi` / `nip50Relay`
- `status`: `success` / `failed` / `skipped`
- `result_count`, `latency_ms` (success only)
- `reason`, `latency_ms` (failed only)

Existing `feed_first_batch_received`, `feed_load_complete`, and
`feed_error` events for `feed_type=user_search` are unchanged.

## What is intentionally not in scope

- Changing the 5 s NIP-50 timeout value — latency budget is a product
  decision (parent epic Q3).
- Replacing or extending the NIP-50 relay list — parent epic Q4.
- Auto-navigate-while-typing behavior — see #3802.
- Focus / keyboard continuity across Explore → Search — see #3803,
  #3020.
- Blocklist filtering of search results — see #3805, #948.
- `searchUsers` (the non-progressive sibling used by
  `NewMessageSearchBloc`) — different caller, different scope.

## Related issues

- #3804 — this contract's execution ticket
- #3791 — the user-visible "cant find friends" report this closes
- #3801 — parent search-stabilization epic
- #3627 — data-source strategy doc requirement (partial payment)
- #3593 — suppressed catch blocks (the per-source-failed wrapping
  pays the relevant Phase 3 portion)
