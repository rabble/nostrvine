# People Lists 3207 Integration Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Update PR #3244 after merged PR #3207 so kind `30000` people-list ownership is coherent, add-person flows work end to end, and the implementation stays BLoC-aligned.

**Architecture:** `people_lists_repository` owns NIP-51 kind `30000` parsing, relay search, local cache, and mutations. `CuratedListRepository` owns kind `30005` video lists only. `ListSearchBloc` composes both repositories for global search, while `AddPeopleToListCubit` owns the screen-local candidate picker state and delegates actual list mutations to the existing global `PeopleListsBloc`.

**Tech Stack:** Flutter, Dart, BLoC/Cubit, Riverpod providers for dependency wiring, GoRouter, Nostr kind `30000`/NIP-51, `people_lists_repository`, `curated_list_repository`, `follow_repository`, `profile_repository`, mocktail/bloc_test widget and unit tests.

---

## Specs

### Product Behavior

- Tapping add-person from an editable people-list detail screen opens a full-screen picker with candidate people, not an empty screen.
- Candidate people come from the authenticated user's network:
  - current following list from `FollowRepository.followingPubkeys` plus `followingStream`;
  - current followers from `FollowRepository.watchMyFollowers()`;
  - mutuals are derived from overlap and sorted first.
- The picker supports local text filtering over display name, handle, and full pubkey.
- Existing list members remain visible as selected/disabled rows unless a later product pass intentionally hides them.
- Tapping "Create list" from the add-to-list sheet creates a new list and adds the originally selected person in one step.
- Public people-list search from #3207 remains a search-results feature. It must not feed the add-person picker.
- Public people-list search result taps stay inert/TODO in this plan unless an owner-aware public detail route is added later.

### Domain Boundaries

- `PeopleListsRepository` owns kind `30000`.
- `CuratedListRepository` owns kind `30005`.
- `Nip51PeopleListCodec` is the source of truth for decoding and encoding kind `30000` events.
- Delete or retire #3207's `UserListConverter`; do not keep a second parser for kind `30000`.
- Public search must preserve the list owner pubkey. A `UserList.id`/`d` tag alone is not globally unique.
- Do not navigate public people-list search results to `/people-lists/:listId`, because that route is current-user scoped.

### BLoC Boundaries

- `PeopleListsBloc` owns durable authenticated-user list state and mutations.
- `AddPeopleToListCubit` owns only picker state:
  - loading/error status;
  - candidate source merging;
  - query filtering;
  - temporary selection.
- UI widgets render state and call callbacks. They should not directly watch follow/profile repositories.

### Route Rules

- `/people-lists/:listId/add-people` identifies the target current-user list only.
- `/people-lists/new` may accept `initialPubkey=<full hex pubkey>`.
- Query params must preserve full Nostr pubkeys and use URI encoding.
- Public list route design is out of scope. If added later, it needs owner identity, for example `/people-lists/:ownerPubkey/:listId` or an `naddr`-style route.

### Failure Handling

- If candidate loading fails, show a retryable picker error state without popping the route.
- If profile lookup fails for a candidate, keep the candidate row with deterministic fallback copy based on the full pubkey.
- If people-list public relay search fails, `ListSearchBloc` should surface failure the same way #3207 already intended.
- If `CreatePeopleListPage` is opened with an invalid/empty `initialPubkey`, create an empty list rather than throwing.

---

## File Map

### Repository Ownership And Search

- Modify: `mobile/packages/people_lists_repository/lib/src/people_lists_repository.dart`
  - Add public people-list search API.
- Modify: `mobile/packages/people_lists_repository/lib/src/people_lists_repository_impl.dart`
  - Move #3207's relay kind `30000` search here and decode via `Nip51PeopleListCodec`.
- Create: `mobile/packages/people_lists_repository/lib/src/people_list_search_result.dart`
  - Preserve `ownerPubkey`, decoded `UserList`, and addressable coordinate.
- Modify: `mobile/packages/people_lists_repository/lib/people_lists_repository.dart`
  - Export the new search result type.
- Modify: `mobile/packages/people_lists_repository/test/people_lists_repository_impl_test.dart`
  - Add public search tests.
- Modify: `mobile/packages/people_lists_repository/test/nip51_people_list_codec_test.dart`
  - Add coverage for `d=block`, `name` fallback if retained, UTC timestamps, empty pubkey filtering.
- Modify: `mobile/packages/curated_list_repository/lib/src/curated_list_repository.dart`
  - Remove `searchAllPeopleLists`.
- Delete: `mobile/packages/curated_list_repository/lib/src/user_list_converter.dart`
  - Replaced by `Nip51PeopleListCodec`.
- Modify: `mobile/packages/curated_list_repository/lib/curated_list_repository.dart`
  - Remove `UserListConverter` export if #3207 exported it.
- Modify: `mobile/packages/curated_list_repository/test/src/curated_list_repository_test.dart`
  - Remove people-list search tests.
- Delete: `mobile/packages/curated_list_repository/test/src/user_list_converter_test.dart`
  - Move relevant expectations to `people_lists_repository` codec/search tests.

### Global Search Integration

- Modify: `mobile/lib/blocs/list_search/list_search_bloc.dart`
  - Inject `PeopleListsRepository`.
  - Compose video-list search and people-list search.
- Modify: `mobile/lib/blocs/list_search/list_search_state.dart`
  - Change `peopleResults` from `List<UserList>` to `List<PeopleListSearchResult>`.
- Modify: `mobile/lib/screens/search_results/view/search_results_page.dart`
  - Pass `peopleListsRepositoryProvider` into `ListSearchBloc`.
- Modify: `mobile/lib/screens/search_results/widgets/lists_section.dart`
  - Render `PeopleListSearchCard(userList: result.list)`.
  - Keep public people-list result navigation disabled or TODO until owner-aware route exists.
- Modify: `mobile/test/blocs/list_search/list_search_bloc_test.dart`
  - Update mocks and assertions for `PeopleListsRepository`.
- Modify: `mobile/test/screens/search_results/widgets/lists_section_test.dart`
  - Update fixture type and verify no current-user route is pushed for public people-list cards.

### Add-People Picker

- Create: `mobile/lib/features/people_lists/bloc/add_people_to_list_cubit.dart`
  - Screen-scoped Cubit for candidate loading, filtering, and selection.
- Create: `mobile/lib/features/people_lists/bloc/add_people_to_list_state.dart`
  - Immutable state for status/query/candidates/selected pubkeys.
- Create: `mobile/lib/features/people_lists/models/people_list_candidate.dart`
  - Full pubkey plus optional profile labels and relationship flags.
- Modify: `mobile/lib/features/people_lists/people_lists.dart`
  - Export the new Cubit/state/model if feature exports are used by tests.
- Modify: `mobile/lib/features/people_lists/view/add_people_to_list_screen.dart`
  - Split Page/View if needed.
  - Provide `AddPeopleToListCubit` above the view.
  - Remove constructor-level `candidatePubkeys` as production input.
- Modify: `mobile/lib/features/people_lists/view/widgets/person_pickable_row.dart`
  - Accept candidate label/avatar data from `PeopleListCandidate`.
- Modify: `mobile/lib/router/app_router.dart`
  - Continue routing only by `listId`; no `extra` for candidate lists.
- Modify: `mobile/test/features/people_lists/view/add_people_to_list_screen_test.dart`
  - Test routed screen renders candidates from Cubit/repositories.
- Create: `mobile/test/features/people_lists/bloc/add_people_to_list_cubit_test.dart`
  - Test candidate merging, sorting, search, selection, retry, and profile fallback.

### Create-And-Add

- Modify: `mobile/lib/features/people_lists/view/add_to_people_lists_sheet.dart`
  - Empty state passes `pubkey` into create-list navigation.
  - Capture `GoRouter.of(context)` before popping the sheet.
- Modify: `mobile/lib/features/people_lists/view/create_people_list_page.dart`
  - Accept `initialPubkey`.
  - Dispatch `PeopleListsCreateRequested(initialPubkeys: [initialPubkey])` when present.
- Modify: `mobile/lib/router/app_router.dart`
  - Read `initialPubkey` from `/people-lists/new` query params.
- Modify: `mobile/test/features/people_lists/view/add_to_people_lists_sheet_test.dart`
  - Verify empty-state create button navigates with the full pubkey query param.
- Modify: `mobile/test/features/people_lists/view/create_people_list_page_test.dart`
  - Verify submit seeds the created list with `initialPubkey`.

### Legacy Riverpod Repair

- Modify: `mobile/lib/providers/list_providers.dart`
  - Watch `currentAuthStateProvider` in `userListsProvider` before reading `authService.currentPublicKeyHex`.
- Modify: `mobile/lib/providers/list_providers.g.dart`
  - Regenerate after provider source changes.
- Create or modify: `mobile/test/providers/list_providers_test.dart`
  - Verify login/account changes rebuild `userListsProvider`.

---

## Chunk 1: Merge Main And Resolve #3207 Conflicts

**Files:**
- Modify as needed: files conflicted by `origin/main` merge.
- Do not modify: `docs/superpowers/plans/2026-04-20-add-person-to-people-lists.md` unless explicitly carrying forward existing user edits.

- [ ] **Step 1: Confirm current worktree state**

Run:

```bash
git status --short --branch
```

Expected: only known pre-existing local changes plus this plan file if it is not committed yet.

- [ ] **Step 2: Fetch latest main**

Run:

```bash
git fetch origin main
```

Expected: fetch completes cleanly.

- [ ] **Step 3: Merge main into the PR branch**

Use merge rather than rebase because this PR branch already has merge commits and is open.

Run:

```bash
git merge --no-ff origin/main
```

Expected: likely conflicts around `ListSearchBloc`, `lists_section.dart`, `feature_flag.dart`, l10n, and repository files.

- [ ] **Step 4: Resolve conflicts by applying this ownership rule**

Keep #3207's UI/search feature behavior, but move kind `30000` ownership into `people_lists_repository`.

Expected conflict outcomes:

- `CuratedListRepository.searchAllLists` remains.
- `CuratedListRepository.searchAllPeopleLists` is removed.
- `Nip51PeopleListCodec` remains.
- `UserListConverter` is removed.
- `FeatureFlag.peopleListSearch` remains.
- `ListSearchBloc` gains both `CuratedListRepository` and `PeopleListsRepository`.

- [ ] **Step 5: Check merge result**

Run:

```bash
git status --short
git diff --check
```

Expected: no conflict markers and no whitespace errors.

- [ ] **Step 6: Commit merge**

Run:

```bash
git add <resolved files only>
git commit
```

Expected commit message: merge commit from Git unless policy prefers an explicit message.

---

## Chunk 2: Move Public People-List Search Into PeopleListsRepository

**Files:**
- Modify: `mobile/packages/people_lists_repository/lib/src/people_lists_repository.dart`
- Modify: `mobile/packages/people_lists_repository/lib/src/people_lists_repository_impl.dart`
- Create: `mobile/packages/people_lists_repository/lib/src/people_list_search_result.dart`
- Modify: `mobile/packages/people_lists_repository/lib/people_lists_repository.dart`
- Modify: `mobile/packages/people_lists_repository/test/people_lists_repository_impl_test.dart`
- Modify: `mobile/packages/people_lists_repository/test/nip51_people_list_codec_test.dart`
- Modify: `mobile/packages/curated_list_repository/lib/src/curated_list_repository.dart`
- Delete: `mobile/packages/curated_list_repository/lib/src/user_list_converter.dart`
- Delete: `mobile/packages/curated_list_repository/test/src/user_list_converter_test.dart`

- [ ] **Step 1: Write failing codec/search tests**

Add tests that require:

- `d=block` events are ignored.
- Empty lists are not returned from public search.
- Search matches name/title and description case-insensitively.
- Duplicate addressable events keep the newest event.
- Results preserve `ownerPubkey`.
- Two lists with the same `d` tag from different owners both survive.

Sketch:

```dart
test('searchPublicLists preserves owner pubkey and dedupes by addressable id', () async {
  final older = buildPeopleListEvent(
    ownerPubkey: ownerA,
    dTag: 'friends',
    title: 'Vine Friends',
    createdAt: 100,
    pubkeys: [memberA],
  );
  final newer = buildPeopleListEvent(
    ownerPubkey: ownerA,
    dTag: 'friends',
    title: 'Vine Friends',
    createdAt: 200,
    pubkeys: [memberB],
  );
  final otherOwner = buildPeopleListEvent(
    ownerPubkey: ownerB,
    dTag: 'friends',
    title: 'Vine Friends',
    createdAt: 150,
    pubkeys: [memberC],
  );
  when(() => nostrClient.queryEvents(any())).thenAnswer((_) async => [
    older,
    newer,
    otherOwner,
  ]);

  final results = await repository.searchPublicLists('vine').last;

  expect(results, hasLength(2));
  expect(results.map((r) => r.ownerPubkey), containsAll([ownerA, ownerB]));
  expect(
    results.firstWhere((r) => r.ownerPubkey == ownerA).list.pubkeys,
    equals([memberB]),
  );
});
```

- [ ] **Step 2: Run tests to verify they fail**

Run:

```bash
cd mobile/packages/people_lists_repository
flutter test test/nip51_people_list_codec_test.dart test/people_lists_repository_impl_test.dart
```

Expected: FAIL because `searchPublicLists` and `PeopleListSearchResult` do not exist yet.

- [ ] **Step 3: Add `PeopleListSearchResult`**

Create:

```dart
class PeopleListSearchResult extends Equatable {
  const PeopleListSearchResult({
    required this.ownerPubkey,
    required this.list,
  });

  final String ownerPubkey;
  final UserList list;

  String get addressableId =>
      '${Nip51PeopleListCodec.kind}:$ownerPubkey:${list.id}';

  @override
  List<Object?> get props => [ownerPubkey, list];
}
```

- [ ] **Step 4: Add repository interface method**

Add to `PeopleListsRepository`:

```dart
Stream<List<PeopleListSearchResult>> searchPublicLists(
  String query, {
  int limit = 50,
});
```

- [ ] **Step 5: Implement relay search in `PeopleListsRepositoryImpl`**

Implementation rules:

- Query `Filter(kinds: const [Nip51PeopleListCodec.kind], limit: limit)`.
- Decode with `Nip51PeopleListCodec.decode(event)`.
- Skip null decodes.
- Skip lists with no `pubkeys`.
- Match query against `list.name` and `list.description`.
- Deduplicate by addressable coordinate, not `list.id` alone.
- Keep newest `list.updatedAt`.
- Yield only when there are results, matching #3207 behavior.

- [ ] **Step 6: Remove kind `30000` parser/search from curated-list package**

Delete `UserListConverter` and its tests. Remove imports and methods from `CuratedListRepository`.

- [ ] **Step 7: Run package tests**

Run:

```bash
cd mobile/packages/people_lists_repository
flutter test
cd ../curated_list_repository
flutter test
```

Expected: PASS.

- [ ] **Step 8: Commit**

Run:

```bash
git add \
  mobile/packages/people_lists_repository/lib \
  mobile/packages/people_lists_repository/test \
  mobile/packages/curated_list_repository/lib \
  mobile/packages/curated_list_repository/test
git commit -m "refactor(people-lists): own public kind 30000 search"
```

---

## Chunk 3: Rewire ListSearchBloc To Compose Both Repositories

**Files:**
- Modify: `mobile/lib/blocs/list_search/list_search_bloc.dart`
- Modify: `mobile/lib/blocs/list_search/list_search_state.dart`
- Modify: `mobile/lib/screens/search_results/view/search_results_page.dart`
- Modify: `mobile/lib/screens/search_results/widgets/lists_section.dart`
- Modify: `mobile/test/blocs/list_search/list_search_bloc_test.dart`
- Modify: `mobile/test/screens/search_results/widgets/lists_section_test.dart`

- [ ] **Step 1: Write failing BLoC tests**

Update tests so `ListSearchBloc`:

- searches video lists through `CuratedListRepository.searchAllLists`;
- searches people lists through `PeopleListsRepository.searchPublicLists` only when `peopleListSearchEnabled` is true;
- emits `peopleResults` as `List<PeopleListSearchResult>`;
- surfaces failure when either stream throws.

- [ ] **Step 2: Run BLoC test to verify failure**

Run:

```bash
cd mobile
flutter test test/blocs/list_search/list_search_bloc_test.dart
```

Expected: FAIL because constructor/state still use the old #3207 shape or stale #3244 shape.

- [ ] **Step 3: Update `ListSearchState`**

Use:

```dart
final List<CuratedList> videoResults;
final List<PeopleListSearchResult> peopleResults;
```

Import `people_lists_repository`.

- [ ] **Step 4: Update `ListSearchBloc` constructor**

Use:

```dart
ListSearchBloc({
  required CuratedListRepository curatedListRepository,
  required PeopleListsRepository peopleListsRepository,
  bool peopleListSearchEnabled = false,
})
```

Store both repositories. Keep `Rx.merge` from #3207, but map people results from `PeopleListsRepository.searchPublicLists`.

- [ ] **Step 5: Update search page wiring**

In `SearchResultsPage`, read both repositories:

```dart
ListSearchBloc(
  curatedListRepository: ref.read(curatedListRepositoryProvider),
  peopleListsRepository: ref.read(peopleListsRepositoryProvider),
  peopleListSearchEnabled: ref.read(
    isFeatureEnabledProvider(FeatureFlag.peopleListSearch),
  ),
)
```

- [ ] **Step 6: Update lists section rendering**

Use `peopleResult.list` for the card:

```dart
PeopleListSearchCard(
  userList: peopleResult.list,
  onTap: () {
    // Intentionally disabled until public people-list routes include owner pubkey.
  },
)
```

Do not route to `/people-lists/:listId`.

- [ ] **Step 7: Run tests**

Run:

```bash
cd mobile
flutter test test/blocs/list_search/list_search_bloc_test.dart
flutter test test/screens/search_results/widgets/lists_section_test.dart
```

Expected: PASS.

- [ ] **Step 8: Commit**

Run:

```bash
git add \
  mobile/lib/blocs/list_search \
  mobile/lib/screens/search_results/view/search_results_page.dart \
  mobile/lib/screens/search_results/widgets/lists_section.dart \
  mobile/test/blocs/list_search/list_search_bloc_test.dart \
  mobile/test/screens/search_results/widgets/lists_section_test.dart
git commit -m "refactor(search): source people list results from repository"
```

---

## Chunk 4: Add Screen-Scoped AddPeopleToListCubit

**Files:**
- Create: `mobile/lib/features/people_lists/models/people_list_candidate.dart`
- Create: `mobile/lib/features/people_lists/bloc/add_people_to_list_cubit.dart`
- Create: `mobile/lib/features/people_lists/bloc/add_people_to_list_state.dart`
- Modify: `mobile/lib/features/people_lists/people_lists.dart`
- Create: `mobile/test/features/people_lists/bloc/add_people_to_list_cubit_test.dart`

- [ ] **Step 1: Write failing Cubit tests**

Test:

- following-only candidates render with `isFollowing=true`;
- follower-only candidates render with `isFollower=true`;
- mutuals sort before following-only and follower-only;
- search filters by display name, handle, and full pubkey;
- selected pubkeys toggle locally;
- existing members are marked `isAlreadyInList`;
- profile lookup failure keeps fallback labels.

Candidate fixture should use full 64-character pubkeys.

- [ ] **Step 2: Run tests to verify failure**

Run:

```bash
cd mobile
flutter test test/features/people_lists/bloc/add_people_to_list_cubit_test.dart
```

Expected: FAIL because files do not exist.

- [ ] **Step 3: Add candidate model**

Core fields:

```dart
class PeopleListCandidate extends Equatable {
  const PeopleListCandidate({
    required this.pubkey,
    this.displayName,
    this.handle,
    this.avatarUrl,
    this.isFollowing = false,
    this.isFollower = false,
    this.isAlreadyInList = false,
  });

  final String pubkey;
  final String? displayName;
  final String? handle;
  final String? avatarUrl;
  final bool isFollowing;
  final bool isFollower;
  final bool isAlreadyInList;

  bool get isMutual => isFollowing && isFollower;
}
```

- [ ] **Step 4: Add Cubit state**

Suggested fields:

```dart
enum AddPeopleToListStatus { initial, loading, ready, failure }

class AddPeopleToListState extends Equatable {
  const AddPeopleToListState({
    this.status = AddPeopleToListStatus.initial,
    this.query = '',
    this.candidates = const [],
    this.selectedPubkeys = const {},
  });
}
```

Expose `visibleCandidates` either as a getter or precomputed field. Keep filtering deterministic.

- [ ] **Step 5: Implement Cubit**

Constructor dependencies:

```dart
AddPeopleToListCubit({
  required FollowRepository followRepository,
  required ProfileRepository? profileRepository,
  required List<String> existingMemberPubkeys,
})
```

Methods:

- `Future<void> started()`
- `void queryChanged(String query)`
- `void candidateToggled(String pubkey)`
- `void retryRequested()`

Implementation notes:

- Seed following from `followRepository.followingPubkeys`.
- Listen to `followRepository.followingStream`.
- Listen to `followRepository.watchMyFollowers()`.
- Merge sets into one map keyed by full pubkey.
- For labels, prefer cached profile. Trigger fresh fetch for missing profiles without blocking the whole picker.
- Sort by mutual, following, follower, normalized label, full pubkey.

- [ ] **Step 6: Run tests**

Run:

```bash
cd mobile
flutter test test/features/people_lists/bloc/add_people_to_list_cubit_test.dart
```

Expected: PASS.

- [ ] **Step 7: Commit**

Run:

```bash
git add \
  mobile/lib/features/people_lists/models/people_list_candidate.dart \
  mobile/lib/features/people_lists/bloc/add_people_to_list_cubit.dart \
  mobile/lib/features/people_lists/bloc/add_people_to_list_state.dart \
  mobile/lib/features/people_lists/people_lists.dart \
  mobile/test/features/people_lists/bloc/add_people_to_list_cubit_test.dart
git commit -m "feat(people-lists): add people picker cubit"
```

---

## Chunk 5: Wire AddPeopleToListScreen To The Cubit

**Files:**
- Modify: `mobile/lib/features/people_lists/view/add_people_to_list_screen.dart`
- Modify: `mobile/lib/features/people_lists/view/widgets/person_pickable_row.dart`
- Modify: `mobile/lib/router/app_router.dart`
- Modify: `mobile/test/features/people_lists/view/add_people_to_list_screen_test.dart`
- Modify: `mobile/test/router/route_coverage_test.dart` if route expectations need updates.

- [ ] **Step 1: Write failing widget/router tests**

Add tests:

- routed `/people-lists/:listId/add-people` renders network candidates;
- empty candidate state only appears when follow/follower sources are empty;
- typing filters candidate rows;
- tapping candidates enables the submit button;
- submit dispatches one `PeopleListsPubkeyAddRequested` per selected pubkey.

- [ ] **Step 2: Run tests to verify failure**

Run:

```bash
cd mobile
flutter test test/features/people_lists/view/add_people_to_list_screen_test.dart
```

Expected: FAIL because the screen still defaults to empty `candidatePubkeys`.

- [ ] **Step 3: Refactor screen to Page/View**

Keep route constructor simple:

```dart
const AddPeopleToListScreen({required this.listId, super.key});
```

Make the Page layer a `ConsumerWidget` or `ConsumerStatefulWidget` so it can
read repository providers once and inject plain Dart dependencies into the
Cubit. Inside, select the target list from `PeopleListsBloc`, then provide:

```dart
final followRepository = ref.read(followRepositoryProvider);
final profileRepository = ref.read(profileRepositoryProvider);

BlocProvider(
  create: (_) => AddPeopleToListCubit(
    followRepository: followRepository,
    profileRepository: profileRepository,
    existingMemberPubkeys: userList.pubkeys,
  )..started(),
  child: AddPeopleToListView(userList: userList),
)
```

Keep Riverpod reads in the Page layer only. The View should consume Cubit state.

- [ ] **Step 4: Update UI states**

Render:

- loading indicator for `loading`;
- retryable error for `failure`;
- empty copy when ready and no candidates;
- `PersonPickableRow` list for visible candidates.

Existing members should be selected/disabled.

- [ ] **Step 5: Run widget tests**

Run:

```bash
cd mobile
flutter test test/features/people_lists/view/add_people_to_list_screen_test.dart
flutter test test/router/route_coverage_test.dart
```

Expected: PASS.

- [ ] **Step 6: Commit**

Run:

```bash
git add \
  mobile/lib/features/people_lists/view/add_people_to_list_screen.dart \
  mobile/lib/features/people_lists/view/widgets/person_pickable_row.dart \
  mobile/lib/router/app_router.dart \
  mobile/test/features/people_lists/view/add_people_to_list_screen_test.dart \
  mobile/test/router/route_coverage_test.dart
git commit -m "fix(people-lists): populate add people picker"
```

---

## Chunk 6: Make Create-And-Add One Step

**Files:**
- Modify: `mobile/lib/features/people_lists/view/add_to_people_lists_sheet.dart`
- Modify: `mobile/lib/features/people_lists/view/create_people_list_page.dart`
- Modify: `mobile/lib/router/app_router.dart`
- Modify: `mobile/test/features/people_lists/view/add_to_people_lists_sheet_test.dart`
- Modify: `mobile/test/features/people_lists/view/create_people_list_page_test.dart`
- Modify: `mobile/test/router/route_coverage_test.dart`

- [ ] **Step 1: Write failing tests**

Test that pressing "Create list" from the empty add-to-list sheet navigates to:

```text
/people-lists/new?initialPubkey=<full-hex-pubkey>
```

Test that submitting create dispatches:

```dart
PeopleListsCreateRequested(
  name: 'Close Friends',
  initialPubkeys: [targetPubkey],
)
```

- [ ] **Step 2: Run tests to verify failure**

Run:

```bash
cd mobile
flutter test test/features/people_lists/view/add_to_people_lists_sheet_test.dart
flutter test test/features/people_lists/view/create_people_list_page_test.dart
```

Expected: FAIL because the target pubkey is not threaded through.

- [ ] **Step 3: Update sheet empty state**

Pass `pubkey` into `_EmptyState`. Capture router before popping:

```dart
final router = GoRouter.of(context);
Navigator.of(context).pop();
router.push(CreatePeopleListPage.pathWithInitialPubkey(pubkey));
```

- [ ] **Step 4: Update create page**

Add:

```dart
const CreatePeopleListPage({this.initialPubkey, super.key});

final String? initialPubkey;

static String pathWithInitialPubkey(String pubkey) {
  return '$path?initialPubkey=${Uri.encodeQueryComponent(pubkey)}';
}
```

On submit:

```dart
final initialPubkeys = switch (widget.initialPubkey) {
  final value? when value.isNotEmpty => [value],
  _ => const <String>[],
};
context.read<PeopleListsBloc>().add(
  PeopleListsCreateRequested(
    name: name,
    initialPubkeys: initialPubkeys,
  ),
);
```

- [ ] **Step 5: Update router**

Read query param:

```dart
builder: (context, state) => CreatePeopleListPage(
  initialPubkey: state.uri.queryParameters['initialPubkey'],
),
```

- [ ] **Step 6: Run tests**

Run:

```bash
cd mobile
flutter test test/features/people_lists/view/add_to_people_lists_sheet_test.dart
flutter test test/features/people_lists/view/create_people_list_page_test.dart
flutter test test/router/route_coverage_test.dart
```

Expected: PASS.

- [ ] **Step 7: Commit**

Run:

```bash
git add \
  mobile/lib/features/people_lists/view/add_to_people_lists_sheet.dart \
  mobile/lib/features/people_lists/view/create_people_list_page.dart \
  mobile/lib/router/app_router.dart \
  mobile/test/features/people_lists/view/add_to_people_lists_sheet_test.dart \
  mobile/test/features/people_lists/view/create_people_list_page_test.dart \
  mobile/test/router/route_coverage_test.dart
git commit -m "fix(people-lists): create list with selected person"
```

---

## Chunk 7: Repair Auth Reactivity In Legacy Lists Provider

**Files:**
- Modify: `mobile/lib/providers/list_providers.dart`
- Modify: `mobile/lib/providers/list_providers.g.dart`
- Create or modify: `mobile/test/providers/list_providers_test.dart`

- [ ] **Step 1: Write failing provider test**

Test:

- when auth starts unauthenticated, `userListsProvider` emits empty;
- when `currentAuthStateProvider` changes and `authService.currentPublicKeyHex` becomes non-null, provider rebuilds and watches repository for that owner;
- when account changes, provider switches owner.

- [ ] **Step 2: Run test to verify failure**

Run:

```bash
cd mobile
flutter test test/providers/list_providers_test.dart
```

Expected: FAIL because `userListsProvider` does not watch `currentAuthStateProvider`.

- [ ] **Step 3: Add reactive auth watch**

In `userListsProvider`, before reading `currentPublicKeyHex`:

```dart
ref.watch(currentAuthStateProvider);
final ownerPubkey = ref.watch(authServiceProvider).currentPublicKeyHex;
```

- [ ] **Step 4: Regenerate Riverpod output**

Run:

```bash
cd mobile
dart run build_runner build --delete-conflicting-outputs
```

Expected: `mobile/lib/providers/list_providers.g.dart` hash updates if generator detects source changes.

- [ ] **Step 5: Run provider test**

Run:

```bash
cd mobile
flutter test test/providers/list_providers_test.dart
```

Expected: PASS.

- [ ] **Step 6: Commit**

Run:

```bash
git add \
  mobile/lib/providers/list_providers.dart \
  mobile/lib/providers/list_providers.g.dart \
  mobile/test/providers/list_providers_test.dart
git commit -m "fix(people-lists): react to auth changes in list provider"
```

---

## Chunk 8: Final Verification

**Files:**
- No new source files expected.
- Review all touched files before staging/pushing.

- [ ] **Step 1: Run focused package tests**

Run:

```bash
cd mobile/packages/people_lists_repository
flutter test
cd ../curated_list_repository
flutter test
```

Expected: PASS.

- [ ] **Step 2: Run focused app tests**

Run:

```bash
cd mobile
flutter test test/blocs/list_search/list_search_bloc_test.dart
flutter test test/screens/search_results/widgets/lists_section_test.dart
flutter test test/features/people_lists/bloc/people_lists_bloc_test.dart
flutter test test/features/people_lists/bloc/add_people_to_list_cubit_test.dart
flutter test test/features/people_lists/view/add_people_to_list_screen_test.dart
flutter test test/features/people_lists/view/add_to_people_lists_sheet_test.dart
flutter test test/features/people_lists/view/create_people_list_page_test.dart
flutter test test/router/route_coverage_test.dart
flutter test test/providers/list_providers_test.dart
```

Expected: PASS.

- [ ] **Step 3: Run analyze**

Run:

```bash
cd mobile
flutter analyze \
  lib/blocs/list_search \
  lib/features/people_lists \
  lib/providers/list_providers.dart \
  lib/router/app_router.dart \
  lib/screens/search_results \
  packages/people_lists_repository \
  packages/curated_list_repository \
  test/blocs/list_search/list_search_bloc_test.dart \
  test/features/people_lists \
  test/router/route_coverage_test.dart
```

Expected: no issues.

- [ ] **Step 4: Run broader changed-file suite**

Run:

```bash
cd mobile
flutter test \
  test/blocs/list_search/list_search_bloc_test.dart \
  test/screens/search_results/widgets/lists_section_test.dart \
  test/screens/user_list_people_screen_test.dart \
  test/widgets/share_video_menu_comprehensive_test.dart
```

Expected: PASS.

- [ ] **Step 5: Check generated files and dirty state**

Run:

```bash
git status --short
git diff --check
```

Expected: only intentional changes, no whitespace errors, no untracked scratch files.

- [ ] **Step 6: Push and inspect PR checks**

Run:

```bash
git push origin investigate/list-management
gh pr view 3244 --json statusCheckRollup,mergeStateStatus,url
```

Expected: checks start on pushed head. After they complete, all required checks pass or any failure is investigated before handoff.

---

## Notes For Implementer

- Do not use GoRouter `extra` for add-people candidate state. The route must be reloadable from URL alone.
- Do not truncate pubkeys in tests, logs, or state.
- Do not add arbitrary `Future.delayed()` calls. Use streams, fakeAsync, completers, or direct state emissions in tests.
- Do not route public search results to current-user list detail until owner identity is part of the route.
- If #3207 added l10n keys and this branch adds more, rerun the repo's l10n generation path already used in #3244 and commit generated localizations.
- Keep the pre-existing modified `docs/superpowers/plans/2026-04-20-add-person-to-people-lists.md` out of unrelated commits unless the user explicitly asks to update it.
