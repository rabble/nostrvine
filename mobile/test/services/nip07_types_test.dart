// ABOUTME: Tests for nip07_types.dart — Nip07Exception, data helpers,
// ABOUTME: safeNip07Call error classification, and stub class contracts.

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/nip07_types.dart';

void main() {
  group('Nip07Exception', () {
    test('toString without code', () {
      const ex = Nip07Exception('something went wrong');
      expect(ex.toString(), equals('NIP-07 Error: something went wrong'));
    });

    test('toString with code', () {
      const ex = Nip07Exception('user rejected', code: 'USER_REJECTED');
      expect(
        ex.toString(),
        equals('NIP-07 Error: user rejected (USER_REJECTED)'),
      );
    });
  });

  group('dartEventToJs', () {
    test('maps all fields when fully populated', () {
      final dart = {
        'id': 'abc123',
        'pubkey': 'deadbeef',
        'created_at': 1_700_000_000,
        'kind': 1,
        'tags': [
          ['e', 'note1abc'],
          ['p', 'pubkey1'],
        ],
        'content': 'hello',
        'sig': 'sig123',
      };

      final event = dartEventToJs(dart);

      expect(event.id, equals('abc123'));
      expect(event.pubkey, equals('deadbeef'));
      expect(event.created_at, equals(1_700_000_000));
      expect(event.kind, equals(1));
      expect(
        event.tags,
        equals([
          ['e', 'note1abc'],
          ['p', 'pubkey1'],
        ]),
      );
      expect(event.content, equals('hello'));
      expect(event.sig, equals('sig123'));
    });

    test('defaults created_at to current time when missing', () {
      final before = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final event = dartEventToJs({'pubkey': 'pk', 'kind': 1, 'content': ''});
      final after = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      expect(event.created_at, isA<int>());
      expect(event.created_at, greaterThanOrEqualTo(before));
      expect(event.created_at, lessThanOrEqualTo(after));
    });

    test('handles empty tags list', () {
      final event = dartEventToJs({
        'pubkey': 'pk',
        'created_at': 1000,
        'kind': 1,
        'tags': <dynamic>[],
        'content': 'x',
      });

      expect(event.tags, isEmpty);
    });
  });

  group('jsEventToDart', () {
    test('maps all fields to a Dart map', () {
      final event = NostrEvent(
        id: 'id1',
        pubkey: 'pk1',
        created_at: 1_700_000_000,
        kind: 1,
        tags: [
          ['e', 'note1abc'],
        ],
        content: 'world',
        sig: 'sig1',
      );

      final map = jsEventToDart(event);

      expect(map['id'], equals('id1'));
      expect(map['pubkey'], equals('pk1'));
      expect(map['created_at'], equals(1_700_000_000));
      expect(map['kind'], equals(1));
      expect(
        map['tags'],
        equals([
          ['e', 'note1abc'],
        ]),
      );
      expect(map['content'], equals('world'));
      expect(map['sig'], equals('sig1'));
    });
  });

  group('safeNip07Call', () {
    test('returns the value on success', () async {
      final result = await safeNip07Call(() async => 'ok', 'testOp');
      expect(result, equals('ok'));
    });

    test('classifies user-rejected errors', () async {
      Future<void> op() async => throw Exception('User rejected the request');

      await expectLater(
        safeNip07Call(op, 'sign'),
        throwsA(
          isA<Nip07Exception>().having(
            (e) => e.code,
            'code',
            equals('USER_REJECTED'),
          ),
        ),
      );
    });

    test('classifies not-implemented errors', () async {
      Future<void> op() async =>
          throw Exception('Not implemented by this extension');

      await expectLater(
        safeNip07Call(op, 'getRelays'),
        throwsA(
          isA<Nip07Exception>().having(
            (e) => e.code,
            'code',
            equals('NOT_IMPLEMENTED'),
          ),
        ),
      );
    });

    test('classifies unknown errors', () async {
      Future<void> op() async => throw Exception('network error');

      await expectLater(
        safeNip07Call(op, 'sign'),
        throwsA(
          isA<Nip07Exception>().having(
            (e) => e.code,
            'code',
            equals('UNKNOWN_ERROR'),
          ),
        ),
      );
    });
  });

  group('NostrExtension stub', () {
    test('getPublicKey throws UnsupportedError', () async {
      await expectLater(
        const NostrExtension().getPublicKey(),
        throwsUnsupportedError,
      );
    });

    test('signEvent throws UnsupportedError', () async {
      await expectLater(
        const NostrExtension().signEvent({}),
        throwsUnsupportedError,
      );
    });

    test('getRelays throws UnsupportedError', () {
      expect(
        () => const NostrExtension().getRelays(),
        throwsUnsupportedError,
      );
    });

    test('nip04 getter returns null', () {
      expect(const NostrExtension().nip04, isNull);
    });

    test('nip44 getter returns null', () {
      expect(const NostrExtension().nip44, isNull);
    });
  });

  group('NIP04 stub', () {
    test('encrypt throws UnsupportedError', () async {
      await expectLater(
        const NIP04().encrypt('pk', 'text'),
        throwsUnsupportedError,
      );
    });

    test('decrypt throws UnsupportedError', () async {
      await expectLater(
        const NIP04().decrypt('pk', 'cipher'),
        throwsUnsupportedError,
      );
    });
  });

  group('NIP44 stub', () {
    test('encrypt throws UnsupportedError', () async {
      await expectLater(
        const NIP44().encrypt('pk', 'text'),
        throwsUnsupportedError,
      );
    });

    test('decrypt throws UnsupportedError', () async {
      await expectLater(
        const NIP44().decrypt('pk', 'cipher'),
        throwsUnsupportedError,
      );
    });
  });
}
