// ABOUTME: Developer-only local override for simulating the protected-minor
// ABOUTME: (13-15) state without a real approved-minor account. Debug builds only.

import 'package:shared_preferences/shared_preferences.dart';

/// Stores a debug-only override for the protected-minor state so QA can
/// exercise the #175/#176 protections without a real approved-minor account.
///
/// `null` means "no override" (use the real Keycast flag); `true`/`false`
/// force protected / not-protected respectively.
class ProtectedMinorOverrideService {
  ProtectedMinorOverrideService({required SharedPreferences prefs})
    : _prefs = prefs;

  static const _prefsKey = 'protected_minor_override';

  final SharedPreferences _prefs;

  bool? getOverride() => _prefs.getBool(_prefsKey);

  Future<void> setOverride(bool isProtectedMinor) =>
      _prefs.setBool(_prefsKey, isProtectedMinor);

  Future<void> clearOverride() => _prefs.remove(_prefsKey);
}
