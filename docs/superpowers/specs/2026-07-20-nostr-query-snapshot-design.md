# Nostr Query Snapshot Ownership Design

## Goal

Prevent `ConcurrentModificationError` while asynchronously persisting
one-shot Nostr query results by ensuring each asynchronous boundary owns a
stable list snapshot.

## Confirmed failure

`Nostr.queryEvents()` builds results in an `EventMemBox` and returns
`EventMemBox.all()`, which currently exposes the box's mutable backing list.
`NostrClient.queryEvents()` passes that list to
`NostrEventsDao.upsertEventsBatch()` without awaiting the write, then passes
the same list to `_mergeEvents()`.

When cache results are empty and a filter limit applies, `_mergeEvents()`
sorts the network list in place. The DAO transaction iterates that same list
and awaits each event upsert. The sort can therefore modify the list while
the DAO iterator is suspended, producing the Crashlytics
`ConcurrentModificationError` at `NostrEventsDao.upsertEventsBatch`.

A late relay event could create the same shared-mutation hazard, but it is not
required to reproduce the production failure.

## Design

Apply ownership at all three boundaries that currently share the collection:

1. `EventMemBox.all()` returns a detached snapshot instead of `_eventList`.
   Later box additions cannot alter a completed query result.
2. `NostrClient._mergeEvents()` treats both inputs as immutable values. It
   copies before sorting and returns a detached result even when one input is
   empty.
3. `NostrEventsDao.upsertEventsBatch()` copies its input synchronously before
   the first `await`, then iterates only that snapshot.

This is deliberate defense in depth. The query layer owns collection
completion, the repository/client layer owns merge behavior, and the DAO owns
the batch it persists. Event objects themselves are not deep-copied; only
list membership and ordering need isolation.

## Preserved behavior

- Network events continue to win ID-based deduplication over cached events.
- Filter limits still return the newest events by `created_at`.
- DAO persistence still receives every network event, not only the limited
  merged result.
- Persistence remains non-blocking for callers.
- Existing event ordering outside limited merge paths is preserved.

## Tests

Add focused regressions that fail on the current implementation:

- `nostr_sdk`: a list returned by `EventMemBox.all()` remains unchanged after
  the box receives another event.
- `nostr_client`: a limited query may sort its returned result, but the list
  handed to asynchronous persistence retains its original membership and
  ordering.
- `db_client`: mutating the caller's original batch after
  `upsertEventsBatch()` starts neither changes the persisted batch nor throws
  during iteration.

Run each focused test red before changing production code, then green after
the minimal corresponding implementation.

## Out of scope

- Changing the fire-and-forget persistence policy.
- Introducing immutable collection dependencies or deep-copying `Event`.
- Refactoring relay subscription lifecycle beyond the stable returned
  snapshot.
- Unrelated Nostr query, cache, or database behavior.
