// ABOUTME: Tests for AppEngagementStore session counter + first-launch stamp.
// ABOUTME: Verifies idempotent increment behavior and clock injection.

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/app_engagement_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group(AppEngagementStore, () {
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      prefs = await SharedPreferences.getInstance();
    });

    group('sessionCount', () {
      test('is 0 before recordSession runs', () {
        final store = AppEngagementStore(sharedPreferences: prefs);
        expect(store.sessionCount, 0);
      });

      test('becomes 1 after the first recordSession', () async {
        final store = AppEngagementStore(sharedPreferences: prefs);
        await store.recordSession();
        expect(store.sessionCount, 1);
      });

      test('increments across multiple recordSession calls', () async {
        final store = AppEngagementStore(sharedPreferences: prefs);
        await store.recordSession();
        await store.recordSession();
        await store.recordSession();
        expect(store.sessionCount, 3);
      });

      test(
        'reads a previously-persisted count on a new store instance',
        () async {
          await AppEngagementStore(sharedPreferences: prefs).recordSession();
          await AppEngagementStore(sharedPreferences: prefs).recordSession();

          // A fresh store (simulating a later cold start) reads the persisted count.
          final laterStore = AppEngagementStore(sharedPreferences: prefs);
          expect(laterStore.sessionCount, 2);
        },
      );
    });

    group('firstLaunchAt', () {
      test('is null before recordSession runs', () {
        final store = AppEngagementStore(sharedPreferences: prefs);
        expect(store.firstLaunchAt, isNull);
      });

      test(
        'is stamped on the first recordSession and never overwritten',
        () async {
          final first = DateTime(2026, 1, 15);
          final store = AppEngagementStore(
            sharedPreferences: prefs,
            now: () => first,
          );
          await store.recordSession();
          expect(store.firstLaunchAt, first);

          // A later session with a different clock must NOT overwrite the stamp.
          final laterStore = AppEngagementStore(
            sharedPreferences: prefs,
            now: () => DateTime(2026, 7, 25),
          );
          await laterStore.recordSession();
          expect(laterStore.firstLaunchAt, first);
        },
      );
    });

    group('daysSinceFirstLaunch', () {
      test('is 0 when no first-launch stamp exists', () {
        final store = AppEngagementStore(sharedPreferences: prefs);
        expect(store.daysSinceFirstLaunch(), 0);
      });

      test('computes whole days between first launch and now', () async {
        final firstLaunch = DateTime(2026, 1, 15);
        final store = AppEngagementStore(
          sharedPreferences: prefs,
          now: () => firstLaunch,
        );
        await store.recordSession();

        final tenDaysLater = AppEngagementStore(
          sharedPreferences: prefs,
          now: () => firstLaunch.add(const Duration(days: 10, hours: 12)),
        );
        // 10.5 days floors to 10.
        expect(tenDaysLater.daysSinceFirstLaunch(), 10);
      });

      test('honors an explicit now override', () async {
        final firstLaunch = DateTime(2026, 1, 15);
        final store = AppEngagementStore(
          sharedPreferences: prefs,
          now: () => firstLaunch,
        );
        await store.recordSession();

        final evaluationNow = firstLaunch.add(const Duration(days: 30));
        expect(
          store.daysSinceFirstLaunch(now: evaluationNow),
          30,
        );
      });
    });
  });
}
