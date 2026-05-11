import 'package:cache_sync/src/cache_dao_impl.dart';
import 'package:cache_sync/src/cache_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group(CacheDaoImpl, () {
    late CacheDatabase db;
    late CacheDaoImpl dao;

    setUp(() {
      db = CacheDatabase.test(NativeDatabase.memory());
      dao = CacheDaoImpl(db);
    });

    tearDown(() => db.close());

    group('write / read', () {
      test('returns null for absent key', () async {
        expect(await dao.read('missing'), isNull);
      });

      test('returns payload for a written entry', () async {
        await dao.write(key: 'k1', payload: '{"x":1}');
        expect(await dao.read('k1'), equals('{"x":1}'));
      });

      test('overwrites existing entry', () async {
        await dao.write(key: 'k1', payload: 'first');
        await dao.write(key: 'k1', payload: 'second');
        expect(await dao.read('k1'), equals('second'));
      });
    });

    group('TTL eviction', () {
      test('returns null for an already-expired entry', () async {
        await dao.write(
          key: 'expired',
          payload: 'old',
          ttl: const Duration(microseconds: 1),
        );
        await Future<void>.delayed(const Duration(milliseconds: 5));
        expect(await dao.read('expired'), isNull);
      });

      test('returns payload when TTL has not yet elapsed', () async {
        await dao.write(
          key: 'fresh',
          payload: 'data',
          ttl: const Duration(hours: 1),
        );
        expect(await dao.read('fresh'), equals('data'));
      });

      test('entry without TTL never expires', () async {
        await dao.write(key: 'immortal', payload: 'forever');
        expect(await dao.read('immortal'), equals('forever'));
      });
    });

    group('delete', () {
      test('removes entry', () async {
        await dao.write(key: 'del', payload: 'bye');
        await dao.delete('del');
        expect(await dao.read('del'), isNull);
      });

      test('is a no-op for absent key', () async {
        await expectLater(dao.delete('no_such_key'), completes);
      });
    });

    group('deleteAll', () {
      test('removes all entries', () async {
        await dao.write(key: 'user1:home_feed', payload: 'a');
        await dao.write(key: 'user2:likes', payload: 'b');

        await dao.deleteAll();

        expect(await dao.read('user1:home_feed'), isNull);
        expect(await dao.read('user2:likes'), isNull);
      });

      test('is a no-op when store is empty', () async {
        await expectLater(dao.deleteAll(), completes);
      });
    });

    group('totalPayloadBytes', () {
      test('returns 0 when store is empty', () async {
        expect(await dao.totalPayloadBytes(), equals(0));
      });

      test('returns sum of all payload lengths', () async {
        await dao.write(key: 'a', payload: 'hello'); // 5
        await dao.write(key: 'b', payload: 'world!'); // 6
        expect(await dao.totalPayloadBytes(), equals(11));
      });

      test('reflects overwritten payload size', () async {
        await dao.write(key: 'a', payload: 'hello'); // 5
        await dao.write(key: 'a', payload: 'hi'); // 2 — replaces
        expect(await dao.totalPayloadBytes(), equals(2));
      });
    });

    group('evictOldest', () {
      test('does nothing when bytesToFree is 0', () async {
        await dao.write(key: 'a', payload: 'hello');
        await dao.evictOldest(0);
        expect(await dao.read('a'), equals('hello'));
      });

      test('deletes oldest entry until enough bytes are freed', () async {
        await dao.write(key: 'old', payload: 'aaaa'); // 4 bytes, written first
        await Future<void>.delayed(const Duration(milliseconds: 1));
        await dao.write(key: 'new', payload: 'bbbb'); // 4 bytes, written later

        await dao.evictOldest(4);

        expect(await dao.read('old'), isNull);
        expect(await dao.read('new'), equals('bbbb'));
      });

      test('evicts multiple entries when one is not enough', () async {
        await dao.write(key: 'a', payload: 'aa'); // 2
        await Future<void>.delayed(const Duration(milliseconds: 1));
        await dao.write(key: 'b', payload: 'bb'); // 2
        await Future<void>.delayed(const Duration(milliseconds: 1));
        await dao.write(key: 'c', payload: 'cc'); // 2 — newest, kept

        await dao.evictOldest(4);

        expect(await dao.read('a'), isNull);
        expect(await dao.read('b'), isNull);
        expect(await dao.read('c'), equals('cc'));
      });
    });

    group('size-based LRU eviction via write', () {
      setUp(() async {
        await db.close();
        db = CacheDatabase.test(NativeDatabase.memory());
        dao = CacheDaoImpl(db, maxSizeBytes: 10);
      });

      test('keeps entries within limit', () async {
        await dao.write(key: 'a', payload: 'aaaaa'); // 5
        await dao.write(key: 'b', payload: 'bbbbb'); // 5 — total: 10, ok

        expect(await dao.read('a'), equals('aaaaa'));
        expect(await dao.read('b'), equals('bbbbb'));
      });

      test('evicts oldest entry when limit is exceeded', () async {
        await dao.write(key: 'old', payload: 'aaaaaaaaaa'); // 10
        await Future<void>.delayed(const Duration(milliseconds: 1));
        // 10 + 10 = 20 > limit 10, 'old' is evicted
        await dao.write(key: 'new', payload: 'bbbbbbbbbb');

        expect(await dao.read('old'), isNull);
        expect(await dao.read('new'), equals('bbbbbbbbbb'));
      });

      test('does not evict when unlimited (maxSizeBytes: null)', () async {
        final unlimitedDao = CacheDaoImpl(db);
        await unlimitedDao.write(key: 'x', payload: 'x' * 1000);
        await unlimitedDao.write(key: 'y', payload: 'y' * 1000);

        expect(await unlimitedDao.totalPayloadBytes(), equals(2000));
        expect(await unlimitedDao.read('x'), isNotNull);
        expect(await unlimitedDao.read('y'), isNotNull);
      });
    });
  });
}
