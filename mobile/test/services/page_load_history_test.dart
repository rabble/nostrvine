import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/page_load_history.dart';

void main() {
  group(PageLoadHistory, () {
    late PageLoadHistory history;

    setUp(() {
      history = PageLoadHistory();
      history.clear();
    });

    tearDown(() {
      history.clear();
    });

    group('addOrUpdate', () {
      test('adds a new record', () {
        history.addOrUpdate(
          PageLoadRecord(
            screenName: 'home',
            timestamp: DateTime.now(),
            contentVisibleMs: 100,
          ),
        );

        expect(history.records, hasLength(1));
        expect(history.records.first.screenName, equals('home'));
        expect(history.records.first.contentVisibleMs, equals(100));
      });

      test('defaults to route source with no terminal result', () {
        final record = PageLoadRecord(
          screenName: 'home',
          timestamp: DateTime.now(),
        );

        expect(record.source, equals(PageLoadSource.route));
        expect(record.result, isNull);
      });

      test('updates existing record without dataLoadedMs', () {
        final now = DateTime.now();
        history.addOrUpdate(
          PageLoadRecord(
            screenName: 'home',
            timestamp: now,
            contentVisibleMs: 100,
          ),
        );

        history.addOrUpdate(
          PageLoadRecord(screenName: 'home', timestamp: now, dataLoadedMs: 500),
        );

        expect(history.records, hasLength(1));
        expect(history.records.first.contentVisibleMs, equals(100));
        expect(history.records.first.dataLoadedMs, equals(500));
      });

      test('adds new record when existing has dataLoadedMs', () {
        final now = DateTime.now();
        history.addOrUpdate(
          PageLoadRecord(
            screenName: 'home',
            timestamp: now,
            contentVisibleMs: 100,
            dataLoadedMs: 500,
          ),
        );

        history.addOrUpdate(
          PageLoadRecord(
            screenName: 'home',
            timestamp: now,
            contentVisibleMs: 80,
          ),
        );

        expect(history.records, hasLength(2));
      });

      test('enforces maxRecords limit', () {
        for (var i = 0; i < PageLoadHistory.maxRecords + 10; i++) {
          history.addOrUpdate(
            PageLoadRecord(
              screenName: 'screen_$i',
              timestamp: DateTime.now(),
              contentVisibleMs: i * 10,
              dataLoadedMs: i * 20,
            ),
          );
        }

        expect(history.records, hasLength(PageLoadHistory.maxRecords));
      });

      test('removes oldest records when over limit', () {
        for (var i = 0; i < PageLoadHistory.maxRecords + 5; i++) {
          history.addOrUpdate(
            PageLoadRecord(
              screenName: 'screen_$i',
              timestamp: DateTime.now(),
              contentVisibleMs: i,
              dataLoadedMs: i,
            ),
          );
        }

        // Oldest records (0-4) should be gone, newest should be present
        final names = history.records.map((r) => r.screenName).toList();
        expect(names, isNot(contains('screen_0')));
        expect(names, contains('screen_${PageLoadHistory.maxRecords + 4}'));
      });

      test('adds terminal surface records to recent history', () {
        final startedAt = DateTime(2026, 6, 12, 12);

        history.addOrUpdate(
          PageLoadRecord(
            screenName: 'comments_sheet',
            timestamp: startedAt,
            contentVisibleMs: 80,
            result: 'dismissed',
            source: PageLoadSource.surface,
          ),
        );
        history.addOrUpdate(
          PageLoadRecord(
            screenName: 'comments_sheet',
            timestamp: startedAt.add(const Duration(seconds: 1)),
            contentVisibleMs: 60,
            dataLoadedMs: 420,
            result: 'success',
            source: PageLoadSource.surface,
          ),
        );

        final recent = history.getRecent(2);
        expect(recent, hasLength(2));
        expect(recent.first.source, equals(PageLoadSource.surface));
        expect(recent.first.result, equals('success'));
        expect(recent.last.result, equals('dismissed'));
      });

      test('unrelated stale surface record does not block route update', () {
        final now = DateTime.now();
        history.addOrUpdate(
          PageLoadRecord(
            screenName: 'home',
            timestamp: now,
            contentVisibleMs: 120,
          ),
        );
        history.addOrUpdate(
          PageLoadRecord(
            screenName: 'comments_sheet',
            timestamp: now.subtract(const Duration(seconds: 10)),
            contentVisibleMs: 80,
            result: 'dismissed',
            source: PageLoadSource.surface,
          ),
        );

        history.addOrUpdate(
          PageLoadRecord(
            screenName: 'home',
            timestamp: now,
            dataLoadedMs: 450,
          ),
        );

        final routeRecords = history.records
            .where((record) => record.source == PageLoadSource.route)
            .toList();
        expect(routeRecords, hasLength(1));
        expect(routeRecords.single.screenName, equals('home'));
        expect(routeRecords.single.contentVisibleMs, equals(120));
        expect(routeRecords.single.dataLoadedMs, equals(450));
        expect(history.records, hasLength(2));
      });
    });

    group('records', () {
      test('returns records in most-recent-first order', () {
        for (var i = 0; i < 3; i++) {
          history.addOrUpdate(
            PageLoadRecord(
              screenName: 'screen_$i',
              timestamp: DateTime.now().add(Duration(seconds: i)),
              contentVisibleMs: 100,
              dataLoadedMs: 200,
            ),
          );
        }

        final records = history.records;
        expect(records.first.screenName, equals('screen_2'));
        expect(records.last.screenName, equals('screen_0'));
      });
    });

    group('getRecent', () {
      test('returns requested number of records', () {
        for (var i = 0; i < 10; i++) {
          history.addOrUpdate(
            PageLoadRecord(
              screenName: 'screen_$i',
              timestamp: DateTime.now(),
              contentVisibleMs: 100,
              dataLoadedMs: 200,
            ),
          );
        }

        final recent = history.getRecent(3);
        expect(recent, hasLength(3));
      });

      test('returns all records when count exceeds total', () {
        history.addOrUpdate(
          PageLoadRecord(
            screenName: 'home',
            timestamp: DateTime.now(),
            contentVisibleMs: 100,
            dataLoadedMs: 200,
          ),
        );

        final recent = history.getRecent(10);
        expect(recent, hasLength(1));
      });
    });

    group('getSlowest', () {
      test('returns records sorted by dataLoadedMs descending', () {
        history.addOrUpdate(
          PageLoadRecord(
            screenName: 'fast',
            timestamp: DateTime.now(),
            dataLoadedMs: 100,
          ),
        );
        history.addOrUpdate(
          PageLoadRecord(
            screenName: 'slow',
            timestamp: DateTime.now(),
            dataLoadedMs: 5000,
          ),
        );
        history.addOrUpdate(
          PageLoadRecord(
            screenName: 'medium',
            timestamp: DateTime.now(),
            dataLoadedMs: 1500,
          ),
        );

        final slowest = history.getSlowest(3);
        expect(slowest, hasLength(3));
        expect(slowest[0].screenName, equals('slow'));
        expect(slowest[1].screenName, equals('medium'));
        expect(slowest[2].screenName, equals('fast'));
      });

      test('excludes records without dataLoadedMs', () {
        history.addOrUpdate(
          PageLoadRecord(
            screenName: 'no_data',
            timestamp: DateTime.now(),
            contentVisibleMs: 100,
          ),
        );
        history.addOrUpdate(
          PageLoadRecord(
            screenName: 'with_data',
            timestamp: DateTime.now(),
            dataLoadedMs: 500,
          ),
        );

        final slowest = history.getSlowest(5);
        expect(slowest, hasLength(1));
        expect(slowest.first.screenName, equals('with_data'));
      });

      test('includes surface records with dataLoadedMs', () {
        history.addOrUpdate(
          PageLoadRecord(
            screenName: 'home',
            timestamp: DateTime.now(),
            dataLoadedMs: 500,
          ),
        );
        history.addOrUpdate(
          PageLoadRecord(
            screenName: 'comments_sheet',
            timestamp: DateTime.now(),
            dataLoadedMs: 3500,
            result: 'success',
            source: PageLoadSource.surface,
          ),
        );

        final slowest = history.getSlowest(1);
        expect(slowest.single.screenName, equals('comments_sheet'));
        expect(slowest.single.source, equals(PageLoadSource.surface));
        expect(slowest.single.result, equals('success'));
      });

      test('excludes dismissed surface records without dataLoadedMs', () {
        history.addOrUpdate(
          PageLoadRecord(
            screenName: 'comments_sheet',
            timestamp: DateTime.now(),
            contentVisibleMs: 75,
            result: 'dismissed',
            source: PageLoadSource.surface,
          ),
        );
        history.addOrUpdate(
          PageLoadRecord(
            screenName: 'home',
            timestamp: DateTime.now(),
            dataLoadedMs: 900,
          ),
        );

        final slowest = history.getSlowest(5);
        expect(slowest, hasLength(1));
        expect(slowest.single.screenName, equals('home'));
      });
    });

    group('getAverageForScreen', () {
      test('returns averages for a screen with multiple records', () {
        // Add records with dataLoadedMs so they don't get merged
        history.addOrUpdate(
          PageLoadRecord(
            screenName: 'home',
            timestamp: DateTime.now(),
            contentVisibleMs: 100,
            dataLoadedMs: 500,
          ),
        );
        history.addOrUpdate(
          PageLoadRecord(
            screenName: 'home',
            timestamp: DateTime.now(),
            contentVisibleMs: 200,
            dataLoadedMs: 1000,
          ),
        );

        final avg = history.getAverageForScreen('home');
        expect(avg.avgContentVisibleMs, equals(150.0));
        expect(avg.avgDataLoadedMs, equals(750.0));
      });

      test('returns nulls for unknown screen', () {
        final avg = history.getAverageForScreen('unknown');
        expect(avg.avgContentVisibleMs, isNull);
        expect(avg.avgDataLoadedMs, isNull);
      });

      test('returns null for metric when no records have it', () {
        history.addOrUpdate(
          PageLoadRecord(
            screenName: 'home',
            timestamp: DateTime.now(),
            contentVisibleMs: 100,
            dataLoadedMs: 200,
          ),
        );

        // Add a record with only contentVisibleMs (no dataLoadedMs)
        // Since we already have a record with dataLoadedMs, this will be a new one
        history.addOrUpdate(
          PageLoadRecord(
            screenName: 'partial',
            timestamp: DateTime.now(),
            contentVisibleMs: 300,
          ),
        );

        final avg = history.getAverageForScreen('partial');
        expect(avg.avgContentVisibleMs, equals(300.0));
        expect(avg.avgDataLoadedMs, isNull);
      });
    });

    group('clear', () {
      test('removes all records', () {
        history.addOrUpdate(
          PageLoadRecord(
            screenName: 'home',
            timestamp: DateTime.now(),
            contentVisibleMs: 100,
          ),
        );

        history.clear();
        expect(history.records, isEmpty);
      });
    });
  });

  group(PageLoadRecord, () {
    test('isDataLoadSlow returns true for >3s', () {
      final record = PageLoadRecord(
        screenName: 'test',
        timestamp: DateTime.now(),
        dataLoadedMs: 3001,
      );
      expect(record.isDataLoadSlow, isTrue);
    });

    test('isDataLoadSlow returns false for <=3s', () {
      final record = PageLoadRecord(
        screenName: 'test',
        timestamp: DateTime.now(),
        dataLoadedMs: 3000,
      );
      expect(record.isDataLoadSlow, isFalse);
    });

    test('isDataLoadSlow returns false when null', () {
      final record = PageLoadRecord(
        screenName: 'test',
        timestamp: DateTime.now(),
      );
      expect(record.isDataLoadSlow, isFalse);
    });

    test('isContentVisibleSlow returns true for >1s', () {
      final record = PageLoadRecord(
        screenName: 'test',
        timestamp: DateTime.now(),
        contentVisibleMs: 1001,
      );
      expect(record.isContentVisibleSlow, isTrue);
    });

    test('isContentVisibleSlow returns false for <=1s', () {
      final record = PageLoadRecord(
        screenName: 'test',
        timestamp: DateTime.now(),
        contentVisibleMs: 1000,
      );
      expect(record.isContentVisibleSlow, isFalse);
    });
  });
}
