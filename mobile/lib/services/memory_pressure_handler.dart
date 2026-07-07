// ABOUTME: Fans a memory-pressure signal out to load-shedding actions
// ABOUTME: Clears the image cache and sheds low-priority ingestion backlog

/// Coordinates the app's response to an OS memory-pressure signal.
///
/// Both actions are injected so the handler stays free of Flutter and service
/// dependencies and is trivially testable. Production wiring supplies an image
/// cache clear and an [EventRouter]-backed ingestion shed.
class MemoryPressureHandler {
  MemoryPressureHandler({
    required void Function() clearImageCache,
    required void Function() shedIngestion,
  }) : _clearImageCache = clearImageCache,
       _shedIngestion = shedIngestion;

  final void Function() _clearImageCache;
  final void Function() _shedIngestion;

  /// Sheds load in response to memory pressure by clearing the image cache
  /// and dropping low-priority ingestion backlog.
  void onMemoryPressure() {
    _clearImageCache();
    _shedIngestion();
  }
}
