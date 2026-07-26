// ABOUTME: SharedPreferences-backed install-scoped engagement counters used
// ABOUTME: by the in-app review gate to confirm sustained app use.

import 'package:shared_preferences/shared_preferences.dart';

/// SharedPreferences-backed, install-scoped engagement counters.
///
/// These track *device install* engagement (not per-user), since "is this
/// person actively using the app" is an install-level signal that should
/// survive account switches. The review gate consumes them alongside a
/// per-user cooldown and a server-authoritative video count.
class AppEngagementStore {
  AppEngagementStore({
    required SharedPreferences sharedPreferences,
    DateTime Function()? now,
  }) : _prefs = sharedPreferences,
       _now = now ?? DateTime.now;

  final SharedPreferences _prefs;
  final DateTime Function() _now;

  /// SharedPreferences keys.
  static const sessionCountKey = 'app_session_count';
  static const firstLaunchAtKey = 'app_first_launch_at';

  /// Number of cold starts this install has recorded.
  ///
  /// Returns 0 before [recordSession] runs for the first time.
  int get sessionCount => _prefs.getInt(sessionCountKey) ?? 0;

  /// Wall-clock timestamp of the first cold start on this install, or `null`
  /// if [recordSession] has never run.
  DateTime? get firstLaunchAt {
    final millis = _prefs.getInt(firstLaunchAtKey);
    return millis == null ? null : DateTime.fromMillisecondsSinceEpoch(millis);
  }

  /// Whole days elapsed since the first cold start, or 0 if unset.
  int daysSinceFirstLaunch({DateTime? now}) {
    final first = firstLaunchAt;
    if (first == null) return 0;
    return (now ?? _now()).difference(first).inDays;
  }

  /// Records a single cold start: bumps the session counter and, if this is
  /// the first launch, stamps the install's first-launch timestamp.
  ///
  /// Idempotent per cold start — call exactly once during startup, before
  /// `runApp`. Safe to call again; it will over-count.
  Future<void> recordSession() async {
    final isFirstLaunch = !_prefs.containsKey(firstLaunchAtKey);
    if (isFirstLaunch) {
      await _prefs.setInt(
        firstLaunchAtKey,
        _now().millisecondsSinceEpoch,
      );
    }
    await _prefs.setInt(sessionCountKey, sessionCount + 1);
  }
}
