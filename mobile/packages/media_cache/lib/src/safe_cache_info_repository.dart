import 'dart:io';

import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

/// {@template safe_cache_info_repository}
/// A safe wrapper around [JsonCacheInfoRepository] that handles corrupted
/// JSON files.
///
/// The standard [JsonCacheInfoRepository] crashes with [FormatException] when
/// the cache JSON file is empty or corrupted (e.g., due to app crash during
/// write). This wrapper catches those errors and deletes the corrupted file
/// so a fresh cache can be created.
/// {@endtemplate}
class SafeCacheInfoRepository extends JsonCacheInfoRepository {
  /// {@macro safe_cache_info_repository}
  SafeCacheInfoRepository({required String databaseName})
    : _databaseName = databaseName,
      super(databaseName: databaseName);

  final String _databaseName;

  @override
  Future<bool> open() async {
    try {
      return await super.open();
    } on FormatException {
      // JSON file is corrupted - delete it and retry
      await _deleteCacheFile();
      return super.open();
    } on Exception catch (e) {
      // Handle other errors (null content, type errors, etc.)
      if (e.toString().contains('Unexpected end of input') ||
          e.toString().contains("type 'Null'")) {
        await _deleteCacheFile();
        return super.open();
      }
      rethrow;
    }
  }

  /// Delete the corrupted cache JSON file.
  ///
  /// Note: [JsonCacheInfoRepository] stores its JSON in
  /// `getApplicationSupportDirectory()`.
  Future<void> _deleteCacheFile() async {
    final directory = await getApplicationSupportDirectory();
    final filePath = path.join(directory.path, '$_databaseName.json');
    final file = File(filePath);
    if (file.existsSync()) {
      await file.delete();
    }
  }
}
