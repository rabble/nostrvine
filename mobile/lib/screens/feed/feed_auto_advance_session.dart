import 'package:flutter/foundation.dart';

/// Feed-scoped runtime state for the Auto playback mode.
class FeedAutoAdvanceSession extends ChangeNotifier {
  bool _autoEnabled = false;
  bool _autoSuppressed = false;

  bool get autoEnabled => _autoEnabled;
  bool get autoSuppressed => _autoSuppressed;
  bool get isEffectivelyActive => _autoEnabled && !_autoSuppressed;

  void setEnabled(bool value) {
    if (_autoEnabled == value) return;

    _autoEnabled = value;
    if (!value) {
      _autoSuppressed = false;
    }
    notifyListeners();
  }

  void toggle() => setEnabled(!_autoEnabled);

  void suppressForInteraction() {
    if (!_autoEnabled || _autoSuppressed) return;

    _autoSuppressed = true;
    notifyListeners();
  }

  void resumeAfterSwipe() {
    if (!_autoEnabled || !_autoSuppressed) return;

    _autoSuppressed = false;
    notifyListeners();
  }
}
