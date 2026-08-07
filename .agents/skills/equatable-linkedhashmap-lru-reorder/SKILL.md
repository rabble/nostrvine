---
name: equatable-linkedhashmap-lru-reorder
description: |
  Fix LRU-bounded Flutter/bloc state classes that silently lose insertion-order
  updates. Use when: (1) a state class uses `Equatable` with a
  `LinkedHashMap<K, V>` field to preserve insertion order (LRU, MRU, recent-items
  caches), (2) `Cubit.emit` appears to drop emissions when an existing key is
  re-inserted or moved to most-recent, (3) LRU eviction evicts the "wrong"
  entry after a refresh, (4) a test that reports the same key twice and then
  overflows the cap sees the refreshed entry evicted instead of the oldest.
  Root cause: Equatable's default map comparison is structural (unordered), so
  reordering without changing keys/values produces an "equal" state that
  `Cubit.emit` suppresses.
author: Claude Code
version: 1.0.0
date: 2026-04-05
---

# Equatable + LinkedHashMap LRU reorder suppression

## Problem

A Flutter bloc/cubit state class uses an insertion-ordered `LinkedHashMap<K, V>`
to implement LRU semantics (touch-on-access, evict oldest past a cap). The
field is included in `props` for value equality. When an existing key is
re-inserted to move it to most-recent, `Cubit.emit` drops the new state as
equal to the previous one, leaving LRU order stale. On the next insert past
the cap, the "touched" entry is evicted instead of the truly oldest one.

This is silent: no errors, no logs. Tests that only check the final status
of each key pass. The bug surfaces only when a test specifically asserts
that a refreshed key survives a later cap-overflow eviction.

## Context / Trigger Conditions

- State class `extends Equatable` with a `LinkedHashMap<K, V>` field
- LRU behavior implemented via `remove(key)` + insert to move-to-most-recent
- `props` includes the map directly: `List<Object?> get props => [_map, ...]`
- Symptoms:
  - `blocTest(..., expect: () => hasLength(N))` reports fewer emissions than expected
  - LRU eviction test like "refresh key A, then overflow — expect B evicted" fails with A evicted instead
  - Consumers using `BlocListener` or `context.select` don't react to touch-only updates

## Solution

Add the keys list to `props` alongside the map so insertion-order changes
produce a distinct state:

```dart
@override
List<Object?> get props {
  // Both entries are required.
  //
  // Equatable's default map comparison is structural (unordered), so
  // `_statuses` alone catches value changes but NOT pure LRU reorders
  // where the key/value set is unchanged.
  // `_statuses.keys.toList()` catches those insertion-order changes.
  // Removing either would silently suppress a whole class of state
  // updates — do not "simplify" this.
  return [_statuses, _statuses.keys.toList(), maxEntries];
}
```

Keep the map in `props` as well — it catches value-only changes (same key,
different value, no reorder). The keys list catches order-only changes.
Together they cover both dimensions. Removing either re-opens the bug.

### Additional hardening (recommended)

While you're here, also:

1. **Defensive-copy in the constructor** if it accepts an externally-built
   `LinkedHashMap`. A caller can otherwise retain a reference and mutate
   the "immutable" state:

   ```dart
   VideoPlaybackStatusState({
     this.maxEntries = _defaultMaxEntries,
     LinkedHashMap<K, V>? statuses,
   }) : _statuses = statuses == null
             ? LinkedHashMap<K, V>()
             : LinkedHashMap<K, V>.from(statuses);
   ```

2. **Short-circuit redundant writes** in the cubit to avoid allocating a
   new map on every no-op report (e.g. errorBuilder fires every frame
   during a retry):

   ```dart
   void report(K key, V value) {
     if (state.valueFor(key) == value) return;
     emit(state.withValue(key, value));
   }
   ```

## Verification

Write an explicit props-inequality test that pins the invariant directly,
rather than relying on higher-level LRU tests to transitively catch it:

```dart
test('states with same entries but different LRU order are not equal', () {
  final a = MyState()
      .withStatus(idA, Status.foo)
      .withStatus(idB, Status.bar);
  final b = MyState()
      .withStatus(idB, Status.bar)
      .withStatus(idA, Status.foo);

  expect(a, isNot(equals(b)));
});
```

Mutation test: temporarily revert to `props: [_map, maxEntries]` (no keys
list) and run the test. It MUST fail. Restore and confirm pass. This
proves the assertion is load-bearing and guards the invariant.

## Example

Full state class shape (Dart):

```dart
import 'dart:collection';
import 'package:equatable/equatable.dart';

class VideoPlaybackStatusState extends Equatable {
  VideoPlaybackStatusState({
    this.maxEntries = _defaultMaxEntries,
    LinkedHashMap<String, PlaybackStatus>? statuses,
  }) : _statuses = statuses == null
            ? LinkedHashMap<String, PlaybackStatus>()
            : LinkedHashMap<String, PlaybackStatus>.from(statuses);

  static const int _defaultMaxEntries = 100;
  final int maxEntries;
  final LinkedHashMap<String, PlaybackStatus> _statuses;

  PlaybackStatus statusFor(String id) =>
      _statuses[id] ?? PlaybackStatus.ready;

  VideoPlaybackStatusState withStatus(String id, PlaybackStatus status) {
    final next = LinkedHashMap<String, PlaybackStatus>.from(_statuses)
      ..remove(id)
      ..[id] = status;
    while (next.length > maxEntries) {
      next.remove(next.keys.first);
    }
    return VideoPlaybackStatusState(maxEntries: maxEntries, statuses: next);
  }

  @override
  List<Object?> get props => [_statuses, _statuses.keys.toList(), maxEntries];
  //                         ^^^^^^^^^^^  ^^^^^^^^^^^^^^^^^^^^^^^^
  //                         catches      catches reorders
  //                         value changes (LRU touches)
}
```

The LRU test that catches the bug:

```dart
test('reporting same id twice moves it to most-recent', () {
  final cubit = VideoPlaybackStatusCubit(maxEntries: 2);
  cubit.report(id1, PlaybackStatus.forbidden);
  cubit.report(id2, PlaybackStatus.ageRestricted);
  cubit.report(id1, PlaybackStatus.forbidden); // refresh id1
  cubit.report(id3, PlaybackStatus.notFound);  // overflow

  // Without the fix: id1 is evicted (wrong — it was just touched)
  // With the fix: id2 is evicted (correct — it's the oldest)
  expect(cubit.state.statusFor(id2), PlaybackStatus.ready);
  expect(cubit.state.statusFor(id1), PlaybackStatus.forbidden);
});
```

## Notes

- **Flutter lint interaction**: Using an explicit `LinkedHashMap<K, V>()`
  literal trips `prefer_collection_literals` (the lint wants `{}`). But
  `{}` types as `Map<K, V>`, not `LinkedHashMap`, which loses the
  compile-time guarantee that insertion order is preserved across
  refactors. Keep the explicit type and suppress the lint locally
  (`// ignore: prefer_collection_literals`) if the constructor path
  triggers it.
- **Applies to any ordered collection in Equatable**: `Queue`, `SplayTreeMap`,
  or any structure where order is semantic. Anywhere Equatable compares
  the structure contents unordered but your code depends on order, you
  need a secondary props entry that captures the order.
- **Not specific to bloc**: the same bug appears with Riverpod's state
  notifier `==` checks and any equality-based diffing. Same fix applies.
- **TDD discipline**: this bug was only caught because a test specifically
  asserted "refreshed key survives overflow." A test suite that only
  checks "status X maps to key Y" after individual writes would pass
  with the bug intact. When writing tests for ordered-collection state,
  always include at least one test that exercises the ordering itself
  (not just membership).

## References

- [Equatable package — props semantics](https://pub.dev/packages/equatable)
- [Dart `LinkedHashMap` — insertion-order guarantee](https://api.dart.dev/stable/dart-collection/LinkedHashMap-class.html)
- [flutter_bloc — Cubit.emit equality behavior](https://pub.dev/packages/flutter_bloc)
- Divine mobile fix: `fix(video_playback_status): add cubit for per-video playback status tracking` (commit `fb828df33` on branch `fix/moderated-content-filter`), where the bug was caught and fixed.
