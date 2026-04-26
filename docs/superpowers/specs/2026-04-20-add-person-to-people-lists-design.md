# Add Person to People Lists — Design

**Date:** 2026-04-20
**Branch:** `investigate/list-management` (worktree: `.worktrees/investigate-list-management`)
**Feature flag:** `FF_CURATED_LISTS` (reused; no new flag)

## Problem

Viewing people lists works today — the Explore screen renders a "People Lists" section from `UserListService`, and `UserListPeopleScreen` opens when a card is tapped. The default "Divine Team" list appears there and is usable.

What doesn't work: adding or removing pubkeys from lists. Users cannot put a person in a list from anywhere in the app. Investigation findings:

- `UserListService.addPubkeyToList` / `removePubkeyFromList` exist but are called only from the service itself and its tests. No UI path invokes them.
- `UserListService` is `SharedPreferences`-only despite being labelled "NIP-51 kind 30000". It never publishes to a relay, so even if UI were wired, lists would be device-local and unshareable.
- The video-side equivalent ("add video to curated list", kind 30005) is fully wired but hidden behind the same `FF_CURATED_LISTS` flag, which has no `defaultValue: true` and is off in every build.

The loss was not a regression from a UI update — the add-UI for people lists was never shipped and the underlying storage was never completed for relay publishing.

## Goals

- Ship "add person to list" across all natural surfaces in the app.
- Publish kind 30000 NIP-51 follow sets to the relay so lists are portable, interoperable, and sync across devices.
- Preserve existing view surfaces — the Explore "People Lists" section and `UserListPeopleScreen` keep working with zero rewrite.
- Land behind `FF_CURATED_LISTS` (still off). A separate, small PR flips the flag once we're confident; that same flip also lights up the existing dark video add-to-list feature.
- Ship analytics for every mutation from day one.

## Non-goals

- Kind 10000 mute lists, kind 30003 bookmark sets, kind 30005 curated video lists (already done).
- Private (encrypted) lists. `isPublic` stays in the model but the UI toggle is disabled with a "Coming soon" label in v1.
- List sharing, list subscriptions, list feeds as consumption surfaces.
- Large lists. **v1 assumes a list has ≤ 500 members.** Kind-30000 events with thousands of `p`-tags can exceed relay size limits. If usage demands larger lists, chunking or multi-event sharding is a separate spec.
- Migration of anyone's existing `SharedPreferences`-stored `UserList` data. The service is dark and no UI ever wrote to it, so no users have data to migrate. `UserListService` is deleted.

---

## Architecture

```
UI (sheets + screens)
  └── PeopleListsBloc (global, provided at app shell)
        └── PeopleListsRepository
              ├── NostrClient (publish + subscribe, kind 30000)
              ├── LocalCache (Hive — mirror the curated-video cache pattern)
              └── Synthetic "Divine Team" list (merged into the stream)
        └── FirebaseAnalytics (injected collaborator, events fire from BLoC)
```

Location:

```
mobile/lib/features/people_lists/
  bloc/    people_lists_bloc.dart  (with part files for event + state)
  view/    add_to_people_lists_sheet.dart
           add_people_to_list_screen.dart
           create_people_list_page.dart
           people_list_membership_indicator.dart
  models/  mutation.dart

mobile/packages/people_lists_repository/
  lib/src/people_lists_repository.dart
  lib/src/people_lists_repository_impl.dart
  lib/src/local_people_lists_cache.dart
```

Constructor injection only. `PeopleListsRepository` has no Flutter import.

**Reference pattern for the repository layer:** `mobile/packages/curated_list_repository/`. Do **not** mirror `mobile/lib/services/curated_list_service.dart` — that 1609-line file is a historical mislocation (repository-layer logic leaking into `lib/services/`), kept working but not a template to copy. The `packages/`-based layout is the one architecture.md prescribes.

**Rewiring existing Riverpod consumers.** The Explore "People Lists" section and `UserListPeopleScreen` consume `userListsProvider` (`mobile/lib/providers/list_providers.dart:18-21`), which today sources from `UserListService`. We rewrite that provider to bridge onto the new `PeopleListsBloc`'s state — existing call sites (Explore, list-people screen, `allListsProvider`) stay unchanged. This is the *only* legacy Riverpod touch we preserve. Everything new is BLoC.

### Nostr event shape (NIP-51 kind 30000, public v1)

```
kind: 30000
tags:
  ["d", "<list-id>"]            // addressable d-tag, immutable
  ["title", "<name>"]
  ["description", "<desc>"]     // optional
  ["image", "<url>"]            // optional
  ["p", "<pubkey-hex>"], ...    // one per member
content: ""                      // v1 public only; encrypted content reserved for v2
```

`updated_at` monotonic. Relay accepts as replaceable on `<pubkey>:30000:<d-tag>`.

### Divine Team default list

Synthesized client-side in v1 from `AppConstants.divineTeamPubkeys`, merged into the repository's stream with `isEditable: false`. Treated as a real list everywhere in UI except it's greyed and non-interactive in pickers, and has no "Remove from list" affordance in `UserListPeopleScreen`. Migrating to a real published NIP-51 event signed by the team's pubkey is a follow-up that needs zero app changes.

---

## Data model

No change to `packages/models/UserList`. Existing fields are sufficient: `id`, `name`, `description`, `imageUrl`, `pubkeys`, `createdAt`, `updatedAt`, `isPublic`, `nostrEventId`, `isEditable`.

`id` semantics: for owned lists, the d-tag of the kind 30000 event. For the synthetic Divine Team list, the constant string `"divine_team"`.

---

## Repository contract

```dart
abstract class PeopleListsRepository {
  /// Emits default lists + user-owned lists, sorted (defaults first, then
  /// user-owned by updatedAt desc). Hot stream kept alive via relay subscription.
  Stream<List<UserList>> watchLists();

  Future<UserList> createList({required String name, String? description});
  Future<void> deleteList(String listId);
  Future<void> addPubkey(String listId, String pubkey);
  Future<void> removePubkey(String listId, String pubkey);

  /// Batch — used by entry point 4 ("add N people to this list").
  /// Computes the diff from the current members; publishes one replaceable event.
  Future<void> setPubkeys(String listId, Set<String> pubkeys);
}
```

Publish failures throw. Repo does not store error state. Local cache is written only after the relay confirms (OK message). Optimistic revert happens in the BLoC, not the repo.

---

## BLoC

Single global `PeopleListsBloc` provided at the app shell. Subscribes to `watchLists()` on init; stays alive for the app's lifetime.

```dart
sealed class PeopleListsEvent {}
class PeopleListsSubscribed extends PeopleListsEvent {}

class PeopleListCreated extends PeopleListsEvent {
  final String name;
  final String? description;
  final ListEntryPoint entryPoint;
}

class PeopleListDeleted extends PeopleListsEvent {
  final String listId;
}

class PeopleListMembershipToggled extends PeopleListsEvent {
  final String listId;
  final String pubkey;
  final ListEntryPoint entryPoint;
}

class PeopleListMembersSet extends PeopleListsEvent {  // batch
  final String listId;
  final Set<String> pubkeys;
  final ListEntryPoint entryPoint;
}

class PeopleListMutationCleared extends PeopleListsEvent {
  final String mutationId;
}

class PeopleListMembershipUndone extends PeopleListsEvent {
  final String listId;
  final String pubkey;
  final ListEntryPoint originalEntryPoint;
}
```

```dart
enum PeopleListsStatus { initial, loading, ready, failure }
enum MutationKind { create, delete, toggleAdd, toggleRemove, batchSet }
enum MutationStatus { pending, success, failure }

class Mutation extends Equatable {
  final String mutationId;
  final MutationKind kind;
  final String? listId;
  final String? pubkey;      // nullable for batch
  final MutationStatus status;
}

class PeopleListsState extends Equatable {
  final PeopleListsStatus status;
  final List<UserList> lists;
  final Map<String, Mutation> pendingMutations;   // keyed by mutationId
  final Map<String, Set<String>> listsByPubkey;    // reverse index: pubkey → list ids

  // O(1) lookups via the reverse index:
  Iterable<Mutation> mutationsForRow(String listId, String pubkey) => ...;
  int listCountContaining(String pubkey) => listsByPubkey[pubkey]?.length ?? 0;
  bool isMember(String listId, String pubkey) =>
      listsByPubkey[pubkey]?.contains(listId) ?? false;
}
```

The `listsByPubkey` reverse index is rebuilt on every `lists` replacement inside the BLoC (not in the widget layer). This keeps the profile "in N lists" chip and row `isMember` checks O(1) regardless of how many lists the user owns.

No error strings in state (per `state_management.md`). Failures are surfaced through `addError(e, st)` plus a mutation entry marked `failure`. UI reads failure rows via `context.select` for row-scoped rebuilds.

### Event transformers (prevent race conditions)

- `PeopleListMembershipToggled` and `PeopleListMembersSet` use `sequential()` from `bloc_concurrency`. Two rapid taps on the same row serialize rather than interleave, preventing "add then remove" and "remove then add" from racing against each other at the relay.
- `PeopleListCreated` uses `droppable()`. While a create is in flight, subsequent create taps are ignored (prevents accidental double-creates from double-taps).
- `PeopleListMutationCleared` remains `concurrent` (default) — independent per-mutation timers.

### Relay-echo vs optimistic-state merge rule

The repository's `watchLists()` stream can emit an updated list from the relay while an optimistic mutation for the same `(listId, pubkey)` is still `pending` — either because another device published the change first or because the relay echoed our own publish. Merge rule:

1. When a new `lists` value arrives from the stream, the BLoC walks `pendingMutations`. For each `pending` mutation, the stream's value for that `(listId, pubkey)` is **overridden** by the optimistic value in `lists`.
2. When a mutation transitions to `success`, the override is released and the next stream emission flows through unchanged.
3. When a mutation transitions to `failure`, the optimistic change is reverted *before* the override is released, so the final state matches the relay.

This rule lives in the BLoC, not the repo. The repo's stream is canonical; the BLoC owns the optimistic overlay.

### Optimistic flow (single-toggle)

1. UI dispatches `PeopleListMembershipToggled(listId, pubkey, entryPoint)`.
2. BLoC generates a `mutationId`, applies the optimistic change to `lists`, adds a `pending` `Mutation` to `pendingMutations`, emits.
3. BLoC calls `repository.addPubkey` / `removePubkey`.
4a. **On success:** analytics event fires, mutation marked `success`, schedules `PeopleListMutationCleared` 100 ms later.
4b. **On failure:** `addError(e, st)`, mutation marked `failure`, **lists reverted** to pre-optimistic state for that pubkey/list. UI listens for `failure` mutations and shows a retry snackbar. `people_list_publish_failed` analytics fires.

### Batch flow

Same shape. The full-screen picker keeps its `Set<String>` selection in `StatefulWidget` local state. On commit it computes the diff from `currentMembers` and dispatches a single `PeopleListMembersSet(newMembers)`.

On success the BLoC emits analytics per-pubkey **in both directions** based on the diff:

- `people_list_member_added` fires once per pubkey in `newMembers \ currentMembers`
- `people_list_member_removed` fires once per pubkey in `currentMembers \ newMembers`
- `entry_point = list_people_screen` for both

Dashboards don't double-count, and removals that happen through deselection in the batch picker are observable. A batch set where the diff is empty emits no per-pubkey events (but the publish still happens — no-op events on the relay are harmless and cheap, but see if we can short-circuit the publish entirely when the diff is empty).

### BLoC-to-BLoC

None. Any coordination with other BLoCs (e.g. the profile header "in N lists" chip) is done via `BlocListener`/`BlocSelector` in the UI.

---

## UX

Full-bleed project rules apply: dark mode only, `VineTheme`, `DivineIcon`, no inline text styles, 48×48 minimum tap targets, semantic identifiers from constants, `SemanticsService.announce` on mutations, `HapticFeedback.selectionClick` on toggle.

### User-side picker — draggable bottom sheet

Used from entry points 1, 2, 3, 5. Mirrors the existing `SelectListDialog` for videos to keep visual consistency.

Layout (top to bottom):

- Header: "Add to lists" + "@handle" subtitle
- `+ New list` row — tapping expands in place to a single-line name field with an inline "Create" button
- Scrollable list rows:
  - checkbox · list name · "N people" · (lock icon trailing when `!isEditable`)
  - Tap: optimistic toggle, haptic click, announce "Added @handle to *X*" / "Removed @handle from *X*"
  - While the row's mutation is `pending`, show a 12 px spinner replacing the checkbox
  - On `failure`, the row reverts and a bottom snackbar appears: "Couldn't reach the relay · Retry"
  - On remove success: 4-second snackbar "Removed from *X* · Undo" dispatches `PeopleListMembershipUndone` on tap
- Empty state (no owned lists): illustration + "Lists are how you remember the people who matter. Yours. Portable across Nostr." + primary "Create your first list"

### List-side picker — full-screen route

Route: `/lists/:id/add-people` (typed `GoRouteData`). Pushed from a new "+ Add people" button on `UserListPeopleScreen`, visible only when `userList.isEditable`.

Layout:

- App bar: "Add people" + list name as subtitle
- Segmented control: **Following · Followers · Search**
- Person rows: avatar · display name · @handle · trailing circular checkbox
- Already-members: greyed, disabled, fixed checkmark
- Persistent top search (queries funnelcake user search; falls back to relay query per the architecture.md fallback rule)
- Pinned bottom primary: **Add N** (disabled when 0 selected). Tap dispatches `PeopleListMembersSet`; success pops the route; failure stays with retry snackbar.

### Create-list full-screen page

Route: `/lists/new`. Fields: name · description · public/private toggle (disabled in v1). Reached from the Lists tab header. The in-sheet "+ New list" row handles the fast common case; this page exists for when users want the full form.

### "In N of your lists" indicator

Small `divine_ui` chip on profile headers (other users only; rendered by `ProfileHeaderWidget`). Hidden when `N == 0`. Tapping opens the **standard user-side sheet** — no pre-filtering. The rows containing this pubkey are already checked, which is the signal the user wants. Pre-filtering would hide the option to add them to additional lists, which is the most likely next action. Feature-flagged with the rest.

### Entry-point wiring

| Surface | Trigger | File to modify |
|---|---|---|
| Other-user profile three-dot | "Add to list" menu item | `profile_screen_router.dart` other-profile menu |
| Followers row | Trailing three-dot on each tile | `followers/*_screen.dart` row widget |
| Following row | Same | Same |
| User search result row | Same trailing three-dot | search result tile widget |
| Own profile | Menu entry | own-profile menu |
| `UserListPeopleScreen` | "+ Add people" primary action | `user_list_people_screen.dart` |
| Profile header chip | "In N lists" | `profile_header_widget.dart` |

All wrapped in `ref.watch(isFeatureEnabledProvider(FeatureFlag.curatedLists))` — same guard pattern already in use at `share_sheet_more_actions.dart:36`.

---

## Analytics

Injected `FirebaseAnalytics` collaborator on the BLoC. Events fire on mutation **success**, never on optimistic dispatch. All Nostr IDs full-length — never truncated.

| Event | Params |
|---|---|
| `people_list_created` | `list_id`, `has_description` |
| `people_list_deleted` | `list_id`, `member_count` (pre-delete) |
| `people_list_member_added` | `list_id`, `pubkey`, `entry_point` |
| `people_list_member_removed` | `list_id`, `pubkey`, `entry_point`, `was_undone` |
| `people_list_publish_failed` | `list_id`, `operation`, `error_class` |
| `people_list_sheet_opened` | `entry_point` |
| `people_list_indicator_tapped` | `pubkey`, `membership_count` |

`entry_point` values: `other_profile_menu` · `followers_row` · `following_row` · `search_result` · `own_profile` · `list_people_screen` · `profile_indicator_chip`.

`error_class` is the runtime type name (`TimeoutException`, `RelayRejectedException`, …). No stack traces or user-visible messages sent to Firebase.

---

## Rules (blanket, apply to every surface in this feature)

- **Nostr IDs are never truncated.** Not in logs, not in `dart:developer` output, not in error messages, not in analytics params, not in debug widgets, not in error-class strings, not in screen-reader announcements. Full 64-char hex always. This is a project-wide rule and this spec inherits it.
- **No `Future.delayed()` in app code** for coordination. The 100 ms mutation-cleared timer is the only scheduled delay in this spec and it's a bloc-internal UI-state reset, not async coordination.
- **Dark-mode only, `VineTheme`, `DivineIcon`, `VineTheme` font methods.** No inline `TextStyle`, no raw `Colors.*`, no Material `Icon`.
- **`SemanticsService.announce` on every optimistic-success transition** ("Added @handle to *X*" / "Removed @handle from *X*"). Every interactive element has a tooltip.
- **All mutations through the BLoC.** UI never calls the repository directly; analytics never fires from widgets.

---

## Testing

**Repository tests** (`people_lists_repository` package): create / delete / addPubkey / removePubkey / setPubkeys. Assert publish format, tag order, d-tag immutability, `updated_at` monotonicity, local cache consistency, optimistic-revert on publish failure. Real `models` package; in-memory relay fake.

**BLoC tests** (`blocTest`): every event's pending → success and pending → failure → revert paths. Mutation-id clearing after 100 ms. Batch-set diffing emits correct per-pubkey analytics. Undo dispatches the correct event. Mock `FirebaseAnalytics` verifies event name + params for each success transition.

**Widget tests:**
- Sheet renders with empty state / one-list / many-lists
- Toggle dispatches the correct event with correct entry-point enum
- Pending spinner replaces checkbox
- Failure reverts the row and shows retry snackbar
- Undo snackbar dispatches undo event
- Inline new-list expand → create auto-checks the new list
- List-side picker: selection count drives "Add N" enablement; already-member rows are disabled
- `!isEditable` rows disabled in picker
- Feature flag off → all entry-point buttons hidden
- Semantics: every row has `toggled` state, every button has a tooltip, announce fires on success

**Goldens:** sheet empty / one-list / many-lists / row-pending / row-failure; full-screen picker empty / with-selection; profile indicator chip `N=1` and `N=5`.

**E2E (patrol)**: one end-to-end flow against the local Docker relay — open sheet → toggle into an existing list → reopen sheet from a different entry point → verify membership present → remove → verify gone. Asserts relay actually stored the event.

---

## i18n

All copy under `people_lists.*` in `AppLocalizations`. Keys include sheet title, new-list, empty-state body + CTA, member count, publish-failed retry, removed-undo, add-people title, already-a-member hint, in-N-lists chip template. No inline strings.

---

## Rollout

1. Ship the whole feature with `FF_CURATED_LISTS=true` by default so the profile, share, search, followers, and following entry points are visible without custom dart defines.
2. Keep `--dart-define=FF_CURATED_LISTS=false` available as the rollback path if product needs to hide both video add-to-list and people add-to-list together.
3. If product needs to split video add-to-list from people add-to-list later, introduce `FF_PEOPLE_LISTS` at that point, not before.

---

## Open questions (non-blocking)

- Should the flag-flip PR bundle video add-to-list and people add-to-list, or split? Product call.
- Long-term home for the Divine Team default — keep synthetic forever, or publish from a team pubkey later? Not needed for v1.
- Private/encrypted lists (NIP-04 content) — separate spec.

---

## Next step

Hand off to `superpowers:writing-plans` to produce the step-by-step implementation plan with TDD task breakdown.
