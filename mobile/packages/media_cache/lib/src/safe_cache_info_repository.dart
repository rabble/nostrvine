import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

/// Function type for getting the application support directory.
typedef DirectoryProvider = Future<Directory> Function();

/// {@template safe_cache_info_repository}
/// A safe wrapper around [CacheInfoRepository] that handles corrupted
/// JSON files.
///
/// The standard [JsonCacheInfoRepository] crashes with [FormatException] when
/// the cache JSON file is empty or corrupted (e.g., due to app crash during
/// write). This wrapper catches those errors and deletes the corrupted file
/// so a fresh cache can be created.
///
/// Uses composition to wrap a [CacheInfoRepository] (defaults to
/// [JsonCacheInfoRepository]), making it fully testable via dependency
/// injection.
/// {@endtemplate}
class SafeCacheInfoRepository implements CacheInfoRepository {
  /// {@macro safe_cache_info_repository}
  ///
  /// The [repository] and [directoryProvider] parameters are exposed for
  /// testing purposes. In production, they default to
  /// [JsonCacheInfoRepository] and [getApplicationSupportDirectory].
  SafeCacheInfoRepository({
    required String databaseName,
    @visibleForTesting CacheInfoRepository? repository,
    @visibleForTesting DirectoryProvider? directoryProvider,
  }) : _databaseName = databaseName,
       _repository =
           repository ?? JsonCacheInfoRepository(databaseName: databaseName),
       _directoryProvider = directoryProvider ?? getApplicationSupportDirectory;

  final String _databaseName;
  final CacheInfoRepository _repository;
  final DirectoryProvider _directoryProvider;

  /// The wrapped repository instance.
  ///
  /// Exposed for testing purposes only.
  @visibleForTesting
  CacheInfoRepository get repository => _repository;

  @override
  Future<bool> open() async {
    try {
      return await _repository.open();
    } on FormatException {
      // JSON file is corrupted - delete it and retry
      await deleteCacheFile();
      return _repository.open();
    } on Exception catch (e) {
      // Handle other errors (null content, type errors, etc.)
      if (e.toString().contains('Unexpected end of input') ||
          e.toString().contains("type 'Null'")) {
        await deleteCacheFile();
        return _repository.open();
      }
      rethrow;
    }
  }

  /// Deletes the cache JSON file.
  ///
  /// This is called internally when the cache file is corrupted.
  /// Exposed as a visible method for testing purposes.
  @visibleForTesting
  Future<void> deleteCacheFile() async {
    final directory = await _directoryProvider();
    final filePath = path.join(directory.path, '$_databaseName.json');
    final file = File(filePath);
    if (file.existsSync()) {
      await file.delete();
    }
  }

  // Delegate all CacheInfoRepository methods to the wrapped repository.

  @override
  Future<bool> close() => _repository.close();

  @override
  Future<int> delete(int id) => _repository.delete(id);

  @override
  Future<int> deleteAll(Iterable<int> ids) => _repository.deleteAll(ids);

  @override
  Future<void> deleteDataFile() => _repository.deleteDataFile();

  @override
  Future<bool> exists() => _repository.exists();

  @override
  Future<CacheObject?> get(String key) => _repository.get(key);

  @override
  Future<List<CacheObject>> getAllObjects() => _repository.getAllObjects();

  @override
  Future<List<CacheObject>> getObjectsOverCapacity(int capacity) =>
      _repository.getObjectsOverCapacity(capacity);

  @override
  Future<List<CacheObject>> getOldObjects(Duration maxAge) =>
      _repository.getOldObjects(maxAge);

  @override
  Future<CacheObject> insert(
    CacheObject cacheObject, {
    bool setTouchedToNow = true,
  }) => _repository.insert(cacheObject, setTouchedToNow: setTouchedToNow);

  @override
  Future<int> update(
    CacheObject cacheObject, {
    bool setTouchedToNow = true,
  }) => _repository.update(cacheObject, setTouchedToNow: setTouchedToNow);

  @override
  Future<dynamic> updateOrInsert(CacheObject cacheObject) =>
      _repository.updateOrInsert(cacheObject);
}
