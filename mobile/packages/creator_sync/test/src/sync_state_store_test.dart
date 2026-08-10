// ABOUTME: Tests for sync item state, body hashing, and the memory store.
// ABOUTME: Pins canonical-JSON hashing and per-kind isolation.

import 'package:creator_sync/creator_sync.dart';
import 'package:test/test.dart';

/// Builds a [SyncItemState] through non-constant arguments so repeated
/// calls with equal fields still return distinct instances instead of
/// being canonicalized into the same const object.
SyncItemState _buildState({required int createdAt, required String bodyHash}) {
  return SyncItemState(createdAt: createdAt, bodyHash: bodyHash);
}

void main() {
  const stateA = SyncItemState(createdAt: 7, bodyHash: 'hash-a');
  const stateB = SyncItemState(createdAt: 9, bodyHash: 'hash-b');

  group(SyncItemState, () {
    test('round-trips through json', () {
      expect(SyncItemState.fromJson(stateA.toJson()), equals(stateA));
    });

    test('compares by value', () {
      final a = _buildState(createdAt: 7, bodyHash: 'hash-a');
      final b = _buildState(createdAt: 7, bodyHash: 'hash-a');

      // Guards against the equality assertion below being satisfied
      // merely because const canonicalization made [a] and [b] the same
      // object — these must be genuinely distinct instances.
      expect(identical(a, b), isFalse);
      expect(a, equals(b));
      expect(stateA, isNot(equals(stateB)));
    });

    test('hashes equal instances identically', () {
      final a = _buildState(createdAt: 7, bodyHash: 'hash-a');
      final b = _buildState(createdAt: 7, bodyHash: 'hash-a');

      expect(a.hashCode, equals(b.hashCode));
    });

    test('describes itself for debugging', () {
      expect(stateA.toString(), equals('SyncItemState(7, hash-a)'));
    });
  });

  group('syncBodyHash', () {
    test('is stable for the same body', () {
      expect(
        syncBodyHash(const {'a': 1, 'b': 2}),
        equals(syncBodyHash(const {'a': 1, 'b': 2})),
      );
    });

    test('ignores key insertion order', () {
      expect(
        syncBodyHash(<String, dynamic>{'a': 1, 'b': 2}),
        equals(syncBodyHash(<String, dynamic>{'b': 2, 'a': 1})),
      );
    });

    test('ignores key order in nested maps', () {
      expect(
        syncBodyHash(<String, dynamic>{
          'outer': <String, dynamic>{'x': 1, 'y': 2},
        }),
        equals(
          syncBodyHash(<String, dynamic>{
            'outer': <String, dynamic>{'y': 2, 'x': 1},
          }),
        ),
      );
    });

    test('ignores key order in maps nested inside lists', () {
      expect(
        syncBodyHash(<String, dynamic>{
          'clips': [
            <String, dynamic>{'y': 1, 'x': 2},
          ],
        }),
        equals(
          syncBodyHash(<String, dynamic>{
            'clips': [
              <String, dynamic>{'x': 2, 'y': 1},
            ],
          }),
        ),
      );
    });

    test('preserves list order as significant', () {
      expect(
        syncBodyHash(const {
          'tags': ['a', 'b'],
        }),
        isNot(
          equals(
            syncBodyHash(const {
              'tags': ['b', 'a'],
            }),
          ),
        ),
      );
    });

    test('changes when a value changes', () {
      expect(
        syncBodyHash(const {'label': 'intro'}),
        isNot(equals(syncBodyHash(const {'label': 'outro'}))),
      );
    });
  });

  group(InMemorySyncStateStore, () {
    late InMemorySyncStateStore store;

    setUp(() => store = InMemorySyncStateStore());

    test('returns an empty map for an untouched kind', () async {
      expect(await store.readApplied(SyncItemKind.sound), isEmpty);
    });

    test('round-trips applied state', () async {
      await store.writeApplied(SyncItemKind.sound, {
        'divine:sync:sound:a': stateA,
      });

      expect(
        await store.readApplied(SyncItemKind.sound),
        equals({'divine:sync:sound:a': stateA}),
      );
    });

    test('keeps kinds isolated from each other', () async {
      await store.writeApplied(SyncItemKind.sound, {'a': stateA});

      expect(await store.readApplied(SyncItemKind.clip), isEmpty);
    });

    test('replaces the whole map on write', () async {
      await store.writeApplied(
        SyncItemKind.sound,
        {'a': stateA, 'b': stateB},
      );
      await store.writeApplied(SyncItemKind.sound, {'a': stateB});

      expect(
        await store.readApplied(SyncItemKind.sound),
        equals({'a': stateB}),
      );
    });

    test('returns a copy callers cannot mutate through', () async {
      await store.writeApplied(SyncItemKind.sound, {'a': stateA});
      (await store.readApplied(SyncItemKind.sound))['a'] = stateB;

      expect(
        await store.readApplied(SyncItemKind.sound),
        equals({'a': stateA}),
      );
    });
  });
}
