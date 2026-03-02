import 'package:curated_list_repository/curated_list_repository.dart';
import 'package:models/models.dart';
import 'package:nostr_sdk/nostr_sdk.dart' show Event;
import 'package:test/test.dart';

/// 64-char hex pubkey for test events.
const _testPubkey =
    'aabbccddaabbccddaabbccddaabbccdd'
    'aabbccddaabbccddaabbccddaabbccdd';

/// Creates a kind 30005 Nostr event with the given [tags] and [content].
Event _makeEvent({
  List<List<String>> tags = const [],
  String content = '',
  int? createdAt,
}) {
  return Event(
    _testPubkey,
    30005,
    tags.map(List<dynamic>.from).toList(),
    content,
    createdAt: createdAt ?? 1718400000,
  );
}

void main() {
  group(CuratedListConverter, () {
    group('fromEvent', () {
      test('returns null when d-tag is missing', () {
        final event = _makeEvent(
          tags: [
            ['title', 'No D Tag'],
          ],
        );

        expect(CuratedListConverter.fromEvent(event), isNull);
      });

      test('parses minimal event with only d-tag', () {
        final event = _makeEvent(
          tags: [
            ['d', 'my-list'],
          ],
        );

        final list = CuratedListConverter.fromEvent(event);

        expect(list, isNotNull);
        expect(list!.id, equals('my-list'));
        expect(list.pubkey, equals(_testPubkey));
        expect(list.name, equals('Untitled List'));
        expect(list.videoEventIds, isEmpty);
        expect(list.isPublic, isTrue);
        expect(list.playOrder, equals(PlayOrder.chronological));
      });

      test('uses title tag for name', () {
        final event = _makeEvent(
          tags: [
            ['d', 'my-list'],
            ['title', 'My Favorites'],
          ],
        );

        final list = CuratedListConverter.fromEvent(event)!;

        expect(list.name, equals('My Favorites'));
      });

      test('falls back to content first line when title is absent', () {
        final event = _makeEvent(
          tags: [
            ['d', 'my-list'],
          ],
          content: 'Content Title\nMore content here',
        );

        final list = CuratedListConverter.fromEvent(event)!;

        expect(list.name, equals('Content Title'));
      });

      test('parses description and image tags', () {
        final event = _makeEvent(
          tags: [
            ['d', 'my-list'],
            ['title', 'Test'],
            ['description', 'A great list of videos'],
            ['image', 'https://example.com/cover.jpg'],
          ],
        );

        final list = CuratedListConverter.fromEvent(event)!;

        expect(list.description, equals('A great list of videos'));
        expect(list.imageUrl, equals('https://example.com/cover.jpg'));
      });

      test('falls back to content for description when tag is absent', () {
        final event = _makeEvent(
          tags: [
            ['d', 'my-list'],
            ['title', 'Test'],
          ],
          content: 'Fallback description',
        );

        final list = CuratedListConverter.fromEvent(event)!;

        expect(list.description, equals('Fallback description'));
      });

      test('parses e-tags as video event IDs', () {
        const id1 =
            '1111111111111111111111111111111111111111111111111111111111111111';
        const id2 =
            '2222222222222222222222222222222222222222222222222222222222222222';

        final event = _makeEvent(
          tags: [
            ['d', 'my-list'],
            ['e', id1],
            ['e', id2],
          ],
        );

        final list = CuratedListConverter.fromEvent(event)!;

        expect(list.videoEventIds, equals([id1, id2]));
      });

      test('parses a-tags with NIP-71 video kinds', () {
        final event = _makeEvent(
          tags: [
            ['d', 'my-list'],
            ['a', '34235:pubkey123:horizontal-video'],
            ['a', '34236:pubkey456:vertical-video'],
            ['a', '34237:pubkey789:live-video'],
          ],
        );

        final list = CuratedListConverter.fromEvent(event)!;

        expect(list.videoEventIds, hasLength(3));
        expect(
          list.videoEventIds,
          contains('34235:pubkey123:horizontal-video'),
        );
        expect(
          list.videoEventIds,
          contains('34236:pubkey456:vertical-video'),
        );
        expect(
          list.videoEventIds,
          contains('34237:pubkey789:live-video'),
        );
      });

      test('ignores a-tags with non-video kinds', () {
        final event = _makeEvent(
          tags: [
            ['d', 'my-list'],
            ['a', '30023:pubkey123:some-article'],
            ['a', '34236:pubkey456:actual-video'],
            ['a', '1:pubkey789:text-note'],
          ],
        );

        final list = CuratedListConverter.fromEvent(event)!;

        expect(list.videoEventIds, hasLength(1));
        expect(
          list.videoEventIds.first,
          equals('34236:pubkey456:actual-video'),
        );
      });

      test('parses collaborative settings', () {
        final event = _makeEvent(
          tags: [
            ['d', 'my-list'],
            ['collaborative', 'true'],
            ['collaborator', 'pubkey_alice'],
            ['collaborator', 'pubkey_bob'],
          ],
        );

        final list = CuratedListConverter.fromEvent(event)!;

        expect(list.isCollaborative, isTrue);
        expect(
          list.allowedCollaborators,
          equals(['pubkey_alice', 'pubkey_bob']),
        );
      });

      test('parses t-tags and thumbnail', () {
        final event = _makeEvent(
          tags: [
            ['d', 'my-list'],
            ['t', 'music'],
            ['t', 'dance'],
            ['thumbnail', 'thumb-event-id'],
          ],
        );

        final list = CuratedListConverter.fromEvent(event)!;

        expect(list.tags, equals(['music', 'dance']));
        expect(list.thumbnailEventId, equals('thumb-event-id'));
      });

      test('parses playorder tag', () {
        final event = _makeEvent(
          tags: [
            ['d', 'my-list'],
            ['playorder', 'reverse'],
          ],
        );

        final list = CuratedListConverter.fromEvent(event)!;

        expect(list.playOrder, equals(PlayOrder.reverse));
      });

      test('defaults playorder to chronological when absent', () {
        final event = _makeEvent(
          tags: [
            ['d', 'my-list'],
          ],
        );

        final list = CuratedListConverter.fromEvent(event)!;

        expect(list.playOrder, equals(PlayOrder.chronological));
      });

      test('skips tags with insufficient elements', () {
        final event = _makeEvent(
          tags: [
            ['d', 'my-list'],
            ['title'], // missing value
            ['e'], // missing value
            ['a'], // missing value
          ],
        );

        final list = CuratedListConverter.fromEvent(event)!;

        expect(list.name, equals('Untitled List'));
        expect(list.videoEventIds, isEmpty);
      });

      test('skips empty tags', () {
        final event = _makeEvent(
          tags: [
            ['d', 'my-list'],
            [], // empty tag
          ],
        );

        final list = CuratedListConverter.fromEvent(event);

        expect(list, isNotNull);
        expect(list!.id, equals('my-list'));
      });
    });

    group('toEventTags', () {
      final now = DateTime(2025, 6, 15);

      test('includes d-tag and title', () {
        final list = CuratedList(
          id: 'my-list',
          name: 'My List',
          videoEventIds: const [],
          createdAt: now,
          updatedAt: now,
        );

        final tags = CuratedListConverter.toEventTags(list);

        expect(tags, contains(equals(['d', 'my-list'])));
        expect(tags, contains(equals(['title', 'My List'])));
      });

      test('includes client tag', () {
        final list = CuratedList(
          id: 'my-list',
          name: 'Test',
          videoEventIds: const [],
          createdAt: now,
          updatedAt: now,
        );

        final tags = CuratedListConverter.toEventTags(list);

        expect(tags, contains(equals(['client', 'diVine'])));
      });

      test('includes description when present', () {
        final list = CuratedList(
          id: 'my-list',
          name: 'Test',
          description: 'A description',
          videoEventIds: const [],
          createdAt: now,
          updatedAt: now,
        );

        final tags = CuratedListConverter.toEventTags(list);

        expect(tags, contains(equals(['description', 'A description'])));
      });

      test('excludes description when null', () {
        final list = CuratedList(
          id: 'my-list',
          name: 'Test',
          videoEventIds: const [],
          createdAt: now,
          updatedAt: now,
        );

        final tags = CuratedListConverter.toEventTags(list);
        final descTags = tags.where((t) => t[0] == 'description');

        expect(descTags, isEmpty);
      });

      test('excludes description when empty', () {
        final list = CuratedList(
          id: 'my-list',
          name: 'Test',
          description: '',
          videoEventIds: const [],
          createdAt: now,
          updatedAt: now,
        );

        final tags = CuratedListConverter.toEventTags(list);
        final descTags = tags.where((t) => t[0] == 'description');

        expect(descTags, isEmpty);
      });

      test('includes image when present', () {
        final list = CuratedList(
          id: 'my-list',
          name: 'Test',
          imageUrl: 'https://example.com/img.jpg',
          videoEventIds: const [],
          createdAt: now,
          updatedAt: now,
        );

        final tags = CuratedListConverter.toEventTags(list);

        expect(
          tags,
          contains(equals(['image', 'https://example.com/img.jpg'])),
        );
      });

      test('includes t-tags for each tag', () {
        final list = CuratedList(
          id: 'my-list',
          name: 'Test',
          videoEventIds: const [],
          tags: const ['music', 'dance'],
          createdAt: now,
          updatedAt: now,
        );

        final tags = CuratedListConverter.toEventTags(list);

        expect(tags, contains(equals(['t', 'music'])));
        expect(tags, contains(equals(['t', 'dance'])));
      });

      test('includes collaborative and collaborator tags', () {
        final list = CuratedList(
          id: 'my-list',
          name: 'Test',
          videoEventIds: const [],
          isCollaborative: true,
          allowedCollaborators: const ['alice', 'bob'],
          createdAt: now,
          updatedAt: now,
        );

        final tags = CuratedListConverter.toEventTags(list);

        expect(tags, contains(equals(['collaborative', 'true'])));
        expect(tags, contains(equals(['collaborator', 'alice'])));
        expect(tags, contains(equals(['collaborator', 'bob'])));
      });

      test('excludes collaborative tags when not collaborative', () {
        final list = CuratedList(
          id: 'my-list',
          name: 'Test',
          videoEventIds: const [],
          createdAt: now,
          updatedAt: now,
        );

        final tags = CuratedListConverter.toEventTags(list);
        final collabTags = tags.where((t) => t[0] == 'collaborative');
        final collabPubkeys = tags.where((t) => t[0] == 'collaborator');

        expect(collabTags, isEmpty);
        expect(collabPubkeys, isEmpty);
      });

      test('includes thumbnail when present', () {
        final list = CuratedList(
          id: 'my-list',
          name: 'Test',
          videoEventIds: const [],
          thumbnailEventId: 'thumb-id',
          createdAt: now,
          updatedAt: now,
        );

        final tags = CuratedListConverter.toEventTags(list);

        expect(tags, contains(equals(['thumbnail', 'thumb-id'])));
      });

      test('includes playorder tag', () {
        final list = CuratedList(
          id: 'my-list',
          name: 'Test',
          videoEventIds: const [],
          playOrder: PlayOrder.shuffle,
          createdAt: now,
          updatedAt: now,
        );

        final tags = CuratedListConverter.toEventTags(list);

        expect(tags, contains(equals(['playorder', 'shuffle'])));
      });

      test('includes e-tags for video event IDs', () {
        final list = CuratedList(
          id: 'my-list',
          name: 'Test',
          videoEventIds: const ['video-1', 'video-2'],
          createdAt: now,
          updatedAt: now,
        );

        final tags = CuratedListConverter.toEventTags(list);

        expect(tags, contains(equals(['e', 'video-1'])));
        expect(tags, contains(equals(['e', 'video-2'])));
      });
    });

    group('extractDTag', () {
      test('returns null when no d-tag is present', () {
        final event = _makeEvent(
          tags: [
            ['title', 'No D Tag'],
          ],
        );

        expect(CuratedListConverter.extractDTag(event), isNull);
      });

      test('returns d-tag value', () {
        final event = _makeEvent(
          tags: [
            ['d', 'my-list-id'],
            ['title', 'Something'],
          ],
        );

        expect(
          CuratedListConverter.extractDTag(event),
          equals('my-list-id'),
        );
      });

      test('returns first d-tag when multiple exist', () {
        final event = _makeEvent(
          tags: [
            ['d', 'first'],
            ['d', 'second'],
          ],
        );

        expect(CuratedListConverter.extractDTag(event), equals('first'));
      });
    });
  });
}
