// ABOUTME: App-layer sink for the runtime SQLITE_CORRUPT reports raised by
// ABOUTME: db_client's Drift interceptor: persists the flag the next launch
// ABOUTME: salvages on, records the non-fatal, and drives the restart prompt.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unified_logger/unified_logger.dart';

/// Bridges runtime database corruption from db_client to the app.
///
/// db_client detects corruption but stays low-level: it neither persists state
/// nor talks to Crashlytics (see the reporter-port pattern in
/// `.claude/rules/error_handling.md`). This service owns both halves:
///
/// * **Now** — [isCorrupted] flips so the UI can ask the user to restart. The
///   database is unusable for the rest of the session either way; every
///   affected read keeps throwing until the process restarts.
/// * **Next launch** — [hasPendingRecovery] persists, and
///   `DatabaseEncryptionBootstrap` skips its reactive probe and salvages
///   unconditionally. Without this the probe would clear the database again
///   (its startup cleanup never reads the corrupt pages) and the user would be
///   stuck on the same broken database forever.
///
/// Recovery is not attempted in-session on purpose: the `AppDatabase` is a
/// keepAlive Riverpod singleton that most of the service graph holds live
/// subscriptions on, so swapping the file underneath it would mean tearing that
/// graph down and rebuilding it. A restart does the same thing safely.
class DatabaseCorruptionService {
  /// Creates a service persisting to [preferences].
  ///
  /// [recordError] reports the corruption as a non-fatal (wired to Crashlytics
  /// in `main`), so the corruption rate stays observable; it is optional
  /// because tests do not need telemetry.
  DatabaseCorruptionService({
    required SharedPreferences preferences,
    Future<void> Function(Object error, StackTrace stackTrace)? recordError,
  }) : _preferences = preferences,
       _recordError = recordError;

  /// SharedPreferences key for the cross-launch recovery flag. Versioned so a
  /// future change of semantics can introduce `.v2` without colliding.
  @visibleForTesting
  static const pendingRecoveryKey = 'db.corruption.pendingRecovery.v1';

  static const _logName = 'DatabaseCorruptionService';

  final SharedPreferences _preferences;
  final Future<void> Function(Object error, StackTrace stackTrace)?
  _recordError;

  final ValueNotifier<bool> _isCorrupted = ValueNotifier(false);

  /// Whether corruption surfaced during **this** session. Drives the restart
  /// prompt; never resets, because nothing repairs the open database in place.
  ValueListenable<bool> get isCorrupted => _isCorrupted;

  /// Whether a previous session hit corruption and the database still needs to
  /// be salvaged. Read by the startup bootstrap before the first open.
  bool get hasPendingRecovery =>
      _preferences.getBool(pendingRecoveryKey) ?? false;

  /// Clears the flag once the bootstrap has salvaged or recreated the database.
  ///
  /// Must run on **every** recovery outcome, including a failed salvage that
  /// fell through to the backup-and-recreate: a stuck flag would force a
  /// salvage attempt on every subsequent launch.
  Future<void> clearPendingRecovery() async {
    await _preferences.remove(pendingRecoveryKey);
  }

  /// Records that [error] surfaced on-disk corruption.
  ///
  /// Safe to call on every failing statement — a corrupt database usually
  /// throws from many of them. Only the first report per session does work; the
  /// rest are dropped so one broken page cannot spam Crashlytics.
  void report(Object error, StackTrace stackTrace) {
    if (_isCorrupted.value) return;
    _isCorrupted.value = true;

    Log.error(
      'Local database reported on-disk corruption at runtime. Recovery is '
      'scheduled for the next launch.',
      name: _logName,
      error: error,
      stackTrace: stackTrace,
    );
    unawaited(_persistPendingRecovery(error, stackTrace));
  }

  /// Persists the flag and reports the non-fatal. Best-effort on both counts:
  /// the database is already broken and the session is already surfacing the
  /// restart prompt, so an IO or telemetry failure here must not throw into
  /// whichever query happened to trip the corruption.
  Future<void> _persistPendingRecovery(
    Object error,
    StackTrace stackTrace,
  ) async {
    try {
      await _preferences.setBool(pendingRecoveryKey, true);
    } on Object catch (e) {
      Log.warning(
        'Could not persist the database recovery flag: $e',
        name: _logName,
      );
    }
    try {
      await _recordError?.call(error, stackTrace);
    } on Object catch (e) {
      Log.warning('Corruption reporting failed: $e', name: _logName);
    }
  }

  /// Releases the notifier. The service is an app-lifetime singleton, so this
  /// exists for tests and provider disposal.
  void dispose() => _isCorrupted.dispose();
}
