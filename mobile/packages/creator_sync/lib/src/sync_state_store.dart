// ABOUTME: Tracks what this device last applied or published per sync item.
// ABOUTME: Timestamp suppresses echoes; body hash catches failed edits.

import 'dart:convert';

import 'package:creator_sync/src/sync_item_ref.dart';
import 'package:crypto/crypto.dart';
import 'package:meta/meta.dart';

/// Returns a stable sha256 hex digest of [body].
///
/// Map keys are sorted recursively before encoding so two semantically
/// identical bodies cannot hash differently purely because Dart iterated
/// their keys in a different order. List order stays significant.
String syncBodyHash(Map<String, dynamic> body) =>
    sha256.convert(utf8.encode(jsonEncode(_canonical(body)))).toString();

Object? _canonical(Object? value) {
  if (value is Map) {
    final keys = value.keys.map((k) => k.toString()).toList()..sort();
    return {for (final key in keys) key: _canonical(value[key])};
  }
  if (value is List) return value.map(_canonical).toList();
  return value;
}

/// What this device last applied or published for one item.
@immutable
class SyncItemState {
  /// Creates a [SyncItemState].
  const SyncItemState({required this.createdAt, required this.bodyHash});

  /// Rebuilds a [SyncItemState] from [json].
  factory SyncItemState.fromJson(Map<String, dynamic> json) => SyncItemState(
    createdAt: json['createdAt'] as int,
    bodyHash: json['bodyHash'] as String,
  );

  /// Body hash recorded for a tombstone, which carries no body.
  static const String tombstoneHash = '';

  /// `created_at` of the last event applied or published for this item.
  final int createdAt;

  /// [syncBodyHash] of the body last applied or published, or
  /// [tombstoneHash] for a deletion.
  final String bodyHash;

  /// Serializes this state for persistence.
  Map<String, dynamic> toJson() => {
    'createdAt': createdAt,
    'bodyHash': bodyHash,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SyncItemState &&
          other.createdAt == createdAt &&
          other.bodyHash == bodyHash;

  @override
  int get hashCode => Object.hash(createdAt, bodyHash);

  @override
  String toString() => 'SyncItemState($createdAt, $bodyHash)';
}

/// Persists, per item, the state this device last applied or published.
///
/// Implemented in the app layer over `SharedPreferences`; kept as an
/// interface so this package stays free of Flutter dependencies.
abstract interface class SyncStateStore {
  /// Returns a `dTag -> state` map for [kind].
  Future<Map<String, SyncItemState>> readApplied(SyncItemKind kind);

  /// Replaces the stored map for [kind] with [applied].
  Future<void> writeApplied(
    SyncItemKind kind,
    Map<String, SyncItemState> applied,
  );
}

/// Non-persistent [SyncStateStore] for tests and the E2E harness.
class InMemorySyncStateStore implements SyncStateStore {
  final Map<SyncItemKind, Map<String, SyncItemState>> _byKind = {};

  @override
  Future<Map<String, SyncItemState>> readApplied(SyncItemKind kind) async =>
      Map<String, SyncItemState>.from(_byKind[kind] ?? const {});

  @override
  Future<void> writeApplied(
    SyncItemKind kind,
    Map<String, SyncItemState> applied,
  ) async {
    _byKind[kind] = Map<String, SyncItemState>.from(applied);
  }
}
