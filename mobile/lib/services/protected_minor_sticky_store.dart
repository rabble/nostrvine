// ABOUTME: Persists last-known protected-minor status per account and applies
// ABOUTME: the #175 fail-safe machine (sticky; lifts only on a positive signal).

import 'package:openvine/models/protected_minor_status.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Durable, per-account last-known protected-minor state.
///
/// Reads/writes a synchronous [SharedPreferences] snapshot so the value is
/// valid at cold start (local, no network). The fail-safe machine only ever
/// lifts protection on a confirmed not-a-minor signal; unknown/error is sticky.
class ProtectedMinorStickyStore {
  ProtectedMinorStickyStore({required SharedPreferences prefs})
    : _prefs = prefs;

  final SharedPreferences _prefs;

  static String _key(String pubkey) => 'protected_minor_sticky_$pubkey';

  /// Last-known protected status for [pubkey]. Null/unconfirmed -> false.
  bool isProtectedMinorFor(String? pubkey) =>
      pubkey != null && (_prefs.getBool(_key(pubkey)) ?? false);

  /// Apply a live keycast status: confirmed protected -> persist true;
  /// confirmed not-protected -> persist false; unknown -> retain. A write is
  /// skipped when the persisted value already matches (avoids redundant I/O on
  /// every rebuild).
  Future<void> applyLiveStatus(
    String? pubkey,
    ProtectedMinorStatus status,
  ) async {
    if (pubkey == null) return;
    final bool? next = switch (status.kind) {
      ProtectedMinorStatusKind.protected => true,
      ProtectedMinorStatusKind.notProtected => false,
      ProtectedMinorStatusKind.unknown => null, // retain last-known
    };
    if (next == null) return;
    if (_prefs.getBool(_key(pubkey)) == next) return;
    await _prefs.setBool(_key(pubkey), next);
  }
}
