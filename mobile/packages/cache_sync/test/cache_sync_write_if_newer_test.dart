import 'dart:async';
import 'dart:convert';

import 'package:cache_sync/cache_sync.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_cache_dao.dart';

/// FakeCacheDao with a one-shot Completer that gates the **next** call to
/// [write], so tests can force two `writeIfNewer` calls to interleave
/// in a specific order.
class _BlockableCacheDao extends FakeCacheDao {
  Completer<void>? blockNextWrite;

  @override
  Future<void> write({
    required String key,
    required String payload,
    Duration? ttl,
  }) async {
    final block = blockNextWrite;
    blockNextWrite = null;
    if (block != null) await block.future;
    await super.write(key: key, payload: payload, ttl: ttl);
  }
}

/// FakeCacheDao whose [read] throws — used to pin the contract that
/// [CacheSync.writeIfNewer] rethrows storage-layer failures.
class _ReadThrowingCacheDao extends FakeCacheDao {
  @override
  Future<String?> read(String key) async => throw StateError('read boom');
}

class _StampedEvent {
  const _StampedEvent({required this.createdAt, required this.data});

  factory _StampedEvent.fromJson(String json) {
    final map = jsonDecode(json) as Map<String, dynamic>;
    return _StampedEvent(
      createdAt: map['created_at'] as int,
      data: map['data'] as String,
    );
  }

  final int createdAt;
  final String data;

  String toJson() => jsonEncode({'created_at': createdAt, 'data': data});
}

Future<bool> _writeIfNewer(FakeCacheDao dao, _StampedEvent value) {
  return CacheSync.writeIfNewer<_StampedEvent>(
    key: 'k',
    value: value,
    fromJson: _StampedEvent.fromJson,
    toJson: (e) => e.toJson(),
    versionOf: (e) => e.createdAt,
  );
}

void main() {
  late FakeCacheDao dao;

  setUp(() async {
    dao = FakeCacheDao();
    await CacheSync.init(dao: dao);
  });

  group('CacheSync.writeIfNewer', () {
    test('writes and returns true when no cached value exists', () async {
      final wrote = await _writeIfNewer(
        dao,
        const _StampedEvent(createdAt: 100, data: 'a'),
      );

      expect(wrote, isTrue);
      final cached = _StampedEvent.fromJson(dao.rawRead('k')!);
      expect(cached.data, equals('a'));
      expect(cached.createdAt, equals(100));
    });

    test('writes when cached value has an older version', () async {
      await dao.write(
        key: 'k',
        payload: const _StampedEvent(createdAt: 100, data: 'old').toJson(),
      );

      final wrote = await _writeIfNewer(
        dao,
        const _StampedEvent(createdAt: 200, data: 'new'),
      );

      expect(wrote, isTrue);
      final cached = _StampedEvent.fromJson(dao.rawRead('k')!);
      expect(cached.data, equals('new'));
      expect(cached.createdAt, equals(200));
    });

    test('skips when cached value has a newer version', () async {
      await dao.write(
        key: 'k',
        payload: const _StampedEvent(createdAt: 200, data: 'newer').toJson(),
      );

      final wrote = await _writeIfNewer(
        dao,
        const _StampedEvent(createdAt: 100, data: 'older'),
      );

      expect(wrote, isFalse);
      final cached = _StampedEvent.fromJson(dao.rawRead('k')!);
      expect(cached.data, equals('newer'));
      expect(cached.createdAt, equals(200));
    });

    test('skips when versions are equal', () async {
      await dao.write(
        key: 'k',
        payload: const _StampedEvent(createdAt: 100, data: 'first').toJson(),
      );

      final wrote = await _writeIfNewer(
        dao,
        const _StampedEvent(createdAt: 100, data: 'second'),
      );

      expect(wrote, isFalse);
      final cached = _StampedEvent.fromJson(dao.rawRead('k')!);
      expect(cached.data, equals('first'));
    });

    test('overwrites corrupted cached payloads', () async {
      await dao.write(key: 'k', payload: '{this is not valid json');

      final wrote = await _writeIfNewer(
        dao,
        const _StampedEvent(createdAt: 100, data: 'fresh'),
      );

      expect(wrote, isTrue);
      final cached = _StampedEvent.fromJson(dao.rawRead('k')!);
      expect(cached.data, equals('fresh'));
    });

    test('respects empty toJson by skipping the write', () async {
      final wrote = await CacheSync.writeIfNewer<_StampedEvent>(
        key: 'k',
        value: const _StampedEvent(createdAt: 100, data: 'a'),
        fromJson: _StampedEvent.fromJson,
        toJson: (_) => '',
        versionOf: (e) => e.createdAt,
      );

      expect(wrote, isFalse);
      expect(dao.rawRead('k'), isNull);
    });

    test('persists the provided TTL on write', () async {
      await CacheSync.writeIfNewer<_StampedEvent>(
        key: 'k',
        value: const _StampedEvent(createdAt: 100, data: 'a'),
        fromJson: _StampedEvent.fromJson,
        toJson: (e) => e.toJson(),
        versionOf: (e) => e.createdAt,
        ttl: const Duration(milliseconds: 5),
      );

      // Read immediately — still fresh.
      expect(await dao.read('k'), isNotNull);

      await Future<void>.delayed(const Duration(milliseconds: 15));

      // TTL expired — read returns null and clears the entry.
      expect(await dao.read('k'), isNull);
    });

    test(
      'serializes concurrent writers on the same key — newer wins '
      'regardless of completion order',
      () async {
        // Reproduces the TOCTOU race the per-key mutex guards against.
        // Without serialization, the older value would land last and
        // overwrite the newer one because both readers would see the
        // empty cache before either had written.
        final blockingDao = _BlockableCacheDao();
        await CacheSync.init(dao: blockingDao);
        final blockOlder = Completer<void>();
        blockingDao.blockNextWrite = blockOlder;

        // Caller A: writes the OLDER value but its write is blocked.
        final futureA = CacheSync.writeIfNewer<_StampedEvent>(
          key: 'shared',
          value: const _StampedEvent(createdAt: 100, data: 'older'),
          fromJson: _StampedEvent.fromJson,
          toJson: (e) => e.toJson(),
          versionOf: (e) => e.createdAt,
        );

        // Give A a chance to reach its blocked write.
        await Future<void>.delayed(Duration.zero);

        // Caller B: tries to write the NEWER value while A is blocked.
        // With the mutex, B queues behind A and reads the cache only
        // AFTER A's write lands — so B sees `older` and overwrites it
        // with `newer`. Without the mutex, B would also see an empty
        // cache, write `newer` immediately, then A would unblock and
        // clobber it with `older`.
        final futureB = CacheSync.writeIfNewer<_StampedEvent>(
          key: 'shared',
          value: const _StampedEvent(createdAt: 200, data: 'newer'),
          fromJson: _StampedEvent.fromJson,
          toJson: (e) => e.toJson(),
          versionOf: (e) => e.createdAt,
        );

        await Future<void>.delayed(Duration.zero);
        blockOlder.complete();
        await Future.wait([futureA, futureB]);

        final cached = _StampedEvent.fromJson(blockingDao.rawRead('shared')!);
        expect(cached.createdAt, equals(200));
        expect(cached.data, equals('newer'));
      },
    );

    test('rethrows storage failures from the underlying DAO read', () async {
      await CacheSync.init(dao: _ReadThrowingCacheDao());

      await expectLater(
        () => CacheSync.writeIfNewer<_StampedEvent>(
          key: 'k',
          value: const _StampedEvent(createdAt: 100, data: 'a'),
          fromJson: _StampedEvent.fromJson,
          toJson: (e) => e.toJson(),
          versionOf: (e) => e.createdAt,
        ),
        throwsA(isA<StateError>()),
      );
    });
  });
}
