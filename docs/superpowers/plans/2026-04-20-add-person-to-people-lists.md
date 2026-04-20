# Add Person to People Lists — Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship "add person to people list" across every natural surface in the Divine app, backed by NIP-51 kind 30000 relay publishing, with analytics, all behind `FF_CURATED_LISTS`.

**Architecture:** New `PeopleListsRepository` package owns relay publish/subscribe + Hive cache for kind 30000. New `PeopleListsBloc` in `mobile/lib/features/people_lists/` owns optimistic mutations with a relay-echo merge rule and a reverse `listsByPubkey` index. UI: draggable bottom sheet for user-side picker, full-screen route for list-side picker, chip on profile header, entry points on profile menus, followers/following rows, and user search results. Feature-flag gate uses the existing `isFeatureEnabledProvider(FeatureFlag.curatedLists)`.

**Tech Stack:** Flutter, `flutter_bloc`, `bloc_concurrency`, `equatable`, `riverpod` (only to bridge the existing `userListsProvider`), `nostr_sdk`, `hive`, `firebase_analytics`, `go_router`. Project rules: `.claude/CLAUDE.md` + everything under `.claude/rules/`.

**Spec:** `docs/superpowers/specs/2026-04-20-add-person-to-people-lists-design.md` — the implementer should read the spec before starting.

---

## Prerequisites

- Running in an isolated worktree (use `superpowers:using-git-worktrees`). This plan was written in the `investigate/list-management` worktree; rename the branch to `feat/people-lists-management` before starting implementation, or create a fresh worktree.
- Pre-commit hooks installed (`cd mobile && mise run setup_hooks`). This is non-negotiable — the hooks run `dart format`, `flutter analyze`, and codegen verification on each commit.
- Feature flag stays **off** for the entirety of this plan's implementation. Do not flip `FF_CURATED_LISTS` in `build_configuration.dart:35`. That is a separate PR, out of scope here.
- The plan assumes TDD throughout. Every code-writing task is preceded by a failing test.

---

## File structure

### New files

```
mobile/packages/people_lists_repository/
  lib/
    people_lists_repository.dart                 # barrel
    src/
      people_lists_repository.dart               # abstract class
      people_lists_repository_impl.dart          # Nostr + cache impl
      local_people_lists_cache.dart              # Hive cache
      nip51_event_codec.dart                     # encode/decode kind 30000
      default_people_lists.dart                  # synthetic Divine Team list
  test/
    people_lists_repository_impl_test.dart
    local_people_lists_cache_test.dart
    nip51_event_codec_test.dart
  pubspec.yaml

mobile/lib/features/people_lists/
  people_lists.dart                              # feature barrel
  bloc/
    people_lists_bloc.dart                       # acts as barrel via part/part of
    people_lists_event.dart
    people_lists_state.dart
    mutation.dart                                # shared value type
    list_entry_point.dart                        # enum for analytics
  view/
    add_to_people_lists_sheet.dart               # user-side bottom sheet
    add_people_to_list_screen.dart               # list-side full-screen picker
    create_people_list_page.dart                 # full-screen create
    people_list_membership_indicator.dart        # "in N lists" chip
    widgets/
      people_list_row.dart                       # row in the sheet
      person_pickable_row.dart                   # row in the list-side picker
      widgets.dart                               # barrel

mobile/test/features/people_lists/
  bloc/
    people_lists_bloc_test.dart
    mutation_test.dart
  view/
    add_to_people_lists_sheet_test.dart
    add_people_to_list_screen_test.dart
    create_people_list_page_test.dart
    people_list_membership_indicator_test.dart
    widgets/
      people_list_row_test.dart
      person_pickable_row_test.dart

mobile/integration_test/
  people_lists_e2e_test.dart                     # patrol against local relay
```

### Modified files

```
mobile/lib/providers/list_providers.dart:18-21       # bridge userListsProvider onto PeopleListsBloc
mobile/lib/providers/app_providers.dart:1922-1925    # DELETE userListService provider
mobile/lib/services/user_list_service.dart           # DELETE the file
mobile/test/services/user_list_service_test.dart     # DELETE the file

mobile/lib/router/app_router.dart                    # add /lists/:id/add-people, /lists/new
mobile/lib/router/app_shell.dart                     # provide PeopleListsBloc at shell
mobile/lib/screens/user_list_people_screen.dart      # add "+ Add people" affordance, swipe-to-remove on member rows
mobile/lib/screens/other_profile_screen.dart         # "Add to list" menu item (verify actual filename)
mobile/lib/screens/profile_screen_router.dart        # own-profile menu entry
mobile/lib/widgets/profile/profile_header_widget.dart # mount PeopleListMembershipIndicator chip
mobile/lib/screens/followers/my_followers_screen.dart # trailing menu on each row
mobile/lib/screens/followers/others_followers_screen.dart # trailing menu on each row
mobile/lib/widgets/<user_search_result_tile>.dart    # trailing menu (locate exact file in Task 26)

mobile/lib/l10n/app_en.arb                           # new people_lists.* keys
mobile/lib/l10n/<other_locales>.arb                  # copy-in or mark TODO per project convention

mobile/pubspec.yaml                                  # add people_lists_repository path dep, bloc_concurrency if missing
```

### Deleted files

```
mobile/lib/services/user_list_service.dart
mobile/test/services/user_list_service_test.dart
```

---

## Chunk 1: Repository package

This chunk ships the `people_lists_repository` package standalone. It does not depend on anything in `mobile/lib/`, has no Flutter imports, and can be tested in isolation.

### Task 1: Scaffold the package

**Files:**
- Create: `mobile/packages/people_lists_repository/pubspec.yaml`
- Create: `mobile/packages/people_lists_repository/lib/people_lists_repository.dart`
- Create: `mobile/packages/people_lists_repository/analysis_options.yaml`

- [ ] **Step 1: Create pubspec.yaml**

Use `mobile/packages/curated_list_repository/pubspec.yaml` as the template (the package-layer reference pattern per the spec). Dependencies: `equatable`, `models` (path), `nostr_sdk` (path or version matching the curated one), `hive`, `shared_preferences`-free. Dev deps: `test`, `mocktail`, `very_good_analysis`.

```yaml
name: people_lists_repository
description: Nostr NIP-51 kind 30000 people-lists repository for Divine.
publish_to: none
environment:
  sdk: ^3.4.0
dependencies:
  equatable: ^2.0.5
  hive: ^2.2.3
  models:
    path: ../models
  nostr_sdk:
    path: ../nostr_sdk   # mirror whatever curated_list_repository uses
dev_dependencies:
  test: ^1.25.0
  mocktail: ^1.0.3
  very_good_analysis: ^6.0.0
```

Check the exact versions used by `packages/curated_list_repository/pubspec.yaml` and match them.

- [ ] **Step 2: Create analysis_options.yaml**

```yaml
include: package:very_good_analysis/analysis_options.yaml
```

- [ ] **Step 3: Create the empty barrel**

```dart
// mobile/packages/people_lists_repository/lib/people_lists_repository.dart

/// People lists repository.
///
/// Manages NIP-51 kind 30000 follow sets — create, read, update, delete,
/// with relay publish/subscribe and local cache.
library;

export 'src/people_lists_repository.dart';
```

- [ ] **Step 4: Run flutter pub get from mobile/ and verify**

Run: `cd mobile && flutter pub get`
Expected: no errors. The new package is discovered but not yet wired into `mobile/lib/`.

- [ ] **Step 5: Commit**

```bash
git add mobile/packages/people_lists_repository
git commit -m "feat(people_lists): scaffold repository package"
```

### Task 2: NIP-51 codec — encode

**Files:**
- Test: `mobile/packages/people_lists_repository/test/nip51_event_codec_test.dart`
- Create: `mobile/packages/people_lists_repository/lib/src/nip51_event_codec.dart`

- [ ] **Step 1: Write the failing test**

```dart
// test/nip51_event_codec_test.dart
import 'package:models/models.dart';
import 'package:people_lists_repository/src/nip51_event_codec.dart';
import 'package:test/test.dart';

void main() {
  group('Nip51EventCodec.encode', () {
    test('produces kind 30000 with correct tags for a minimal list', () {
      final list = UserList(
        id: 'punk-friends',
        name: 'Punk Friends',
        pubkeys: const [
          'npub1xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx0',
          'npub1yyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyy1',
        ],
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026, 4, 20),
      );

      final payload = Nip51EventCodec.encode(list);

      expect(payload.kind, equals(30000));
      expect(payload.content, equals(''));
      expect(payload.tags, containsAllInOrder([
        ['d', 'punk-friends'],
        ['title', 'Punk Friends'],
      ]));
      expect(
        payload.tags.where((t) => t[0] == 'p').map((t) => t[1]).toList(),
        equals(list.pubkeys),
      );
    });

    test('includes description and image tags when present', () {
      final list = UserList(
        id: 'id',
        name: 'n',
        description: 'the people',
        imageUrl: 'https://example.com/x.png',
        pubkeys: const [],
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
      );
      final payload = Nip51EventCodec.encode(list);
      expect(payload.tags, contains(['description', 'the people']));
      expect(payload.tags, contains(['image', 'https://example.com/x.png']));
    });

    test('omits description and image tags when null or empty', () {
      final list = UserList(
        id: 'id',
        name: 'n',
        pubkeys: const [],
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
      );
      final payload = Nip51EventCodec.encode(list);
      expect(payload.tags.any((t) => t[0] == 'description'), isFalse);
      expect(payload.tags.any((t) => t[0] == 'image'), isFalse);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd mobile/packages/people_lists_repository && dart test test/nip51_event_codec_test.dart`
Expected: FAIL — `Nip51EventCodec` not defined.

- [ ] **Step 3: Write minimal encode implementation**

```dart
// lib/src/nip51_event_codec.dart
import 'package:models/models.dart';

class UnsignedNostrPayload {
  const UnsignedNostrPayload({
    required this.kind,
    required this.tags,
    required this.content,
  });
  final int kind;
  final List<List<String>> tags;
  final String content;
}

abstract final class Nip51EventCodec {
  static const kind = 30000;

  static UnsignedNostrPayload encode(UserList list) {
    final tags = <List<String>>[
      ['d', list.id],
      ['title', list.name],
      if (list.description != null && list.description!.isNotEmpty)
        ['description', list.description!],
      if (list.imageUrl != null && list.imageUrl!.isNotEmpty)
        ['image', list.imageUrl!],
      for (final p in list.pubkeys) ['p', p],
    ];
    return UnsignedNostrPayload(kind: kind, tags: tags, content: '');
  }
}
```

- [ ] **Step 4: Run test — passes**

Run: `dart test test/nip51_event_codec_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add mobile/packages/people_lists_repository
git commit -m "feat(people_lists): Nip51EventCodec.encode for kind 30000"
```

### Task 3: NIP-51 codec — decode

**Files:**
- Modify test: `mobile/packages/people_lists_repository/test/nip51_event_codec_test.dart`
- Modify: `mobile/packages/people_lists_repository/lib/src/nip51_event_codec.dart`

- [ ] **Step 1: Add failing decode tests**

```dart
group('Nip51EventCodec.decode', () {
  test('decodes a well-formed kind 30000 event into UserList', () {
    final event = FakeNostrEvent(
      kind: 30000,
      pubkey: 'author-pubkey',
      id: 'event-id-32-bytes-hex',
      createdAt: DateTime.utc(2026, 4, 20).millisecondsSinceEpoch ~/ 1000,
      tags: const [
        ['d', 'punk-friends'],
        ['title', 'Punk Friends'],
        ['description', 'the people'],
        ['p', 'pub-a'],
        ['p', 'pub-b'],
      ],
      content: '',
    );

    final list = Nip51EventCodec.decode(event);

    expect(list.id, equals('punk-friends'));
    expect(list.name, equals('Punk Friends'));
    expect(list.description, equals('the people'));
    expect(list.pubkeys, equals(['pub-a', 'pub-b']));
    expect(list.nostrEventId, equals('event-id-32-bytes-hex'));
    expect(list.isEditable, isTrue);
  });

  test('throws FormatException when d tag is missing', () {
    final event = FakeNostrEvent(
      kind: 30000, pubkey: 'x', id: 'y',
      createdAt: 0, tags: const [['title', 'x']], content: '',
    );
    expect(() => Nip51EventCodec.decode(event), throwsFormatException);
  });

  test('ignores unknown tag kinds without error', () {
    final event = FakeNostrEvent(
      kind: 30000, pubkey: 'x', id: 'y', createdAt: 0,
      tags: const [['d', 'id'], ['title', 'n'], ['nonsense', 'v']],
      content: '',
    );
    final list = Nip51EventCodec.decode(event);
    expect(list.id, equals('id'));
  });
});
```

Define `FakeNostrEvent` in the test file implementing whatever event interface `nostr_sdk` exposes. Consult `packages/nostr_sdk/` for the actual type name.

- [ ] **Step 2: Run — fails**

Expected: decode not defined.

- [ ] **Step 3: Implement decode**

```dart
static UserList decode(NostrEvent event) {
  if (event.kind != kind) {
    throw FormatException('Expected kind $kind, got ${event.kind}');
  }
  String? d;
  String? title;
  String? description;
  String? image;
  final pubkeys = <String>[];
  for (final t in event.tags) {
    if (t.isEmpty) continue;
    switch (t[0]) {
      case 'd': d = t.length > 1 ? t[1] : null;
      case 'title': title = t.length > 1 ? t[1] : null;
      case 'description': description = t.length > 1 ? t[1] : null;
      case 'image': image = t.length > 1 ? t[1] : null;
      case 'p':
        if (t.length > 1) pubkeys.add(t[1]);
    }
  }
  if (d == null) throw const FormatException('Missing d tag');
  final createdAt = DateTime.fromMillisecondsSinceEpoch(
    event.createdAt * 1000, isUtc: true,
  );
  return UserList(
    id: d,
    name: title ?? d,
    description: description,
    imageUrl: image,
    pubkeys: pubkeys,
    createdAt: createdAt,
    updatedAt: createdAt,
    nostrEventId: event.id,
  );
}
```

- [ ] **Step 4: Run — passes**

- [ ] **Step 5: Commit**

```bash
git commit -am "feat(people_lists): Nip51EventCodec.decode"
```

### Task 4: Local cache (Hive)

**Files:**
- Test: `mobile/packages/people_lists_repository/test/local_people_lists_cache_test.dart`
- Create: `mobile/packages/people_lists_repository/lib/src/local_people_lists_cache.dart`

- [ ] **Step 1: Write failing tests**

Cover: open/close, put/get single, deleteByListId, getAll sorted by updatedAt desc, corrupted box handled gracefully (returns empty). Use `Hive.init` with a temp directory.

- [ ] **Step 2: Run — fails.**

- [ ] **Step 3: Implement `LocalPeopleListsCache`.** Serialize `UserList` via `toJson`/`fromJson` (already on the model). Store in a `Box<Map>` named `people_lists`. Key = `list.id`.

- [ ] **Step 4: Run — passes.**

- [ ] **Step 5: Commit.**

### Task 5: Repository interface

**Files:**
- Create: `mobile/packages/people_lists_repository/lib/src/people_lists_repository.dart`

- [ ] **Step 1: Write the interface**

```dart
// lib/src/people_lists_repository.dart
import 'package:models/models.dart';

abstract class PeopleListsRepository {
  Stream<List<UserList>> watchLists();
  Future<UserList> createList({required String name, String? description});
  Future<void> deleteList(String listId);
  Future<void> addPubkey(String listId, String pubkey);
  Future<void> removePubkey(String listId, String pubkey);
  Future<void> setPubkeys(String listId, Set<String> pubkeys);
}
```

No tests yet for the interface alone — it's a contract. The impl will be tested in Task 7.

- [ ] **Step 2: Commit**

```bash
git commit -am "feat(people_lists): repository interface"
```

### Task 6: Default lists source

**Files:**
- Test: `mobile/packages/people_lists_repository/test/default_people_lists_test.dart`
- Create: `mobile/packages/people_lists_repository/lib/src/default_people_lists.dart`

The Divine Team synthetic list lives here. Takes `List<String> teamPubkeys` as a constructor arg so tests can pass their own fixtures (no app-constant coupling in the package).

- [ ] **Step 1: Test it returns a non-editable list with the team pubkeys.**

- [ ] **Step 2: Run — fails.**

- [ ] **Step 3: Implement**

```dart
class DefaultPeopleLists {
  const DefaultPeopleLists({required this.teamPubkeys});
  final List<String> teamPubkeys;

  List<UserList> all() => [
    UserList(
      id: 'divine_team',
      name: 'Divine Team',
      description: 'Curated by the Divine team',
      pubkeys: teamPubkeys,
      createdAt: DateTime.utc(2024),
      updatedAt: DateTime.utc(2024),
      isEditable: false,
    ),
  ];
}
```

- [ ] **Step 4: Run — passes.**
- [ ] **Step 5: Commit.**

### Task 7: Repository implementation

**Files:**
- Test: `mobile/packages/people_lists_repository/test/people_lists_repository_impl_test.dart`
- Create: `mobile/packages/people_lists_repository/lib/src/people_lists_repository_impl.dart`

This is the biggest single file in the package. It wires `NostrClient`, `LocalPeopleLists Cache`, `Nip51EventCodec`, and `DefaultPeopleLists` together.

- [ ] **Step 1: Write tests (in this order, one at a time — TDD red/green for each)**

Test matrix (one test per bullet, each with its own red/green/commit cycle — treat each bullet as a sub-step):

1. `watchLists` emits default lists immediately when cache is empty and no relay events arrive.
2. `watchLists` emits cached owned lists + defaults on first subscribe.
3. `watchLists` emits updated lists when a new kind-30000 event arrives on the subscription.
4. `createList` signs and publishes a kind-30000 event, writes to cache, and the stream emits the new list.
5. `createList` throws when relay rejects (`OK: false, reason="..."`) and does not write to cache.
6. `deleteList` publishes a kind-5 deletion event referencing `<pubkey>:30000:<d>`, removes from cache, stream reflects the removal.
7. `addPubkey` appends the pubkey, publishes an updated replaceable event, stream emits the new member set.
8. `addPubkey` is idempotent — calling twice with the same pubkey publishes only once.
9. `removePubkey` removes the pubkey and publishes.
10. `setPubkeys` replaces the member set in a single publish.
11. `setPubkeys` with no diff (incoming set equals current members) does not publish — short-circuit.
12. Default (`isEditable: false`) lists cannot be mutated — attempting `addPubkey('divine_team', ...)` throws `UnsupportedError`.
13. `updatedAt` on published events is monotonic — publishing twice in rapid succession produces strictly increasing timestamps even if the wall clock is flat (use `max(DateTime.now(), last.updatedAt + 1ms)`).

- [ ] **Step 2: Implement the class, making each test pass one at a time, committing after each.**

Skeleton:

```dart
class PeopleListsRepositoryImpl implements PeopleListsRepository {
  PeopleListsRepositoryImpl({
    required NostrClient nostrClient,
    required LocalPeopleListsCache cache,
    required DefaultPeopleLists defaults,
    required String ownerPubkey,
    required Future<NostrEvent> Function(UnsignedNostrPayload) signer,
    Clock? clock,
  })  : _client = nostrClient,
        _cache = cache,
        _defaults = defaults,
        _ownerPubkey = ownerPubkey,
        _signer = signer,
        _clock = clock ?? const Clock();

  // ... subscribe on first listen, merge cache + incoming events,
  //     emit merged+default lists sorted (defaults first, then by updatedAt desc).
  //     Mutations publish → wait for OK → update cache → emit.
}
```

Do **not** implement unrelated optimizations. Make the tests pass.

- [ ] **Step 3: Commit after each test-implement pair.**

### Task 8: Export the public API

**Files:**
- Modify: `mobile/packages/people_lists_repository/lib/people_lists_repository.dart`

- [ ] **Step 1:** Export the interface, impl, codec types, default lists source, cache. Barrel hygiene only — no code change to internals.

- [ ] **Step 2: Run `dart analyze` in the package — clean.**

- [ ] **Step 3: Commit.**

---

## Chunk 1 review

**Dispatch `plan-document-reviewer` subagent with Chunk 1 content and the spec path. Apply any Issues-Found feedback and re-dispatch until Approved before moving to Chunk 2.**

---

## Chunk 2: BLoC

### Task 9: Mutation value type

**Files:**
- Test: `mobile/test/features/people_lists/bloc/mutation_test.dart`
- Create: `mobile/lib/features/people_lists/bloc/mutation.dart`

- [ ] **Step 1: Write tests** — Equatable equality; `copyWith(status:)`; each `MutationKind` round-trips.

- [ ] **Step 2: Run — fails.**

- [ ] **Step 3: Implement**

```dart
import 'package:equatable/equatable.dart';

enum MutationKind { create, delete, toggleAdd, toggleRemove, batchSet }
enum MutationStatus { pending, success, failure }

class Mutation extends Equatable {
  const Mutation({
    required this.mutationId,
    required this.kind,
    required this.status,
    this.listId,
    this.pubkey,
  });

  final String mutationId;
  final MutationKind kind;
  final MutationStatus status;
  final String? listId;
  final String? pubkey;

  Mutation copyWith({MutationStatus? status}) => Mutation(
    mutationId: mutationId, kind: kind, listId: listId, pubkey: pubkey,
    status: status ?? this.status,
  );

  @override
  List<Object?> get props => [mutationId, kind, status, listId, pubkey];
}
```

- [ ] **Step 4: Run — passes.**
- [ ] **Step 5: Commit.**

### Task 10: ListEntryPoint enum

**Files:**
- Create: `mobile/lib/features/people_lists/bloc/list_entry_point.dart`

No test needed for an enum-only file. Implement directly.

```dart
enum ListEntryPoint {
  otherProfileMenu('other_profile_menu'),
  followersRow('followers_row'),
  followingRow('following_row'),
  searchResult('search_result'),
  ownProfile('own_profile'),
  listPeopleScreen('list_people_screen'),
  profileIndicatorChip('profile_indicator_chip');

  const ListEntryPoint(this.analyticsValue);
  final String analyticsValue;
}
```

- [ ] Commit.

### Task 11: State class

**Files:**
- Test: `mobile/test/features/people_lists/bloc/people_lists_bloc_test.dart` (state section)
- Create: `mobile/lib/features/people_lists/bloc/people_lists_state.dart`

State carries `status`, `lists`, `pendingMutations`, `listsByPubkey`. Helpers `isMember`, `listCountContaining`, `mutationsForRow`.

- [ ] **Step 1: Write tests** — initial values; `copyWith` with `lists` rebuilds the reverse index; `isMember` / `listCountContaining` correct; Equatable.

- [ ] **Step 2: Run — fails.**

- [ ] **Step 3: Implement**

```dart
part of 'people_lists_bloc.dart';

enum PeopleListsStatus { initial, loading, ready, failure }

class PeopleListsState extends Equatable {
  PeopleListsState({
    this.status = PeopleListsStatus.initial,
    this.lists = const [],
    this.pendingMutations = const {},
  }) : listsByPubkey = _buildIndex(lists);

  const PeopleListsState._({
    required this.status,
    required this.lists,
    required this.pendingMutations,
    required this.listsByPubkey,
  });

  final PeopleListsStatus status;
  final List<UserList> lists;
  final Map<String, Mutation> pendingMutations;
  final Map<String, Set<String>> listsByPubkey;

  bool isMember(String listId, String pubkey) =>
      listsByPubkey[pubkey]?.contains(listId) ?? false;

  int listCountContaining(String pubkey) =>
      listsByPubkey[pubkey]?.length ?? 0;

  Iterable<Mutation> mutationsForRow(String listId, String pubkey) =>
      pendingMutations.values.where(
        (m) => m.listId == listId && m.pubkey == pubkey,
      );

  PeopleListsState copyWith({
    PeopleListsStatus? status,
    List<UserList>? lists,
    Map<String, Mutation>? pendingMutations,
  }) => PeopleListsState._(
    status: status ?? this.status,
    lists: lists ?? this.lists,
    pendingMutations: pendingMutations ?? this.pendingMutations,
    listsByPubkey:
        lists == null ? listsByPubkey : _buildIndex(lists),
  );

  static Map<String, Set<String>> _buildIndex(List<UserList> lists) {
    final idx = <String, Set<String>>{};
    for (final l in lists) {
      for (final p in l.pubkeys) {
        (idx[p] ??= <String>{}).add(l.id);
      }
    }
    return idx;
  }

  @override
  List<Object?> get props => [status, lists, pendingMutations];
}
```

- [ ] **Step 4: Run — passes. Commit.**

### Task 12: Events

**Files:**
- Create: `mobile/lib/features/people_lists/bloc/people_lists_event.dart`

Direct implementation (mostly mechanical):

```dart
part of 'people_lists_bloc.dart';

sealed class PeopleListsEvent extends Equatable {
  const PeopleListsEvent();
  @override List<Object?> get props => [];
}

class PeopleListsSubscribed extends PeopleListsEvent {
  const PeopleListsSubscribed();
}
class PeopleListCreated extends PeopleListsEvent {
  const PeopleListCreated({required this.name, this.description, required this.entryPoint});
  final String name;
  final String? description;
  final ListEntryPoint entryPoint;
  @override List<Object?> get props => [name, description, entryPoint];
}
class PeopleListDeleted extends PeopleListsEvent { /* listId */ }
class PeopleListMembershipToggled extends PeopleListsEvent {
  /* listId, pubkey, entryPoint */
}
class PeopleListMembersSet extends PeopleListsEvent {
  /* listId, Set<String> pubkeys, entryPoint */
}
class PeopleListMutationCleared extends PeopleListsEvent { /* mutationId */ }
class PeopleListMembershipUndone extends PeopleListsEvent {
  /* listId, pubkey, originalEntryPoint */
}

// Internal events used only by the BLoC to process the stream:
class _RepositoryListsReceived extends PeopleListsEvent { /* List<UserList> */ }
class _RepositoryStreamFailed extends PeopleListsEvent { /* Object error */ }
```

- [ ] Write tests for Equatable equality of each event. Commit.

### Task 13: BLoC skeleton + subscribed event

**Files:**
- Modify: `mobile/test/features/people_lists/bloc/people_lists_bloc_test.dart`
- Create: `mobile/lib/features/people_lists/bloc/people_lists_bloc.dart`

- [ ] **Step 1: Write tests**

```dart
blocTest<PeopleListsBloc, PeopleListsState>(
  'emits [loading, ready] with repository lists on subscribe',
  setUp: () {
    when(repo.watchLists).thenAnswer(
      (_) => Stream.value([_list('a'), _list('b')]),
    );
  },
  build: () => PeopleListsBloc(repository: repo, analytics: analytics),
  act: (b) => b.add(const PeopleListsSubscribed()),
  expect: () => [
    isA<PeopleListsState>().having((s) => s.status, 'status', PeopleListsStatus.loading),
    isA<PeopleListsState>()
      .having((s) => s.status, 'status', PeopleListsStatus.ready)
      .having((s) => s.lists.length, 'lists', 2),
  ],
);
```

- [ ] **Step 2: Run — fails.**

- [ ] **Step 3: Implement**

```dart
// people_lists_bloc.dart
import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:models/models.dart';
import 'package:people_lists_repository/people_lists_repository.dart';

import 'list_entry_point.dart';
import 'mutation.dart';

part 'people_lists_event.dart';
part 'people_lists_state.dart';

class PeopleListsBloc extends Bloc<PeopleListsEvent, PeopleListsState> {
  PeopleListsBloc({
    required PeopleListsRepository repository,
    required FirebaseAnalytics analytics,
    String Function()? mutationIdFactory,
  })  : _repo = repository,
        _analytics = analytics,
        _newId = mutationIdFactory ?? _defaultIdFactory,
        super(PeopleListsState()) {
    on<PeopleListsSubscribed>(_onSubscribed);
    on<_RepositoryListsReceived>(_onRepoLists);
    on<_RepositoryStreamFailed>(_onRepoFailed);
    // ... mutation handlers registered in later tasks
  }

  final PeopleListsRepository _repo;
  final FirebaseAnalytics _analytics;
  final String Function() _newId;
  StreamSubscription<List<UserList>>? _sub;

  Future<void> _onSubscribed(
    PeopleListsSubscribed event,
    Emitter<PeopleListsState> emit,
  ) async {
    emit(state.copyWith(status: PeopleListsStatus.loading));
    await _sub?.cancel();
    _sub = _repo.watchLists().listen(
      (lists) => add(_RepositoryListsReceived(lists)),
      onError: (e, _) => add(_RepositoryStreamFailed(e)),
    );
  }

  void _onRepoLists(
    _RepositoryListsReceived event,
    Emitter<PeopleListsState> emit,
  ) {
    // Apply relay-echo merge rule: pending mutations override relay state.
    emit(state.copyWith(
      status: PeopleListsStatus.ready,
      lists: _applyPendingOverlay(event.lists, state.pendingMutations),
    ));
  }

  void _onRepoFailed(
    _RepositoryStreamFailed event,
    Emitter<PeopleListsState> emit,
  ) {
    addError(event.error, StackTrace.current);
    emit(state.copyWith(status: PeopleListsStatus.failure));
  }

  @override
  Future<void> close() {
    _sub?.cancel();
    return super.close();
  }
}

String _defaultIdFactory() => DateTime.now().microsecondsSinceEpoch.toString();
```

- [ ] **Step 4: Run — passes. Commit.**

### Task 14: Relay-echo overlay helper

**Files:**
- Modify BLoC file and test.

- [ ] **Step 1: Unit-test `_applyPendingOverlay`** (extract it as a top-level private function to make it testable):
  - No pending → returns input unchanged.
  - Pending `toggleAdd(listId, pubkey)` → output has `pubkey` in `listId.pubkeys` even if incoming stream doesn't.
  - Pending `toggleRemove(listId, pubkey)` → output has `pubkey` absent even if incoming stream contains it.
  - Pending `batchSet(listId, pubkeys)` → output's `listId.pubkeys` equals the optimistic set.
  - `failure` mutations no longer override (they've been reverted upstream).

- [ ] **Step 2: Run — fails.**
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run — passes. Commit.**

### Task 15: Toggle membership handler

**Files:**
- Modify BLoC + test.

- [ ] **Step 1: Tests (each own TDD cycle, commit each)**

1. `PeopleListMembershipToggled(add)` — pending mutation appears in state, list reflects pubkey added optimistically.
2. Repo `addPubkey` succeeds → mutation becomes `success` → `people_list_member_added` analytics fires with `list_id`, `pubkey`, `entry_point`.
3. Repo `addPubkey` throws → mutation becomes `failure`, list reverts, `addError` called, `people_list_publish_failed` analytics fires.
4. `PeopleListMembershipToggled(remove)` mirrors symmetrically, fires `people_list_member_removed` with `was_undone=false`.
5. Transformer `sequential` — two rapid toggles on same `(listId, pubkey)` serialize (inject a slow repo to observe order).

- [ ] **Step 2: Implement the handler with `sequential()` transformer.**

```dart
on<PeopleListMembershipToggled>(
  _onToggle,
  transformer: sequential(),
);

Future<void> _onToggle(
  PeopleListMembershipToggled event,
  Emitter<PeopleListsState> emit,
) async {
  final currentlyMember = state.isMember(event.listId, event.pubkey);
  final kind = currentlyMember ? MutationKind.toggleRemove : MutationKind.toggleAdd;
  final mutationId = _newId();
  final mutation = Mutation(
    mutationId: mutationId, kind: kind, status: MutationStatus.pending,
    listId: event.listId, pubkey: event.pubkey,
  );
  // Optimistic update + pending mutation.
  emit(_withMutation(mutation, apply: true));

  try {
    if (currentlyMember) {
      await _repo.removePubkey(event.listId, event.pubkey);
    } else {
      await _repo.addPubkey(event.listId, event.pubkey);
    }
    await _analytics.logEvent(
      name: currentlyMember ? 'people_list_member_removed' : 'people_list_member_added',
      parameters: {
        'list_id': event.listId,
        'pubkey': event.pubkey,
        'entry_point': event.entryPoint.analyticsValue,
        if (currentlyMember) 'was_undone': false,
      },
    );
    emit(_markMutation(mutationId, MutationStatus.success));
    _scheduleClear(mutationId);
  } catch (e, st) {
    addError(e, st);
    await _analytics.logEvent(
      name: 'people_list_publish_failed',
      parameters: {
        'list_id': event.listId,
        'operation': currentlyMember ? 'remove' : 'add',
        'error_class': e.runtimeType.toString(),
      },
    );
    emit(_withMutation(mutation.copyWith(status: MutationStatus.failure), apply: false, revert: true));
  }
}
```

Helpers `_withMutation`, `_markMutation`, `_scheduleClear` are small private methods — implement alongside.

- [ ] **Step 3: Run — each test passes. Commit after each.**

### Task 16: Create / Delete / BatchSet / Undo / Cleared

Same shape as Task 15 — one handler per event, TDD, commit per test-green.

- [ ] **Task 16a: `PeopleListCreated`**
  - Transformer: `droppable()`.
  - On success: `people_list_created` analytics with `list_id`, `has_description`.
  - On failure: `people_list_publish_failed` with `operation: 'create'`.
  - Optimistically inserts a placeholder list with a temp id while pending.

- [ ] **Task 16b: `PeopleListDeleted`**
  - Pre-capture `member_count` for analytics.
  - Default lists throw → emit mutation `failure` without calling repo.
  - On success: `people_list_deleted` with `list_id`, `member_count`.

- [ ] **Task 16c: `PeopleListMembersSet`**
  - Transformer: `sequential()`.
  - Diff against current members.
  - Per-pubkey analytics for each added and each removed in the diff.
  - Short-circuit: empty diff → no-op, no publish, no events.

- [ ] **Task 16d: `PeopleListMembershipUndone`**
  - Inverse of the last toggle. Re-dispatches an internal toggle but tags analytics with `was_undone: true`.

- [ ] **Task 16e: `PeopleListMutationCleared`**
  - Removes the mutation from the map after the 100 ms timer set by `_scheduleClear`.

### Task 17: Feature barrel + provider wiring

**Files:**
- Create: `mobile/lib/features/people_lists/people_lists.dart`
- Modify: `mobile/lib/router/app_shell.dart` (or wherever top-level providers mount)

- [ ] **Step 1: Barrel**

```dart
export 'bloc/people_lists_bloc.dart';
export 'bloc/list_entry_point.dart';
// view/ barrel added in Chunk 3
```

- [ ] **Step 2: Provide `PeopleListsBloc` at the shell** — via `MultiBlocProvider`, alongside other app-shell blocs. Construct with `PeopleListsRepositoryImpl`, `FirebaseAnalytics.instance`, `AppConstants.divineTeamPubkeys`, and the signer from `NostrClient`. Dispatch `PeopleListsSubscribed` on create.

- [ ] **Step 3: Unit-test the wiring** via a widget test that pumps the shell with a mocked repo and asserts the bloc is provided.

- [ ] **Step 4: Commit.**

### Task 18: Bridge `userListsProvider`

**Files:**
- Modify: `mobile/lib/providers/list_providers.dart:16-21`
- Delete: `mobile/lib/services/user_list_service.dart`
- Delete: `mobile/test/services/user_list_service_test.dart`
- Modify: `mobile/lib/providers/app_providers.dart:1922-1925`

- [ ] **Step 1: Rewrite `userListsProvider`** to read from the `PeopleListsBloc` via a `BlocProvider`-backed bridge. Easiest pattern: a new `people_lists_stream_provider` that exposes the bloc's state stream into Riverpod, and `userListsProvider` derives `state.lists` from that. Look at existing bridge patterns in the repo if any.

- [ ] **Step 2: Delete `UserListService` and its provider + test.** `git rm` the files.

- [ ] **Step 3: Run `flutter analyze`** — expect zero unresolved references. Fix imports in `explore_screen.dart`, `user_list_people_screen.dart`, and `list_providers.g.dart` (rerun codegen).

- [ ] **Step 4: Run `dart run build_runner build --delete-conflicting-outputs`** and commit generated files.

- [ ] **Step 5: Widget-test** that the Explore "People Lists" section still renders the Divine Team list (now sourced via the new bloc).

- [ ] **Step 6: Commit.**

---

## Chunk 2 review

**Dispatch `plan-document-reviewer` subagent. Apply issues, re-dispatch, until Approved.**

---

## Chunk 3: UI components

All UI tasks: TDD widget tests first, then goldens where noted, then implementation. Follow `rules/ui_theming.md`, `rules/accessibility.md`, `rules/code_style.md`. No `Future.delayed`, no inline `TextStyle`, no `Colors.*`, no methods returning widgets.

### Task 19: `PeopleListRow` widget

Row used inside the user-side sheet: checkbox · list name · "N people" · lock icon (when `!isEditable`).

**Files:**
- Test: `mobile/test/features/people_lists/view/widgets/people_list_row_test.dart`
- Create: `mobile/lib/features/people_lists/view/widgets/people_list_row.dart`

- [ ] **Step 1: Tests**
  - Renders list name and member count.
  - Checkbox reflects `isChecked`.
  - Tap → emits `PeopleListMembershipToggled` via provided `PeopleListsBloc` mock with the correct `entryPoint`.
  - When `mutationStatus == pending`, spinner replaces checkbox.
  - When `!isEditable`, row is disabled (no gesture) and shows lock icon.
  - Semantics: `toggled` = `isChecked`; announces "Added to X" after tap success.

- [ ] **Step 2: Implement** with `DivineIcon`, `VineTheme` font methods, `ConstrainedBox(minHeight: 48)`, `MergeSemantics`, `HapticFeedback.selectionClick`.

- [ ] **Step 3: Goldens** — default · checked · pending · disabled/lock — tagged `golden`.

- [ ] **Step 4: Commit.**

### Task 20: `AddToPeopleListsSheet`

**Files:**
- Test: `mobile/test/features/people_lists/view/add_to_people_lists_sheet_test.dart`
- Create: `mobile/lib/features/people_lists/view/add_to_people_lists_sheet.dart`

Draggable bottom sheet; builds rows via `PeopleListRow`; handles inline "+ New list" expand → TextField → create → auto-check; empty state with CTA.

- [ ] **Step 1: Tests** (each its own TDD cycle)
  - Sheet renders all owned lists + defaults.
  - Tapping a row dispatches toggle with the sheet's `entryPoint`.
  - "+ New list" row expands inline, Enter submits create, new list appears at top and is auto-checked.
  - Empty state (zero owned lists) shows illustration + primary "Create your first list" → opens inline create input.
  - `failure` mutation shows retry snackbar.
  - Closing the sheet while a pending mutation is in flight does not cancel it.
  - Announces "Added @handle to X" on row tap success.

- [ ] **Step 2: Implement.** Use `showModalBottomSheet` with `DraggableScrollableSheet`. Keep the sheet itself under ~150 lines; extract `_EmptyState`, `_CreateListInline`, `_ListRows` as private widgets per `code_style.md`. No methods returning widgets.

- [ ] **Step 3: Goldens** — empty · one-list · many-lists · row-pending · row-failure — tagged `golden`.

- [ ] **Step 4: Public entry point:**

```dart
Future<void> showAddToPeopleListsSheet({
  required BuildContext context,
  required String pubkey,
  required String handle,
  required ListEntryPoint entryPoint,
});
```

- [ ] **Step 5: Commit.**

### Task 21: `PersonPickableRow`

Row used in the list-side full-screen picker: avatar · name · handle · circular checkbox (or disabled + fixed check if already a member).

- [ ] TDD: render, select toggles a local `ValueNotifier<bool>`, disabled state, avatar respects `VineCachedImage`. Goldens default · selected · already-member.

- [ ] Commit.

### Task 22: `AddPeopleToListScreen`

**Files:**
- Test: `mobile/test/features/people_lists/view/add_people_to_list_screen_test.dart`
- Create: `mobile/lib/features/people_lists/view/add_people_to_list_screen.dart`

Full-screen route at `/lists/:id/add-people`. Segmented control Following/Followers/Search, persistent search bar, pinned "Add N" button, batch commit → `PeopleListMembersSet`.

- [ ] **Step 1: Tests**
  - Renders three segments; switching segments reloads the data source.
  - Already-members are disabled with a check.
  - Tapping a row toggles selection in local state.
  - Selection count drives "Add N" label and enablement.
  - "Add N" tap dispatches batch event with union of current members + selected.
  - On success, pops route.
  - On failure, stays on screen with retry snackbar.
  - Search input debounces and queries the search provider.

- [ ] **Step 2: Implement** as a `StatefulWidget` holding `Set<String> _selected`. Segmented control from `divine_ui` if available, else `CupertinoSlidingSegmentedControl`. Use `SliverAppBar` with the search bar pinned.

- [ ] **Step 3: Goldens** — empty segment · with selection · already-member state.

- [ ] **Step 4: Wire the route** in `app_router.dart` with a typed `GoRouteData`.

- [ ] **Step 5: Commit.**

### Task 23: `CreatePeopleListPage`

Full-screen page for the "big" create flow (name + description + public toggle disabled-with-tooltip). Reachable from the Lists tab header.

- [ ] TDD: name-required validation; empty description allowed; public/private toggle disabled with tooltip "Coming soon"; Save dispatches `PeopleListCreated`.

- [ ] Route `/lists/new` in `app_router.dart`.

- [ ] Goldens: fresh · with-input · saving.

- [ ] Commit.

### Task 24: `PeopleListMembershipIndicator` chip

**Files:**
- Test: `mobile/test/features/people_lists/view/people_list_membership_indicator_test.dart`
- Create: `mobile/lib/features/people_lists/view/people_list_membership_indicator.dart`

- [ ] Tests:
  - `N == 0` → renders `SizedBox.shrink`.
  - `N > 0` → renders chip showing "In N of your lists" (pluralized via i18n).
  - Tap → opens `AddToPeopleListsSheet` with `entryPoint: profileIndicatorChip` and fires `people_list_indicator_tapped` analytics.

- [ ] Implement with `BlocSelector<PeopleListsBloc, PeopleListsState, int>` selecting only the count for this `pubkey` — keeps rebuilds scoped.

- [ ] Commit.

### Task 25: View barrel

- [ ] Export all view widgets from `mobile/lib/features/people_lists/view/widgets/widgets.dart` and from `features/people_lists/people_lists.dart`. Run `flutter analyze`. Commit.

---

## Chunk 3 review

**Dispatch `plan-document-reviewer`. Apply, re-dispatch, until Approved.**

---

## Chunk 4: Entry-point wiring

Each entry point is a small, focused commit. Every single one is wrapped in `ref.watch(isFeatureEnabledProvider(FeatureFlag.curatedLists))`. All dispatch through the new public `showAddToPeopleListsSheet` helper with the correct `ListEntryPoint`.

### Task 26: Other-user profile three-dot

- [ ] Locate the three-dot menu on `other_profile_screen.dart` (grep for `showModalBottomSheet` + `PopupMenu` in profile files; confirm exact filename).
- [ ] Add an "Add to list" menu item guarded by the flag.
- [ ] Widget test: flag off → absent; flag on → visible; tap → `showAddToPeopleListsSheet` called with `otherProfileMenu`.
- [ ] Commit.

### Task 27: Followers row (`my_followers_screen.dart`)

- [ ] Add trailing `PopupMenuButton` to each row (or `InkWell`-wrapped icon with a menu on tap). Feature-flag guard.
- [ ] Widget test + semantic label + 48×48 tap target.
- [ ] Commit.

### Task 28: Following row / others followers (`others_followers_screen.dart`)

- [ ] Same as Task 27.
- [ ] Commit.

### Task 29: User search result row

- [ ] Locate the user search result row widget (task note: the exact file is TBD — grep for `find.byType(UserSearchResultTile)` or similar).
- [ ] Add the trailing menu + flag gate + tests.
- [ ] Commit.

### Task 30: Own-profile menu

- [ ] Add the "Add to list" entry on the own-profile menu in `profile_screen_router.dart`. Entry point `ownProfile`.
- [ ] Commit.

### Task 31: `UserListPeopleScreen` — "+ Add people" button

- [ ] Add a prominent primary button on `user_list_people_screen.dart` visible when `userList.isEditable`, that pushes `/lists/<id>/add-people`.
- [ ] Widget test: button absent when `!isEditable`; tap navigates; flag gate.
- [ ] Commit.

### Task 32: `UserListPeopleScreen` — swipe-to-remove

- [ ] Add `Dismissible` on each person row (when `isEditable`). On swipe: `PeopleListMembershipToggled(remove)`. Undo snackbar.
- [ ] Widget test: swipe triggers event with `entryPoint: listPeopleScreen`; undo restores.
- [ ] Commit.

### Task 33: Profile header chip mount

- [ ] In `profile_header_widget.dart`, mount `PeopleListMembershipIndicator(pubkey: ...)` when viewing other users. Feature-flag gate. Do not render for own profile.
- [ ] Widget test: chip absent when count=0, present when count>0, tap opens sheet.
- [ ] Commit.

---

## Chunk 4 review

**Dispatch `plan-document-reviewer`. Apply, re-dispatch.**

---

## Chunk 5: i18n, e2e, rollout prep

### Task 34: Localization keys

- [ ] Add all `people_lists.*` keys to `mobile/lib/l10n/app_en.arb`. Include placeholders for `{handle}`, `{listName}`, `{count}`, pluralization.

Keys (minimum):
```
people_lists.sheet_title
people_lists.sheet_subtitle                 # "for @{handle}"
people_lists.new_list_row
people_lists.new_list_placeholder           # "List name"
people_lists.new_list_create
people_lists.member_count                   # pluralized, "{count, plural, =1{1 person} other{{count} people}}"
people_lists.empty_title
people_lists.empty_body
people_lists.empty_cta
people_lists.added_announce                 # "Added {handle} to {listName}"
people_lists.removed_announce               # "Removed {handle} from {listName}"
people_lists.removed_snackbar               # "Removed from {listName}"
people_lists.undo
people_lists.publish_failed                 # "Couldn't reach the relay"
people_lists.retry
people_lists.add_people_title
people_lists.add_people_add_n               # "Add {count}"
people_lists.already_in_list
people_lists.indicator_in_n_lists           # pluralized
people_lists.create_name_label
people_lists.create_description_label
people_lists.create_public_label
people_lists.create_public_coming_soon      # tooltip
```

- [ ] Run the project's l10n generation command (check `pubspec.yaml` and `l10n.yaml`).
- [ ] Replace every inline string in the feature with `AppLocalizations.of(context).peopleLists*`.
- [ ] Commit.

### Task 35: E2E test against the local Docker stack

**Files:**
- Create: `mobile/integration_test/people_lists_e2e_test.dart`

- [ ] Write a Patrol test that:
  1. Registers + signs in via the standard helpers.
  2. With `--dart-define=FF_CURATED_LISTS=true`, navigates to another user's profile.
  3. Opens "Add to list" menu.
  4. Creates a new list inline named "Test List".
  5. Asserts the list appears in the Explore "People Lists" section.
  6. Queries the local FunnelCake relay directly for the kind 30000 event and verifies the `p` tag equals the target pubkey.
  7. Removes the person via swipe on `UserListPeopleScreen`, asserts undo snackbar, taps Undo, asserts restored.

- [ ] Use `integration_test/helpers/` — `launchAppGuarded`, `pumpUntilSettled`, `relay_helpers`.

- [ ] Run `mise run e2e_test integration_test/people_lists_e2e_test.dart`.

- [ ] Commit.

### Task 36: CHANGELOG + PR description

- [ ] Add a terse entry to `mobile/docs/CHANGELOG.md` under "Unreleased": "Add people to lists (gated by FF_CURATED_LISTS)".
- [ ] Do NOT flip the feature flag in this plan. A separate PR does that.
- [ ] Final commit.

### Task 37: Full local verification

- [ ] `cd mobile && flutter pub get && dart run build_runner build --delete-conflicting-outputs`
- [ ] `flutter analyze lib test integration_test` → zero issues.
- [ ] `flutter test` → all green.
- [ ] `flutter test --tags golden` → all green.
- [ ] `mise run e2e_test integration_test/people_lists_e2e_test.dart` → green.
- [ ] Manually smoke-test with `--dart-define=FF_CURATED_LISTS=true` on an emulator.

### Task 38: Open the PR

- [ ] Push branch, open PR via `gh pr create`.
- [ ] PR body references the spec doc path and links the commit `24f459b9c`.
- [ ] Use `superpowers:finishing-a-development-branch` for cleanup.

---

## Chunk 5 review

**Dispatch `plan-document-reviewer` for the final chunk. Apply, re-dispatch until Approved.**

---

## Out of this plan

- **Flipping `FF_CURATED_LISTS` to `defaultValue: true`.** That's a separate, tiny PR once product confirms both video-add-to-list and people-add-to-list should go live together. Don't bundle.
- **Publishing the Divine Team list as a real NIP-51 event.** Synthetic v1 is good enough; promotion to a signed-and-published event can happen without app changes later.
- **Private/encrypted lists.** Tracked as future spec work; the `isPublic` toggle stays disabled with a "Coming soon" tooltip.
- **Chunked lists > ~500 members.** Out of scope; `PeopleListsRepositoryImpl` can assume lists stay within one event's size budget.
