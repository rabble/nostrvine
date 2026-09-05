// ABOUTME: Observes memory pressure before fanning it out to shedding actions
// ABOUTME: Clears the image cache and sheds low-priority ingestion backlog

/// Coordinates the app's response to an OS memory-pressure signal.
///
/// Every signal is observed before either shedding action runs, preserving the
/// pre-shed gauges for diagnostics. All callbacks are injected so the handler
/// stays free of Flutter and service dependencies and is trivially testable.
class MemoryPressureHandler {
  MemoryPressureHandler({
    required void Function() clearImageCache,
    required void Function() shedIngestion,
    required void Function(int eventCount) onPressureObserved,
  }) : _clearImageCache = clearImageCache,
       _onPressureObserved = onPressureObserved,
       _shedIngestion = shedIngestion;

  final void Function() _clearImageCache;
  final void Function(int eventCount) _onPressureObserved;
  final void Function() _shedIngestion;
  int _eventCount = 0;

  /// Records the signal, then clears the image cache and drops low-priority
  /// ingestion backlog.
  void onMemoryPressure() {
    _eventCount += 1;
    try {
      _onPressureObserved(_eventCount);
    } finally {
      try {
        _clearImageCache();
      } finally {
        _shedIngestion();
      }
    }
  }
}
