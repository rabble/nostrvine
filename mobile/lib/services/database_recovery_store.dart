// ABOUTME: Persists the last local-database recovery outcome for support diagnostics.
// ABOUTME: Stores only an outcome and timestamp, never database contents or key material.

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:unified_logger/unified_logger.dart';

/// A completed operation that replaced or rebuilt the local database.
enum DatabaseRecoveryOutcome {
  salvaged,
  recreatedMissingKey,
  recreatedKeyLoss,
  recreatedCorrupt,
  recreatedAfterBootstrapFailure,
  recreatedUnreadable,
}

/// Durable, aggregate-only evidence that database recovery ran on this install.
class DatabaseRecoveryRecord {
  const DatabaseRecoveryRecord({
    required this.outcome,
    required this.occurredAt,
  });

  final DatabaseRecoveryOutcome outcome;
  final DateTime occurredAt;

  Map<String, dynamic> toDiagnostics() => {
    'outcome': outcome.name,
    'occurredAt': occurredAt.toUtc().toIso8601String(),
  };
}

/// SharedPreferences-backed storage for the latest database recovery record.
class DatabaseRecoveryStore {
  DatabaseRecoveryStore({
    required SharedPreferences preferences,
    DateTime Function()? now,
  }) : _preferences = preferences,
       _now = now ?? DateTime.now;

  static const _key = 'db.recovery.latest.v1';
  static const _logName = 'DatabaseRecoveryStore';

  final SharedPreferences _preferences;
  final DateTime Function() _now;

  Future<void> record(DatabaseRecoveryOutcome outcome) async {
    final value = jsonEncode({
      'outcome': outcome.name,
      'occurredAt': _now().toUtc().toIso8601String(),
    });
    final stored = await _preferences.setString(_key, value);
    if (!stored) {
      throw StateError('SharedPreferences rejected the recovery record');
    }
  }

  DatabaseRecoveryRecord? read() {
    final raw = _preferences.getString(_key);
    if (raw == null || raw.isEmpty) return null;

    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final outcomeName = json['outcome'] as String;
      final occurredAt = DateTime.parse(json['occurredAt'] as String);
      final outcome = DatabaseRecoveryOutcome.values.byName(outcomeName);
      return DatabaseRecoveryRecord(outcome: outcome, occurredAt: occurredAt);
    } on Object catch (error) {
      Log.warning(
        'Ignoring an unreadable database recovery record: $error',
        name: _logName,
        category: LogCategory.system,
      );
      return null;
    }
  }
}
