// ABOUTME: Tests for sync d-tag formatting and allowlist parsing.
// ABOUTME: Pins rejection of DM cursors and the vault key event.

import 'package:creator_sync/creator_sync.dart';
import 'package:test/test.dart';

/// Builds a [SyncItemRef] through a runtime call so that equal
/// arguments still produce distinct object instances. A direct
/// `const SyncItemRef(...)` literal would canonicalize to a single
/// shared object, letting identity stand in for value equality.
SyncItemRef _buildRef(SyncItemKind kind, String id) => SyncItemRef(kind, id);

void main() {
  group(SyncItemRef, () {
    const soundId =
        'f1e2d3c4b5a6978869504132231405f6e7d8c9baab9c8d7e6f50413223140506';

    group('dTag', () {
      test('formats a sound reference', () {
        expect(
          const SyncItemRef(SyncItemKind.sound, soundId).dTag,
          equals('divine:sync:sound:$soundId'),
        );
      });

      test('formats a clip reference', () {
        expect(
          const SyncItemRef(SyncItemKind.clip, 'uuid-1').dTag,
          equals('divine:sync:clip:uuid-1'),
        );
      });

      test('formats a draft reference', () {
        expect(
          const SyncItemRef(SyncItemKind.draft, 'uuid-2').dTag,
          equals('divine:sync:draft:uuid-2'),
        );
      });
    });

    group('tryParse', () {
      test('round-trips every kind', () {
        for (final kind in SyncItemKind.values) {
          final ref = SyncItemRef(kind, soundId);
          expect(SyncItemRef.tryParse(ref.dTag), equals(ref));
        }
      });

      test('preserves the full untruncated id', () {
        final parsed = SyncItemRef.tryParse('divine:sync:sound:$soundId');
        expect(parsed!.id, equals(soundId));
        expect(parsed.id.length, equals(64));
      });

      test('rejects the vault key event', () {
        expect(SyncItemRef.tryParse(vaultKeyDTag), isNull);
      });

      test('rejects a dm_repository read cursor', () {
        expect(SyncItemRef.tryParse('divine:dm:read-cursor'), isNull);
      });

      test('rejects an unknown item kind under our prefix', () {
        expect(SyncItemRef.tryParse('divine:sync:playlist:xyz'), isNull);
      });

      test('rejects a foreign app namespace', () {
        expect(SyncItemRef.tryParse('other-app:sound:xyz'), isNull);
      });

      test('rejects an empty id', () {
        expect(SyncItemRef.tryParse('divine:sync:sound:'), isNull);
      });

      test('rejects an empty string', () {
        expect(SyncItemRef.tryParse(''), isNull);
      });

      test('keeps colons appearing inside the id', () {
        final parsed = SyncItemRef.tryParse('divine:sync:clip:a:b');
        expect(parsed!.id, equals('a:b'));
      });
    });

    group('hashCode', () {
      test('equal refs produce equal hashes', () {
        final ref1 = _buildRef(SyncItemKind.sound, soundId);
        final ref2 = _buildRef(SyncItemKind.sound, soundId);
        expect(identical(ref1, ref2), isFalse);
        expect(ref1.hashCode, equals(ref2.hashCode));
      });

      test('refs differing by kind do not collide', () {
        final ref1 = _buildRef(SyncItemKind.sound, 'id');
        final ref2 = _buildRef(SyncItemKind.clip, 'id');
        expect(identical(ref1, ref2), isFalse);
        expect(ref1.hashCode, isNot(equals(ref2.hashCode)));
      });

      test('refs differing by id do not collide', () {
        final ref1 = _buildRef(SyncItemKind.sound, 'id1');
        final ref2 = _buildRef(SyncItemKind.sound, 'id2');
        expect(identical(ref1, ref2), isFalse);
        expect(ref1.hashCode, isNot(equals(ref2.hashCode)));
      });
    });

    group('toString', () {
      test('contains the full untruncated dTag', () {
        const ref = SyncItemRef(SyncItemKind.sound, soundId);
        expect(ref.toString(), contains('divine:sync:sound:$soundId'));
      });

      test('never truncates nostr ids in output', () {
        const ref = SyncItemRef(SyncItemKind.clip, soundId);
        final str = ref.toString();
        expect(str, contains(soundId));
      });
    });
  });
}
