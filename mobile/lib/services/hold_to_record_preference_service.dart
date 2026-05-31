// ABOUTME: Persists whether pressing the record button starts recording.
// ABOUTME: Controls the optional hold-to-record camera gesture.

import 'package:shared_preferences/shared_preferences.dart';

/// Service for managing the hold-to-record camera gesture preference.
class HoldToRecordPreferenceService {
  HoldToRecordPreferenceService(this._prefs)
    : _isHoldToRecordEnabled = _prefs.getBool(prefsKey) ?? false;

  /// SharedPreferences key for the hold-to-record preference.
  static const String prefsKey = 'hold_to_record_enabled';

  final SharedPreferences _prefs;
  bool _isHoldToRecordEnabled;

  /// Whether pressing the record button records until release.
  bool get isHoldToRecordEnabled => _isHoldToRecordEnabled;

  /// Sets whether pressing the record button records until release.
  Future<void> setHoldToRecordEnabled(bool enabled) async {
    await _prefs.setBool(prefsKey, enabled);
    _isHoldToRecordEnabled = enabled;
  }
}
