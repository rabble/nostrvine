// ABOUTME: Unit tests for UserListConverter — kind 30000 Nostr event parsing.

import 'package:curated_list_repository/curated_list_repository.dart';
import 'package:models/models.dart';
import 'package:nostr_sdk/nostr_sdk.dart' show Event;
import 'package:test/test.dart';

/// 64-char hex pubkey for test events.
const _testPubkey =
    'aabbccddaabbccddaabbccddaabbccdd'
    'aabbccddaabbccddaabbccddaabbccdd';

/// Creates a kind 30000 Nostr event with the given [tags] and [content].
Event _makeEvent({
  List<List<String>> tags = const [],
  String content = '',
  int? createdAt,
}) {
  return Event(
    _testPubkey,
    30000,
    tags.map(List<String>.from).toList(),
    content,
    createdAt: createdAt ?? 1718400000,
  );
}

void main() {
  group(UserListConverter, () {
    group('fromEvent', () {
      test('returns null when d-tag is missing', () {
        final event = _makeEvent(
          tags: [
            ['title', 'No D Tag'],
          ],
        );

        expect(UserListConverter.fromEvent(event), isNull);
      });

      test('parses minimal event with only d-tag', () {
        final event = _makeEvent(
          tags: [
            ['d', 'my-list'],
          ],
        );

        final list = UserListConverter.fromEvent(event);

        expect(list, isNotNull);
        expect(list!.id, equals('my-list'));
        expect(list.name, equals('Untitled List'));
        expect(list.pubkeys, isEmpty);
        expect(list.isPublic, isTrue);
      });

      test('uses title tag for name', () {
        final event = _makeEvent(
          tags: [
            ['d', 'my-list'],
            ['title', 'My People'],
          ],
        );

        final list = UserListConverter.fromEvent(event);

        expect(list!.name, equals('My People'));
      });

      test('falls back to name tag when title is absent', () {
        final event = _makeEvent(
          tags: [
            ['d', 'my-list'],
            ['name', 'Named List'],
          ],
        );

        final list = UserListConverter.fromEvent(event);

        expect(list!.name, equals('Named List'));
      });

      test('title tag takes precedence over name tag', () {
        final event = _makeEvent(
          tags: [
            ['d', 'my-list'],
            ['name', 'Name Tag'],
            ['title', 'Title Tag'],
          ],
        );

        final list = UserListConverter.fromEvent(event);

        expect(list!.name, equals('Title Tag'));
      });

      test('falls back to first line of content when no title or name', () {
        final event = _makeEvent(
          tags: [
            ['d', 'my-list'],
          ],
          content: 'Content Title\nSecond line',
        );

        final list = UserListConverter.fromEvent(event);

        expect(list!.name, equals('Content Title'));
      });

      test('parses p-tags as pubkeys', () {
        final event = _makeEvent(
          tags: [
            ['d', 'my-list'],
            ['p', 'pubkey1'],
            ['p', 'pubkey2'],
            ['p', 'pubkey3'],
          ],
        );

        final list = UserListConverter.fromEvent(event);

        expect(list!.pubkeys, equals(['pubkey1', 'pubkey2', 'pubkey3']));
      });

      test('parses description tag', () {
        final event = _makeEvent(
          tags: [
            ['d', 'my-list'],
            ['description', 'A great list of people'],
          ],
        );

        final list = UserListConverter.fromEvent(event);

        expect(list!.description, equals('A great list of people'));
      });

      test('parses image tag', () {
        final event = _makeEvent(
          tags: [
            ['d', 'my-list'],
            ['image', 'https://example.com/cover.jpg'],
          ],
        );

        final list = UserListConverter.fromEvent(event);

        expect(list!.imageUrl, equals('https://example.com/cover.jpg'));
      });

      test('sets createdAt and updatedAt from event timestamp', () {
        const ts = 1718400000;
        final event = _makeEvent(
          tags: [
            ['d', 'my-list'],
          ],
          createdAt: ts,
        );

        final list = UserListConverter.fromEvent(event);

        final expected = DateTime.fromMillisecondsSinceEpoch(ts * 1000);
        expect(list!.createdAt, equals(expected));
        expect(list.updatedAt, equals(expected));
      });

      test('sets nostrEventId from event id', () {
        final event = _makeEvent(
          tags: [
            ['d', 'my-list'],
          ],
        );

        final list = UserListConverter.fromEvent(event);

        expect(list!.nostrEventId, equals(event.id));
      });

      test('ignores unrecognised tags without throwing', () {
        final event = _makeEvent(
          tags: [
            ['d', 'my-list'],
            ['unknown', 'value'],
            ['e', 'some-event-id'],
          ],
        );

        expect(() => UserListConverter.fromEvent(event), returnsNormally);
        final list = UserListConverter.fromEvent(event);
        expect(list, isNotNull);
        expect(list!.pubkeys, isEmpty);
      });

      test('returns null on malformed event (empty tags list entry)', () {
        // An event where a tag entry is completely empty should not crash.
        final event = _makeEvent(
          tags: [
            ['d', 'my-list'],
            [], // empty tag — should be skipped
          ],
        );

        expect(() => UserListConverter.fromEvent(event), returnsNormally);
      });

      test('parses full event with all fields', () {
        final event = _makeEvent(
          tags: [
            ['d', 'full-list'],
            ['title', 'Full List'],
            ['description', 'All fields present'],
            ['image', 'https://example.com/img.jpg'],
            ['p', 'pk1'],
            ['p', 'pk2'],
          ],
          content: 'ignored when title present',
          createdAt: 1718400000,
        );

        final list = UserListConverter.fromEvent(event);

        expect(list, isNotNull);
        expect(list!.id, equals('full-list'));
        expect(list.name, equals('Full List'));
        expect(list.description, equals('All fields present'));
        expect(list.imageUrl, equals('https://example.com/img.jpg'));
        expect(list.pubkeys, equals(['pk1', 'pk2']));
        expect(list.isPublic, isTrue);
        expect(list.isEditable, isTrue);
      });
    });
  });

  group('UserList model', () {
    final now = DateTime(2024, 6, 15);

    test('copyWith preserves all fields', () {
      final original = UserList(
        id: 'id1',
        name: 'Original',
        pubkeys: const ['pk1'],
        createdAt: now,
        updatedAt: now,
        description: 'desc',
        imageUrl: 'https://img.com',
        nostrEventId: 'event1',
      );

      final copy = original.copyWith(name: 'Updated');

      expect(copy.id, equals('id1'));
      expect(copy.name, equals('Updated'));
      expect(copy.pubkeys, equals(['pk1']));
      expect(copy.description, equals('desc'));
      expect(copy.imageUrl, equals('https://img.com'));
    });

    test('equality is value-based', () {
      final a = UserList(
        id: 'id1',
        name: 'List',
        pubkeys: const ['pk1'],
        createdAt: now,
        updatedAt: now,
      );
      final b = UserList(
        id: 'id1',
        name: 'List',
        pubkeys: const ['pk1'],
        createdAt: now,
        updatedAt: now,
      );

      expect(a, equals(b));
    });

    test('lists with different pubkeys are not equal', () {
      final a = UserList(
        id: 'id1',
        name: 'List',
        pubkeys: const ['pk1'],
        createdAt: now,
        updatedAt: now,
      );
      final b = UserList(
        id: 'id1',
        name: 'List',
        pubkeys: const ['pk2'],
        createdAt: now,
        updatedAt: now,
      );

      expect(a, isNot(equals(b)));
    });
  });
}
