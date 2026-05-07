import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists the user's preference for only showing Divine-hosted videos.
///
/// Defaults to `true` so new installs only see videos served from
/// `*.divine.video` hosts that we can moderate. Users opt in to the
/// wider Nostr media-host space by toggling this off in Safety settings.
class DivineHostFilterService extends ChangeNotifier {
  DivineHostFilterService(this._prefs)
    : _showDivineHostedOnly = _prefs.getBool(_prefsKey) ?? true;

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
