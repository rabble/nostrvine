import 'package:cache_sync/cache_sync.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_cache_dao.dart';

void main() {
  late FakeCacheDao dao;

  setUp(() async {
    dao = FakeCacheDao();
    await CacheSync.init(dao: dao);
  });

  group('CacheSync.invalidate', () {
    test('removes the entry for the given key', () async {
      await dao.write(key: 'user1:home_feed', payload: 'x');
      await CacheSync.invalidate('user1:home_feed');
      expect(dao.rawRead('user1:home_feed'), isNull);
    });

    test('is a no-op for an absent key', () async {
      await expectLater(CacheSync.invalidate('ghost'), completes);
    });
  });

  group('CacheSync.invalidateAll', () {
    test('removes all entries', () async {
      await dao.write(key: 'user1:home_feed', payload: 'a');
      await dao.write(key: 'user1:followers', payload: 'b');
      await dao.write(key: 'user2:home_feed', payload: 'c');

      await CacheSync.invalidateAll();

      expect(dao.length, equals(0));
    });

    test('is a no-op when store is empty', () async {
      await expectLater(CacheSync.invalidateAll(), completes);
    });
  });

  group('CacheSync.invalidatePrefix', () {
    test('is a no-op for an absent prefix', () async {
      await expectLater(CacheSync.invalidatePrefix('ghost'), completes);
    });

    test('removes all entries with the given prefix', () async {
      await dao.write(key: 'user1:home_feed', payload: 'a');
      await dao.write(key: 'user1:my_followers', payload: 'b');
      await dao.write(key: 'user2:home_feed', payload: 'c');

      await CacheSync.invalidatePrefix('user1');

      expect(dao.rawRead('user1:home_feed'), isNull);
      expect(dao.rawRead('user1:my_followers'), isNull);
      expect(dao.rawRead('user2:home_feed'), equals('c'));
    });

    test('exact-key prefix removes prefixed siblings too', () async {
      await dao.write(key: 'abc', payload: 'a');
      await dao.write(key: 'abcdef', payload: 'b');

      await CacheSync.invalidatePrefix('abc');

      expect(dao.rawRead('abc'), isNull);
      expect(dao.rawRead('abcdef'), isNull);
    });

    test('non-prefix substring is preserved', () async {
      await dao.write(key: 'prefixed', payload: 'a');
      await dao.write(key: 'wrap_prefixed_inner', payload: 'b');

      await CacheSync.invalidatePrefix('prefix');

      expect(dao.rawRead('prefixed'), isNull);
      expect(dao.rawRead('wrap_prefixed_inner'), equals('b'));
    });

    test('asserts when prefix is empty', () async {
      await expectLater(
        () => CacheSync.invalidatePrefix(''),
        throwsA(isA<AssertionError>()),
      );
    });
  });
}
