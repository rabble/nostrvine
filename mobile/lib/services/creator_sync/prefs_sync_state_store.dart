// ABOUTME: SharedPreferences-backed store of applied sync timestamps.
// ABOUTME: Scoped per account so sync cursors never cross identities.

import 'dart:convert';

import 'package:creator_sync/creator_sync.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists per-item applied [SyncItemState] values for one account.
class PrefsSyncStateStore implements SyncStateStore {
  /// Creates a [PrefsSyncStateStore] for [pubkeyHex].
  PrefsSyncStateStore(this._prefs, {required String pubkeyHex})
    : _pubkeyHex = pubkeyHex;

  final SharedPreferences _prefs;
  final String _pubkeyHex;

  static const String _keyPrefix = 'creator_sync_applied';

  String _keyFor(SyncItemKind kind) => '${_keyPrefix}_${kind.name}_$_pubkeyHex';

  /// A malformed root (bad JSON, or JSON that isn't an object) discards the
  /// whole cursor and returns an empty map: the next reconcile does a full
  /// pass, which is recoverable. A malformed *entry* inside an otherwise
  /// valid map is skipped individually so one corrupt dTag doesn't cost the
  /// rest of the library its cursor — the same per-record recovery
  /// [SyncIndexClient.fetch] applies to undecryptable remote records.
  ///
  /// Every field is type-checked with `is` before being handed to
  /// [SyncItemState.fromJson], rather than relying on its internal `as`
  /// casts and catching the resulting [TypeError] — this package's lints
  /// forbid catching [Error] subclasses, and validating up front means a
  /// corrupt entry is simply skipped instead of throwing at all.
  @override
  Future<Map<String, SyncItemState>> readApplied(SyncItemKind kind) async {
    final raw = _prefs.getString(_keyFor(kind));
    if (raw == null || raw.isEmpty) return {};

    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      return {};
    }
    if (decoded is! Map) return {};

    final applied = <String, SyncItemState>{};
    for (final entry in decoded.entries) {
      final key = entry.key;
      final value = entry.value;
      if (key is! String || value is! Map) continue;

      final itemJson = Map<String, dynamic>.from(value);
      if (itemJson['createdAt'] is! int || itemJson['bodyHash'] is! String) {
        continue;
      }
      applied[key] = SyncItemState.fromJson(itemJson);
    }
    return applied;
  }

  @override
  Future<void> writeApplied(
    SyncItemKind kind,
    Map<String, SyncItemState> applied,
  ) async {
    final encoded = {
      for (final entry in applied.entries) entry.key: entry.value.toJson(),
    };
    await _prefs.setString(_keyFor(kind), jsonEncode(encoded));
  }
}
