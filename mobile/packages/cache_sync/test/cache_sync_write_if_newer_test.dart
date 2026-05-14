import 'dart:convert';

import 'package:cache_sync/cache_sync.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_cache_dao.dart';

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
  });
}
