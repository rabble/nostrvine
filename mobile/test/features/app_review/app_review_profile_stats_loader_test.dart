// ABOUTME: Tests refresh-first profile-stat loading for review eligibility.
// ABOUTME: Covers ordering and fail-closed error/timeout behavior.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:openvine/features/app_review/app_review_profile_stats_loader.dart';

void main() {
  const pubkey =
      '1111111111111111111111111111111111111111111111111111111111111111';
  final staleStats = ProfileStats(
    pubkey: pubkey,
    videoCount: 10,
    lastUpdated: DateTime(2026, 7, 25),
  );
  final freshStats = ProfileStats(
    pubkey: pubkey,
    videoCount: 11,
    lastUpdated: DateTime(2026, 7, 26),
  );

  group(AppReviewProfileStatsLoader, () {
    test('subscribes after refresh and returns the refreshed row', () async {
      final refreshCompleter = Completer<void>();
      var refreshed = false;
      var watcherSubscriptions = 0;
      const loader = AppReviewProfileStatsLoader();

      final result = loader.load(
        refresh: () async {
          await refreshCompleter.future;
          refreshed = true;
        },
        watch: () {
          watcherSubscriptions++;
          return Stream.value(refreshed ? freshStats : staleStats);
        },
      );

      expect(watcherSubscriptions, 0);
      refreshCompleter.complete();

      expect(await result, same(freshStats));
      expect(watcherSubscriptions, 1);
    });

    test('returns null when refresh fails', () async {
      const loader = AppReviewProfileStatsLoader();

      final result = await loader.load(
        refresh: () => Future<void>.error(StateError('refresh failed')),
        watch: () => Stream.value(freshStats),
      );

      expect(result, isNull);
    });

    test('returns null when the combined load times out', () async {
      final refreshCompleter = Completer<void>();
      const loader = AppReviewProfileStatsLoader(
        timeout: Duration(milliseconds: 1),
      );

      final result = await loader.load(
        refresh: () => refreshCompleter.future,
        watch: () => Stream.value(freshStats),
      );

      expect(result, isNull);
    });
  });
}
