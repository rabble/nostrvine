// ABOUTME: Loads profile statistics for review eligibility after a refresh.
// ABOUTME: Bounds the combined refresh/read operation and fails closed.

import 'package:models/models.dart';

/// Refreshes profile data before reading the current cached statistics row.
class AppReviewProfileStatsLoader {
  const AppReviewProfileStatsLoader({
    this.timeout = const Duration(seconds: 3),
  });

  final Duration timeout;

  Future<ProfileStats?> load({
    required Future<void> Function() refresh,
    required Stream<ProfileStats?> Function() watch,
  }) async {
    try {
      return await (() async {
        await refresh();
        return watch()
            .where((stats) => stats != null)
            .cast<ProfileStats>()
            .first;
      })().timeout(timeout);
    } on Object {
      return null;
    }
  }
}
