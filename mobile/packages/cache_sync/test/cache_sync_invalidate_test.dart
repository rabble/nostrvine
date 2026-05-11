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
}
