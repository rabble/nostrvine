import 'dart:async';

import 'package:cache_sync/cache_sync.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_cache_dao.dart';

void main() {
  late FakeCacheDao dao;

  setUp(() async {
    dao = FakeCacheDao();
    await CacheSync.init(dao: dao);
  });

  group('CacheSync.watchStream', () {
    test('emits only live results when cache is empty', () async {
      final events = await CacheSync.watchStream<int>(
        key: 'ws:empty',
        source: () => Stream.fromIterable([1, 2, 3]),
        fromJson: int.parse,
        toJson: (v) => '$v',
      ).toList();

      expect(events, hasLength(3));
      expect(events.map((e) => e.data), equals([1, 2, 3]));
      expect(events.every((e) => e.isLive), isTrue);
    });

    test('emits cached first then live events', () async {
      await dao.write(key: 'ws:hit', payload: '0');

      final events = await CacheSync.watchStream<int>(
        key: 'ws:hit',
        source: () => Stream.fromIterable([10, 20]),
        fromJson: int.parse,
        toJson: (v) => '$v',
      ).toList();

      expect(events[0].isLive, isFalse);
      expect(events[0].data, equals(0));
      expect(events.skip(1).map((e) => e.data), equals([10, 20]));
    });

    test('writes last live value to cache', () async {
      await CacheSync.watchStream<int>(
        key: 'ws:write',
        source: () => Stream.fromIterable([7, 8, 9]),
        fromJson: int.parse,
        toJson: (v) => '$v',
      ).drain<void>();

      expect(dao.rawRead('ws:write'), equals('9'));
    });

    test('does not write when toJson returns empty string', () async {
      await CacheSync.watchStream<int>(
        key: 'ws:skip',
        source: () => Stream.fromIterable([1]),
        fromJson: int.parse,
        toJson: (_) => '',
      ).drain<void>();

      expect(dao.rawRead('ws:skip'), isNull);
    });

    test('forwards source errors as stream errors', () async {
      final stream = CacheSync.watchStream<int>(
        key: 'ws:err',
        source: () => Stream<int>.error(StateError('bad')),
        fromJson: int.parse,
        toJson: (v) => '$v',
      );

      await expectLater(stream, emitsError(isA<StateError>()));
    });

    test('cacheOnly policy never subscribes to source', () async {
      await dao.write(key: 'ws:only', payload: '5');
      var subscribed = false;

      final events = await CacheSync.watchStream<int>(
        key: 'ws:only',
        source: () {
          subscribed = true;
          return Stream.fromIterable([999]);
        },
        fromJson: int.parse,
        toJson: (v) => '$v',
        policy: CacheFetchPolicy.cacheOnly,
      ).toList();

      expect(subscribed, isFalse);
      expect(events, hasLength(1));
      expect(events[0].data, equals(5));
    });

    test('networkOnly policy ignores cache', () async {
      await dao.write(key: 'ws:net', payload: '1');

      final events = await CacheSync.watchStream<int>(
        key: 'ws:net',
        source: () => Stream.fromIterable([2]),
        fromJson: int.parse,
        toJson: (v) => '$v',
        policy: CacheFetchPolicy.networkOnly,
      ).toList();

      expect(events, hasLength(1));
      expect(events[0].isLive, isTrue);
      expect(events[0].data, equals(2));
    });

    test('deletes corrupted cache entry and serves live events', () async {
      await dao.write(key: 'ws:corrupt', payload: 'NOT_AN_INT');

      final events = await CacheSync.watchStream<int>(
        key: 'ws:corrupt',
        source: () => Stream.fromIterable([42]),
        fromJson: int.parse,
        toJson: (v) => '$v',
      ).toList();

      // Corrupted cache is skipped; only live value is served.
      expect(events, hasLength(1));
      expect(events[0].isLive, isTrue);
      expect(events[0].data, equals(42));
      // Corrupted entry was deleted and replaced with the live value.
      expect(dao.rawRead('ws:corrupt'), equals('42'));
    });
  });
}
