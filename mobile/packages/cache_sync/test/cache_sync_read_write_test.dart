import 'package:cache_sync/cache_sync.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_cache_dao.dart';

void main() {
  late FakeCacheDao dao;

  setUp(() async {
    dao = FakeCacheDao();
    await CacheSync.init(dao: dao);
  });

  group('CacheSync.write', () {
    test('persists a value that read can return', () async {
      await CacheSync.write<int>(
        key: 'k',
        value: 7,
        toJson: (v) => '$v',
      );

      final value = await CacheSync.read<int>(
        key: 'k',
        fromJson: int.parse,
      );
      expect(value, equals(7));
    });

    test('does not persist when toJson returns an empty string', () async {
      await CacheSync.write<int>(
        key: 'k',
        value: 7,
        toJson: (_) => '',
      );

      expect(dao.rawRead('k'), isNull);
    });

    test('applies the provided ttl', () async {
      await CacheSync.write<int>(
        key: 'k',
        value: 7,
        toJson: (v) => '$v',
        ttl: const Duration(microseconds: 1),
      );

      await Future<void>.delayed(const Duration(milliseconds: 5));
      final value = await CacheSync.read<int>(key: 'k', fromJson: int.parse);
      expect(value, isNull);
    });
  });

  group('CacheSync.read', () {
    test('returns null for an absent key', () async {
      final value = await CacheSync.read<int>(key: 'nope', fromJson: int.parse);
      expect(value, isNull);
    });

    test('deletes and returns null on a corrupt entry', () async {
      await dao.write(key: 'k', payload: 'not-an-int');

      final value = await CacheSync.read<int>(key: 'k', fromJson: int.parse);

      expect(value, isNull);
      expect(dao.rawRead('k'), isNull);
    });
  });
}
