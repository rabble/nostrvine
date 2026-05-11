# Brainstorm: people-search timeout / fallback UX (#3804)

Date: 2026-05-12
Parent epic: #3801
Sibling-blocks: #3791 ("cant find friends")
Touches: ProfileRepository · UserSearchBloc · PeopleSection · FeedPerformanceTracker

## Problem (from the issue, verified in code)

`ProfileRepository.searchUsersProgressive` runs three phases (local cache → Funnelcake REST → NIP-50 WebSocket) and yields the accumulated list after each. Phase 3 has a 5 s hard timeout; failures are caught with `on Object` and swallowed. `UserSearchBloc` wraps the stream in a 20 s outer `.timeout` and turns `TimeoutException` into `success` with whatever accumulated, without distinguishing it from a true successful empty.

The UI today (`PeopleSection`) only sees `status` + `results.isEmpty`. It cannot tell:

- whether all three sources succeeded with zero matches
- whether NIP-50 timed out but local + REST returned zero
- whether REST was unavailable and only NIP-50 contributed
- whether the outer 20 s timeout fired and cut the stream

All four scenarios render as the same "No results found for X." That is the lived experience of #3791.

## Three approaches considered

### Approach 1 — UI band-aid only

Add a Try-again button under the empty state and rephrase copy.

- pro: ~0 blast radius
- con: doesn't satisfy the issue's acceptance criteria (data-source strategy, instrumentation, intentional partial states); a true-empty retry yields a true-empty retry
- **rejected**

### Approach 2 — Enum-only degradation signal

Add `degradedReason: SearchDegradedReason?` to the bloc state. Repository signals degradation via a side-channel callback or terminal event.

- pro: smaller type churn
- con: side-channel callback inverts the layer flow (repository pushing into UI orchestration); single enum can't represent "2-of-3 sources succeeded"; the resolution still collapses meaningfully different outcomes
- **rejected**

### Approach 3 — Per-source provenance, end-to-end (recommended)

Repository emits a richer envelope per yield carrying both the accumulated profiles and the per-source outcome map. Bloc state mirrors the map. UI computes degraded-vs-true-empty from the map and shows distinct affordances. Per-source latency/outcome flows into the existing `FeedPerformanceTracker`. Repo gets a short `mobile/docs/PEOPLE_SEARCH.md` codifying the contract.

- pro: meets all four acceptance criteria; #3791's user-visible bug becomes a one-screen fix (degraded-empty → existing `SearchSectionErrorState` with Try again); converts today's silent suppressions into observable signals; partially repays #3593 (suppressed catch blocks) and #3627 (data-source doc)
- con: changes the signature of `searchUsersProgressive` — but its only caller in `mobile/lib` is `UserSearchBloc`, so the blast radius is small and well-tested
- **converged on this**

## Design specifics

### New types in `profile_repository`

```dart
enum SearchSource { localCache, funnelcakeApi, nip50Relay }

sealed class SearchSourceStatus { const SearchSourceStatus(); }
class SearchSourcePending  extends SearchSourceStatus { const SearchSourcePending(); }
class SearchSourceSkipped  extends SearchSourceStatus { const SearchSourceSkipped(); }
class SearchSourceSuccess  extends SearchSourceStatus {
  const SearchSourceSuccess({required this.resultCount, required this.latencyMs});
  final int resultCount;
  final int latencyMs;
}
class SearchSourceFailed   extends SearchSourceStatus {
  const SearchSourceFailed({required this.reason, required this.latencyMs});
  final SearchSourceFailureReason reason;
  final int latencyMs;
}
enum SearchSourceFailureReason { timeout, network, unavailable, other }

class ProgressiveSearchResult {
  const ProgressiveSearchResult({
    required this.profiles,
    required this.sources,
    required this.isComplete,
  });
  final List<UserProfile> profiles;
  final Map<SearchSource, SearchSourceStatus> sources;
  final bool isComplete;
}
```

Sealed classes (not enums) because each status carries different shape — `Success` has a count and latency, `Failed` has a reason and latency. That avoids the "enum + side table" smell. These live in the **repository layer** (data shape, not bloc state), so the "no error strings in bloc state" rule from `state_management.md` does not apply to `SearchSourceFailed.reason` — it's an enum tag, not a message.

### `searchUsersProgressive` becomes `Stream<ProgressiveSearchResult>`

Each phase records its outcome in a local map and yields a `ProgressiveSearchResult` carrying the current snapshot. Final yield sets `isComplete: true`. Existing logging stays; failures additionally update the source map.

The non-progressive sibling `searchUsers` (used only by `NewMessageSearchBloc`) is **not** changed in this PR.

### `UserSearchBloc` state

Adds:

```dart
final Map<SearchSource, SearchSourceStatus> sourceOutcomes;

/// True when we have nothing to show AND at least one source reports failure.
/// UI shows this as an error state (with retry), not "No results found".
bool get isDegradedEmpty =>
    results.isEmpty &&
    sourceOutcomes.values.any((s) => s is SearchSourceFailed);
```

The outer 20 s timeout stops silently turning into success-with-empty. On `TimeoutException` the bloc marks every `pending` source as `Failed(reason: timeout)` then emits `success`. Because `isDegradedEmpty` is a getter, the UI consequence is automatic.

Reporting policy (per `error_handling.md` matrix):

- `TimeoutException` → not reportable (network/expected)
- `on Exception` → wrap with `Reportable(e, context: '_onQueryChanged')` only when the inner is not network/IO. Practically, the only Exception that reaches that catch from the progressive stream today is a `StateError` from the WS client — those *are* worth reporting. Keep the existing `feedTracker.trackFeedError` call.

### UI

`PeopleSection._PeopleContent.build`:

```dart
// Skeleton when still loading + nothing to show
if ((status == .initial || status == .loading) && results.isEmpty) {
  return const _PeopleSkeletonLoader();
}

// Failure OR degraded-empty → existing error state with Try again
if (status == .failure || state.isDegradedEmpty) {
  return SearchSectionErrorState(
    onRetry: () =>
        context.read<UserSearchBloc>().add(UserSearchQueryChanged(query)),
  );
}

// True empty — kept as-is
if (results.isEmpty) {
  if (showAll) return SearchSectionEmptyState(query: query);
  return const SliverToBoxAdapter(child: SizedBox.shrink());
}
```

That single delta is #3791's user-visible fix: when the user types `friend's_name` and every source either timed out or was unavailable, they get "We had trouble reaching some sources — try again" with a retry button, not a misleading "No results found for friend's_name."

The non-empty-but-some-source-failed path keeps the current rendering. We can add a subtle "still loading more" pill in a follow-up if telemetry shows users care; out of scope here.

### Instrumentation

Extend `FeedPerformanceTracker`:

```dart
void trackSearchSource(SearchSource source, SearchSourceStatus status);
```

Repository fires it as each phase finishes. Existing `startFeedLoad` / `markFirstVideosReceived` / `markFeedDisplayed` / `trackFeedError` calls keep their current semantics. New event lets us answer in the field: "is NIP-50 the actual problem, or is REST down, or is the query genuinely missing?"

### Constants

`mobile/lib/constants/search_constants.dart` already exists. Add:

```dart
const nip50QueryTimeout = Duration(seconds: 5);
const userSearchOuterTimeout = Duration(seconds: 20);
```

and migrate the hard-coded numbers in `profile_repository.dart` line 1087 and `user_search_bloc.dart` line 26. Touch what we touch (per `code_style.md` "No Hardcoded Values").

### Doc

`mobile/docs/PEOPLE_SEARCH.md` (new, ~80 lines):

1. Layered flow diagram (UI → Bloc → Repository → 3 clients)
2. Canonical fallback order + skip conditions (offset > 0)
3. Latency budgets (5 s NIP-50, 20 s outer)
4. Degradation contract: how `sourceOutcomes` is populated, what `isDegradedEmpty` means, when UI shows error-with-retry vs true-empty
5. Pointer to FeedPerformanceTracker for instrumentation surface

Linked from #3627 as partial payment.

## Test plan

### Unit / bloc

- `profile_repository_test.dart`: 4 new tests
  - all sources succeed: `sources` keyed local=success, api=success, relay=success
  - REST throws: `sources[api] = failed(network)`, others success
  - NIP-50 times out: `sources[relay] = failed(timeout)`, others success
  - all-failed: `sources` all failed, `profiles` empty
  - existing progressive yield tests migrate to `.profiles` accessor
- `user_search_bloc_test.dart`: 3 new blocTests
  - outer timeout with empty accumulated: state has `degradedEmpty == true`, status `success`
  - sources-map round-trips from repository to bloc state unchanged
  - `isDegradedEmpty` getter correctness across permutations
  - existing "emits success with partial results when stream times out" test updates assertion on `sourceOutcomes`

### Widget

- `people_section_test.dart`: 2 new tests
  - state with `{results: [], sources: {nip50Relay: failed}}` renders `SearchSectionErrorState`
  - state with `{results: [], sources: {all: success}}` renders `SearchSectionEmptyState`

### Manual

- Force-timeout NIP-50 (point relay list at a sink) → degraded-empty banner with retry
- Funnelcake key empty (`isAvailable=false`) → REST skipped, NIP-50 succeeds, no degraded banner
- All sources offline → degraded-empty banner with retry
- Real query that exists → unchanged happy path

## Risk assessment

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Sealed-class type imports break callers in unrelated areas | Low | `searchUsersProgressive` has one caller; sealed types are new, no name collisions |
| `ProgressiveSearchResult` adds GC pressure on hot search loops | Low | Single object per yield (~3 per query); negligible vs the profile list itself |
| `FeedPerformanceTracker` enum expansion breaks analytics dashboards | Low | New method, no change to existing events |
| Outer timeout change surfaces previously-hidden Crashlytics reports | Low | Only `Reportable`-wrapped non-network exceptions report; matrix-aligned |
| Doc drifts from code | Medium | Cross-link doc from code comments, gate on review |

## Non-goals (explicit)

- Changing the 5 s NIP-50 timeout value (latency budget = product, parent epic Q3)
- Replacing or adding NIP-50 relays (parent epic Q4)
- Auto-navigate-while-typing (#3802)
- Focus / keyboard continuity (#3803, #3020)
- Blocklist filtering of search (#3805, #948)
- Replacing `searchUsers` (different caller, different scope)
- BLoC `addError` sweep (#3592 — separate PR)
- "Still searching…" inline indicator on non-empty progressive states
- Caching architecture work (#3624)
- UI bypass refactor (#3620)

## Open question for the subgroup (non-blocking)

Should the degraded-empty banner copy be specifically "We're having trouble reaching some search sources" (technical truth) or generic "Couldn't load results — try again" (matches existing l10n `searchSomethingWentWrong`)? **Recommendation: reuse `searchSomethingWentWrong` + `searchTryAgain` — they exist, they're already translated to 16+ locales, and they read fine. Don't expand l10n surface without product input.**

If product later wants specific copy, it's a one-line ARB change.
