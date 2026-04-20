// ABOUTME: Hive-backed local cache for NIP-51 kind 30000 people lists.
// ABOUTME: Scopes entries by owner pubkey and enforces deletion tombstones.

import 'dart:async';
import 'dart:developer' as developer;

import 'package:hive_ce/hive_ce.dart';
import 'package:models/models.dart';

/// Key prefix constants and JSON field names for the Hive box.
abstract class _CacheKeys {
  static const String listPrefix = 'list:';
  static const String deletedPrefix = 'deleted:';
  static const String keySeparator = ':';

  static const String ownerPubkey = 'ownerPubkey';
  static const String list = 'list';
  static const String receivedAtMillis = 'receivedAtMillis';
  static const String deletedAtMillis = 'deletedAtMillis';
}

/// Logger name used for cache-level diagnostic log entries.
const String _logName = 'people_lists_repository.local_cache';

/// Log level used for recoverable, non-fatal decode failures.
///
/// `dart:developer`'s convention is 900 for WARNING.
const int _logLevelWarning = 900;

/// Local cache for kind 30000 people lists, scoped by owner pubkey.
///
/// The cache stores list records under keys of the form
/// `list:<ownerPubkey>:<listId>` and deletion tombstones under
/// `deleted:<ownerPubkey>:<listId>`. A tombstone hides a list when
/// `deletedAtMillis >= list.updatedAt.millisecondsSinceEpoch`; a recreated
/// list with a newer `updatedAt` can beat the tombstone and become visible
/// again.
class LocalPeopleListsCache {
  /// Creates a cache that lazily opens the backing Hive box via [openBox].
  ///
  /// The opener is invoked at most once per cache instance; subsequent calls
  /// reuse the cached [Box].
  LocalPeopleListsCache({required Future<Box<dynamic>> Function() openBox})
    : _openBox = openBox;

  final Future<Box<dynamic>> Function() _openBox;
  Future<Box<dynamic>>? _boxFuture;

  Future<Box<dynamic>> _box() => _boxFuture ??= _openBox();

  /// Returns all non-tombstoned lists owned by [ownerPubkey], sorted by
  /// `updatedAt` descending.
  ///
  /// Throws any error raised by the injected box opener (for example if the
  /// Hive box cannot be opened). Malformed individual rows are logged via
  /// `dart:developer` and skipped; they do not cause the call to throw.
  Future<List<UserList>> readLists({required String ownerPubkey}) async {
    final box = await _box();
    return _collectLists(box, ownerPubkey);
  }

  /// Emits the current lists for [ownerPubkey] immediately, then re-emits on
  /// each box mutation that affects this owner.
  ///
  /// If opening the Hive box fails, the error is forwarded onto the returned
  /// stream. Malformed individual rows are logged and skipped; they do not
  /// terminate the stream.
  Stream<List<UserList>> watchLists({required String ownerPubkey}) {
    late StreamController<List<UserList>> controller;
    StreamSubscription<BoxEvent>? subscription;

    Future<void> start() async {
      final box = await _box();
      if (controller.isClosed) return;
      controller.add(_collectLists(box, ownerPubkey));
      subscription = box.watch().listen((event) {
        final key = event.key;
        if (key is! String || !_keyBelongsToOwner(key, ownerPubkey)) {
          return;
        }
        controller.add(_collectLists(box, ownerPubkey));
      });
    }

    controller = StreamController<List<UserList>>(
      onListen: () {
        unawaited(start());
      },
      onCancel: () async {
        await subscription?.cancel();
        subscription = null;
      },
    );
    return controller.stream;
  }

  /// Persists [list] for [ownerPubkey] unless a tombstone with a later or
  /// equal timestamp already exists. [receivedAt] is stored alongside the
  /// record for diagnostics and future sync logic.
  ///
  /// Throws if the Hive box cannot be opened or the underlying write fails.
  Future<void> putList({
    required String ownerPubkey,
    required UserList list,
    required DateTime receivedAt,
  }) async {
    final box = await _box();
    final tombstoneMillis = _tombstoneMillis(box, ownerPubkey, list.id);
    if (tombstoneMillis != null &&
        tombstoneMillis >= list.updatedAt.millisecondsSinceEpoch) {
      return;
    }
    await box.put(_listKey(ownerPubkey, list.id), <String, dynamic>{
      _CacheKeys.ownerPubkey: ownerPubkey,
      _CacheKeys.list: list.toJson(),
      _CacheKeys.receivedAtMillis: receivedAt.millisecondsSinceEpoch,
    });
  }

  /// Persists every entry in [lists] via [putList], sharing the same
  /// [receivedAt] timestamp.
  ///
  /// Throws if the Hive box cannot be opened or any underlying write fails.
  /// A partial failure leaves previously written entries in the box.
  Future<void> putLists({
    required String ownerPubkey,
    required Iterable<UserList> lists,
    required DateTime receivedAt,
  }) async {
    for (final list in lists) {
      await putList(
        ownerPubkey: ownerPubkey,
        list: list,
        receivedAt: receivedAt,
      );
    }
  }

  /// Records a tombstone for [listId] at [deletedAt] and removes any existing
  /// list record whose `updatedAt` is older than or equal to [deletedAt].
  ///
  /// A later recreation with a strictly newer `updatedAt` will replace the
  /// tombstone when written via [putList].
  ///
  /// Throws if the Hive box cannot be opened or an underlying write fails.
  Future<void> markDeleted({
    required String ownerPubkey,
    required String listId,
    required DateTime deletedAt,
  }) async {
    final box = await _box();
    final deletedMillis = deletedAt.millisecondsSinceEpoch;
    await box.put(_deletedKey(ownerPubkey, listId), <String, dynamic>{
      _CacheKeys.ownerPubkey: ownerPubkey,
      _CacheKeys.deletedAtMillis: deletedMillis,
    });

    final listKey = _listKey(ownerPubkey, listId);
    final existing = box.get(listKey);
    if (existing is Map) {
      final list = _decodeList(existing);
      if (list != null &&
          list.updatedAt.millisecondsSinceEpoch <= deletedMillis) {
        await box.delete(listKey);
      }
    }
  }

  /// Removes every list record and tombstone owned by [ownerPubkey].
  ///
  /// Throws if the Hive box cannot be opened or the bulk delete fails.
  Future<void> clearOwner({required String ownerPubkey}) async {
    final box = await _box();
    final keysToDelete = box.keys
        .whereType<String>()
        .where((key) => _keyBelongsToOwner(key, ownerPubkey))
        .toList(growable: false);
    if (keysToDelete.isEmpty) {
      return;
    }
    await box.deleteAll(keysToDelete);
  }

  List<UserList> _collectLists(Box<dynamic> box, String ownerPubkey) {
    final tombstones = <String, int>{};
    final records = <UserList>[];

    for (final key in box.keys) {
      if (key is! String) continue;
      if (_isDeletedKey(key, ownerPubkey)) {
        final raw = box.get(key);
        if (raw is Map) {
          final millis = raw[_CacheKeys.deletedAtMillis];
          if (millis is int) {
            tombstones[_listIdFromDeletedKey(key, ownerPubkey)] = millis;
          }
        }
      }
    }

    for (final key in box.keys) {
      if (key is! String) continue;
      if (!_isListKey(key, ownerPubkey)) continue;
      final raw = box.get(key);
      if (raw is! Map) continue;
      final list = _decodeList(raw);
      if (list == null) continue;
      final tombstoneMillis = tombstones[list.id];
      if (tombstoneMillis != null &&
          tombstoneMillis >= list.updatedAt.millisecondsSinceEpoch) {
        continue;
      }
      records.add(list);
    }

    records.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return records;
  }

  /// Decodes a single stored record into a [UserList].
  ///
  /// Returns `null` and logs a warning when the record is shaped unexpectedly
  /// or when [UserList.fromJson] throws. A single malformed row must not
  /// poison the whole `readLists`/`watchLists` result.
  UserList? _decodeList(Map<dynamic, dynamic> record) {
    final raw = record[_CacheKeys.list];
    if (raw is! Map) return null;
    try {
      final json = Map<String, dynamic>.from(
        raw.map((key, value) => MapEntry(key.toString(), value)),
      );
      return UserList.fromJson(json);
    } on Object catch (error, stackTrace) {
      developer.log(
        'Dropped malformed people-list record during decode',
        name: _logName,
        level: _logLevelWarning,
        error: error,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  int? _tombstoneMillis(Box<dynamic> box, String ownerPubkey, String listId) {
    final raw = box.get(_deletedKey(ownerPubkey, listId));
    if (raw is! Map) return null;
    final value = raw[_CacheKeys.deletedAtMillis];
    return value is int ? value : null;
  }

  static String _listKey(String ownerPubkey, String listId) =>
      '${_CacheKeys.listPrefix}$ownerPubkey'
      '${_CacheKeys.keySeparator}$listId';

  static String _deletedKey(String ownerPubkey, String listId) =>
      '${_CacheKeys.deletedPrefix}$ownerPubkey'
      '${_CacheKeys.keySeparator}$listId';

  static bool _keyBelongsToOwner(String key, String ownerPubkey) {
    return _isListKey(key, ownerPubkey) || _isDeletedKey(key, ownerPubkey);
  }

  static bool _isListKey(String key, String ownerPubkey) {
    final prefix =
        '${_CacheKeys.listPrefix}$ownerPubkey${_CacheKeys.keySeparator}';
    return key.startsWith(prefix);
  }

  static bool _isDeletedKey(String key, String ownerPubkey) {
    final prefix =
        '${_CacheKeys.deletedPrefix}$ownerPubkey'
        '${_CacheKeys.keySeparator}';
    return key.startsWith(prefix);
  }

  static String _listIdFromDeletedKey(String key, String ownerPubkey) {
    final prefix =
        '${_CacheKeys.deletedPrefix}$ownerPubkey'
        '${_CacheKeys.keySeparator}';
    return key.substring(prefix.length);
  }
}
