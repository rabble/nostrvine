# List Unfollow and Delete Design

## Goal

Let users leave lists they follow and delete lists they own, without conflating the two actions.

The product rule is:

- Somebody else's list: the user can unfollow it.
- The user's own list: the user can delete it.

The implementation must preserve Nostr semantics. Unfollow is local subscription state. Delete is a protocol-level deletion for owned public lists, not just a local cache removal.

Implementation should be split into small, test-first slices by user intent:

1. Unfollow somebody else's list.
2. Delete the user's own lists, covering both people lists and curated video lists.

The first slice is purely subscription state: leaving a followed external list. The second slice is destructive ownership behavior: deleting owned people lists through the existing kind `30000` delete path and deleting owned curated video lists only after adding protocol-backed kind `30005` deletion.

## Current State

There are two list systems:

- Curated video lists, kind `30005`, backed by `CuratedListService`.
- People lists, kind `30000`, backed by `PeopleListsRepository` and `PeopleListsBloc`.

Curated video lists already support subscribe and unsubscribe through `CuratedListService.subscribeToList` and `unsubscribeFromList`. `CuratedListFeedScreen` and `DiscoverListsScreen` already toggle this state, but the detail action is icon-only and does not clearly expose "Unfollow".

Curated video lists also have `CuratedListService.deleteList`, but that method only removes local state. It must not be exposed as "Delete list" for a public list because the relay-published replaceable event remains visible.

People lists already have protocol-backed delete support. `PeopleListsRepository.deleteList` publishes a NIP-09 kind `5` deletion event for the list address, and `PeopleListsBloc` exposes `PeopleListsDeleteRequested`. The missing piece is owner-only UI on `UserListPeopleScreen`.

## User Experience

List detail screens should expose list actions from the app bar. Use an overflow/action menu rather than a permanently visible destructive button.

For a followed list owned by someone else:

- Show `Unfollow list`.
- On activation, remove the subscription/follow state.
- Show snackbar feedback after the service reports success.
- Do not add undo in the first slice. The restore source differs between route-created list detail screens and discovered-list screens, so undo can be added later only after one explicit restore path is chosen.
- Do not publish any deletion event.

For a list owned by the current user:

- Show `Delete list`.
- Require confirmation before dispatching the delete.
- After confirmation, dispatch the delete and navigate away from the detail screen so the user does not land on the "list deleted" empty state.
- Because the detail screen pops optimistically, do not promise detail-screen failure UI after dispatch. Failure should surface through the owner-scoped list surface if it already listens to `PeopleListsStatus.failure`; do not store raw error text in BLoC state.

If a list is both owned and followed, prefer `Delete list` over `Unfollow list`. Deleting an owned list is the clearer primary action because the user controls the source event.

## Architecture

People-list delete should use existing BLoC and repository paths:

- `UserListPeopleScreen` renders delete only for lists selected from the current owner-scoped `PeopleListsBloc` state and only when `userList.isEditable == true`.
- `UserList.isEditable` is not ownership proof; it is an additional guard for system/read-only lists. Ownership comes from the route selecting from the authenticated owner's bloc state.
- Confirmation dispatches `PeopleListsDeleteRequested(listId: userList.id)`.
- `PeopleListsBloc` continues to optimistically remove the list and calls `PeopleListsRepository.deleteList`.
- `PeopleListsRepositoryImpl.deleteList` remains the protocol-backed NIP-09 implementation.

Curated-list unfollow should use existing service paths:

- `CuratedListFeedScreen` determines whether the current user is subscribed to the displayed list.
- For subscribed external lists, expose an explicit `Unfollow list` action.
- The action calls `CuratedListService.unsubscribeFromList`, invalidates list providers, and updates the UI.
- The first slice does not implement undo.

Curated-list delete needs one extra repository/service capability before UI exposure:

- Add a protocol-backed delete path for owned public curated video lists.
- Publish a NIP-09 kind `5` deletion event that references the kind `30005` addressable list coordinate.
- Only after that exists should owned curated lists show `Delete list`.
- Local-only removal can remain internal, but it must not be labeled as deleting the public list.

## Implementation Slices

Slice 1: unfollow somebody else's list.

- Add explicit unfollow UI to `CuratedListFeedScreen` for subscribed external lists.
- Reuse `CuratedListService.unsubscribeFromList`.
- Do not touch delete behavior.
- Do not add people-list follow/unfollow in this slice because public people-list detail/follow is not currently a routed product surface.

Slice 2: delete the user's own lists.

- Add owner-scoped delete UI to `UserListPeopleScreen`.
- Reuse `PeopleListsDeleteRequested` and the existing `PeopleListsRepository.deleteList` NIP-09 path for owned people lists.
- Add a tested service/repository method that publishes NIP-09 deletion for owned kind `30005` list coordinates.
- Only after the protocol-backed method exists, expose `Delete list` for owned curated video lists.
- Keep local-only `CuratedListService.deleteList` internal or rename it before any UI references it.

## Data Flow

People-list delete:

1. User opens their people list.
2. User chooses `Delete list`.
3. Confirmation dialog returns true.
4. UI dispatches `PeopleListsDeleteRequested`.
5. Bloc optimistically removes the list from state.
6. Repository publishes kind `5` deletion and tombstones the list locally.
7. UI navigates back to the previous screen.
8. If repository submission fails after navigation, existing owner-list UI may surface `PeopleListsStatus.failure`; the popped detail screen does not handle it.

Curated-list unfollow:

1. User opens a subscribed list owned by someone else.
2. User chooses `Unfollow list`.
3. UI calls `unsubscribeFromList`.
4. Service removes the list id from subscribed-list state and notifies cache cleanup.
5. UI invalidates list providers and shows snackbar feedback.

Curated-list delete:

1. User opens their own curated list.
2. User chooses `Delete list`.
3. Confirmation dialog returns true.
4. Service publishes NIP-09 deletion for the list coordinate.
5. Service removes/tombstones local state only after submission succeeds.
6. UI invalidates providers and navigates away.

## Error Handling

Delete and unfollow failures should not leave the UI pretending the action succeeded.

- People-list delete uses existing `PeopleListsStatus.failure` and `addError`; no raw exception strings in BLoC state.
- Curated-list unfollow should show translated failure copy and leave the subscribed state unchanged when the service reports failure.
- Curated-list delete should remove local state only after event submission succeeds. If publishing fails, keep the list visible and show failure copy.

## Testing

Add focused tests:

Slice 1 TDD order: unfollow.

1. RED: `CuratedListFeedScreen` shows explicit `Unfollow list` for subscribed external lists.
2. GREEN: expose unfollow action using existing subscription state.
3. RED: unfollow calls `unsubscribeFromList`, invalidates providers, and updates action state.
4. GREEN: wire service call, provider invalidation, and translated feedback.

Slice 2 TDD order: delete.

1. RED: `UserListPeopleScreen` shows delete for an editable list from the active owner-scoped bloc.
2. GREEN: add the smallest app-bar action/menu needed to expose delete.
3. RED: read-only people list does not show delete.
4. GREEN: gate the action with `isEditable`.
5. RED: delete confirmation cancel does not dispatch.
6. GREEN: wire cancel path.
7. RED: delete confirmation confirm dispatches `PeopleListsDeleteRequested` and navigates away.
8. GREEN: wire dispatch and pop.
9. RED: owned curated-list delete publishes a kind `5` event for the full kind `30005` list coordinate.
10. GREEN: add the minimal protocol-backed delete method.
11. RED: local curated-list state is not removed when publish fails.
12. GREEN: delay local removal/tombstone until submission succeeds.
13. RED: owned curated-list detail shows `Delete list` only after protocol-backed delete is available.
14. GREEN: expose owned curated-list delete UI.

Repository-level coverage for curated-list deletion should assert:

- The deletion event is kind `5`.
- It includes the full addressable coordinate for the kind `30005` list.
- Local state is not removed when publish fails.

## Out Of Scope

- Editing list metadata.
- Following public people lists discovered in search. Current public people-list search intentionally does not route into external owner list detail.
- Any new server API.
- Changing Nostr list kinds, d-tags, or truncating identifiers.
