import 'package:flutter/widgets.dart';

/// Mixin that provides memory pressure handling for video controllers.
///
/// Uses [WidgetsBindingObserver] to listen for system memory warnings
/// and triggers cleanup when the device is running low on memory.
mixin MemoryPressureHandler on ChangeNotifier {
  bool _isMemoryConstrained = false;
  _MemoryPressureObserver? _observer;

  /// Whether the system has reported memory pressure.
  bool get isMemoryConstrained => _isMemoryConstrained;

  /// Initialize memory pressure observation.
  /// Call this in your controller's constructor.
  void initMemoryPressureHandling() {
    _observer = _MemoryPressureObserver(
      onMemoryPressure: _handleMemoryPressure,
      onResumed: _handleResumed,
    );
    WidgetsBinding.instance.addObserver(_observer!);
  }

  /// Cleanup memory pressure observation.
  /// Call this in your controller's dispose method.
  void disposeMemoryPressureHandling() {
    if (_observer != null) {
      WidgetsBinding.instance.removeObserver(_observer!);
      _observer = null;
    }
  }

  void _handleMemoryPressure() {
    _isMemoryConstrained = true;
    onMemoryPressure();
    notifyListeners();
  }

  void _handleResumed() {
    // Reset memory constraint flag when app resumes
    _isMemoryConstrained = false;
  }

  /// Override to implement memory pressure response.
  /// This is called when the system reports low memory.
  void onMemoryPressure();
}

/// Internal observer class that handles the WidgetsBindingObserver callbacks.
class _MemoryPressureObserver with WidgetsBindingObserver {
  _MemoryPressureObserver({
    required this.onMemoryPressure,
    required this.onResumed,
  });
  final VoidCallback onMemoryPressure;
  final VoidCallback onResumed;

  @override
  void didHaveMemoryPressure() {
    onMemoryPressure();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      onResumed();
    }
  }
}
