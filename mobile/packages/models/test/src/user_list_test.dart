import 'package:models/models.dart';
import 'package:test/test.dart';

void main() {
  group(UserList, () {
    final now = DateTime(2024, 6, 15);
    final userList = UserList(
      id: 'test_list',
      name: 'Test List',
      description: 'A test list',
      imageUrl: 'https://example.com/image.png',
      pubkeys: const ['pubkey1', 'pubkey2'],
      createdAt: now,
      updatedAt: now,
      nostrEventId: 'event123',
    );

    group('constructor', () {
      test('creates instance with required parameters', () {
        final list = UserList(
          id: 'id',
          name: 'name',
          pubkeys: const ['pk1'],
          createdAt: now,
          updatedAt: now,
        );
        expect(list.id, equals('id'));
        expect(list.name, equals('name'));
        expect(list.pubkeys, equals(['pk1']));
        expect(list.isPublic, isTrue);
        expect(list.isEditable, isTrue);
        expect(list.description, isNull);
        expect(list.imageUrl, isNull);
        expect(list.nostrEventId, isNull);
      });
    });

    group('fromJson', () {
      test('creates instance from JSON map', () {
        final json = userList.toJson();
        final result = UserList.fromJson(json);

        expect(result.id, equals('test_list'));
        expect(result.name, equals('Test List'));
        expect(result.description, equals('A test list'));
        expect(result.imageUrl, equals('https://example.com/image.png'));
        expect(result.pubkeys, equals(['pubkey1', 'pubkey2']));
        expect(result.createdAt, equals(now));
        expect(result.updatedAt, equals(now));
        expect(result.isPublic, isTrue);
        expect(result.nostrEventId, equals('event123'));
        expect(result.isEditable, isTrue);
      });

      test('handles missing optional fields', () {
        final json = <String, dynamic>{
          'id': 'id',
          'name': 'name',
          'createdAt': now.toIso8601String(),
          'updatedAt': now.toIso8601String(),
        };
        final result = UserList.fromJson(json);

        expect(result.pubkeys, isEmpty);
        expect(result.description, isNull);
        expect(result.imageUrl, isNull);
        expect(result.isPublic, isTrue);
        expect(result.nostrEventId, isNull);
        expect(result.isEditable, isTrue);
      });
    });

    group('toJson', () {
      test('serializes all fields to JSON', () {
        final json = userList.toJson();

        expect(json['id'], equals('test_list'));
        expect(json['name'], equals('Test List'));
        expect(json['description'], equals('A test list'));
        expect(json['imageUrl'], equals('https://example.com/image.png'));
        expect(json['pubkeys'], equals(['pubkey1', 'pubkey2']));
        expect(json['isPublic'], isTrue);
        expect(json['nostrEventId'], equals('event123'));
        expect(json['isEditable'], isTrue);
      });
    });

    group('copyWith', () {
      test('returns copy with updated name', () {
        final copy = userList.copyWith(name: 'Updated');
        expect(copy.name, equals('Updated'));
        expect(copy.id, equals(userList.id));
        expect(copy.pubkeys, equals(userList.pubkeys));
      });

      test('returns copy with updated pubkeys', () {
        final copy = userList.copyWith(pubkeys: ['pk3']);
        expect(copy.pubkeys, equals(['pk3']));
        expect(copy.name, equals(userList.name));
      });

      test('returns identical copy when no arguments', () {
        final copy = userList.copyWith();
        expect(copy, equals(userList));
      });
    });

    group('Equatable', () {
      test('instances with same props are equal', () {
        final a = UserList(
          id: 'id',
          name: 'name',
          pubkeys: const [],
          createdAt: now,
          updatedAt: now,
        );
        final b = UserList(
          id: 'id',
          name: 'name',
          pubkeys: const [],
          createdAt: now,
          updatedAt: now,
        );
        expect(a, equals(b));
      });

      test('instances with different props are not equal', () {
        final a = UserList(
          id: 'id1',
          name: 'name',
          pubkeys: const [],
          createdAt: now,
          updatedAt: now,
        );
        final b = UserList(
          id: 'id2',
          name: 'name',
          pubkeys: const [],
          createdAt: now,
          updatedAt: now,
        );
        expect(a, isNot(equals(b)));
      });
    });
  });
}
