// ABOUTME: In-memory ring buffer storing recent page load performance records
// ABOUTME: Provides queryable history for Developer Options and debugging

import 'dart:collection';

/// A single page load performance record.
class PageLoadRecord {
  PageLoadRecord({
    required this.screenName,
    required this.timestamp,
    this.contentVisibleMs,
    this.dataLoadedMs,
    this.dataMetrics = const {},
  });

  final String screenName;
  final DateTime timestamp;
  int? contentVisibleMs;
  int? dataLoadedMs;
  final Map<String, dynamic> dataMetrics;

  /// Whether data load was slow (>3s).
  bool get isDataLoadSlow => (dataLoadedMs ?? 0) > 3000;

  /// Whether content visible was slow (>1s).
  bool get isContentVisibleSlow => (contentVisibleMs ?? 0) > 1000;
}

/// Singleton ring buffer storing the last [maxRecords] page load records.
///
/// Used by [ScreenAnalyticsService] to record timing data and by
/// Developer Options to display on-device performance history.
class PageLoadHistory {
  factory PageLoadHistory() => _instance;
  PageLoadHistory._internal();
  static final PageLoadHistory _instance = PageLoadHistory._internal();

  static const int maxRecords = 50;

  final Queue<PageLoadRecord> _records = Queue<PageLoadRecord>();

  /// All records, most recent first.
  List<PageLoadRecord> get records => _records.toList().reversed.toList();

  /// Add or update a record for the given screen name.
  ///
  /// If a record for this screen already exists without a dataLoadedMs,
  /// it will be updated rather than creating a duplicate.
  void addOrUpdate(PageLoadRecord record) {
    // Check if there's a recent record for this screen that can be updated
    final existing = _findRecentRecord(record.screenName);
    if (existing != null) {
      // Update the existing record
      if (record.contentVisibleMs != null) {
        existing.contentVisibleMs = record.contentVisibleMs;
      }
      if (record.dataLoadedMs != null) {
        existing.dataLoadedMs = record.dataLoadedMs;
      }
      return;
    }

    _records.addLast(record);
    while (_records.length > maxRecords) {
      _records.removeFirst();
    }
  }

  /// Find a recent record for this screen that doesn't have dataLoadedMs yet.
  PageLoadRecord? _findRecentRecord(String screenName) {
    // Search from newest to oldest (end of queue)
    for (final record in _records.toList().reversed) {
      if (record.screenName == screenName && record.dataLoadedMs == null) {
        return record;
      }
      // Only look back ~5 seconds to avoid stale matches
      if (DateTime.now().difference(record.timestamp).inSeconds > 5) {
        break;
      }
    }
    return null;
  }

  /// Get the [count] most recent records.
  List<PageLoadRecord> getRecent(int count) {
    final all = records;
    return all.take(count).toList();
  }

  /// Get the [count] slowest records by dataLoadedMs.
  List<PageLoadRecord> getSlowest(int count) {
    final withData = records.where((r) => r.dataLoadedMs != null).toList()
      ..sort((a, b) => (b.dataLoadedMs ?? 0).compareTo(a.dataLoadedMs ?? 0));
    return withData.take(count).toList();
  }

  /// Get the average content-visible and data-loaded times for a screen.
  ({double? avgContentVisibleMs, double? avgDataLoadedMs}) getAverageForScreen(
    String screenName,
  ) {
    final screenRecords = records
        .where((r) => r.screenName == screenName)
        .toList();
    if (screenRecords.isEmpty) {
      return (avgContentVisibleMs: null, avgDataLoadedMs: null);
    }

    final contentVisible = screenRecords
        .where((r) => r.contentVisibleMs != null)
        .toList();
    final dataLoaded = screenRecords
        .where((r) => r.dataLoadedMs != null)
        .toList();

    final avgContent = contentVisible.isEmpty
        ? null
        : contentVisible
                  .map((r) => r.contentVisibleMs!)
                  .reduce((a, b) => a + b) /
              contentVisible.length;

    final avgData = dataLoaded.isEmpty
        ? null
        : dataLoaded.map((r) => r.dataLoadedMs!).reduce((a, b) => a + b) /
              dataLoaded.length;

    return (avgContentVisibleMs: avgContent, avgDataLoadedMs: avgData);
  }

  /// Clear all records (for testing).
  void clear() {
    _records.clear();
  }
}
