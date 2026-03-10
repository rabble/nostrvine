import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists the user's preference for only showing Divine-hosted videos.
class DivineHostFilterService extends ChangeNotifier {
  DivineHostFilterService(this._prefs)
    : _showDivineHostedOnly = _prefs.getBool(_prefsKey) ?? false;

  static const String _prefsKey = 'show_divine_hosted_only';

  final SharedPreferences _prefs;
  bool _showDivineHostedOnly;

  bool get showDivineHostedOnly => _showDivineHostedOnly;

  Future<void> setShowDivineHostedOnly(bool value) async {
    if (_showDivineHostedOnly == value) return;

    await _prefs.setBool(_prefsKey, value);
    _showDivineHostedOnly = value;
    notifyListeners();
  }
}
