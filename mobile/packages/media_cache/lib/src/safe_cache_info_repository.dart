import 'dart:io';

import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

/// A callback for logging warning messages.
typedef LogWarningCallback = void Function(String message);

/// A callback for logging info messages.
typedef LogInfoCallback = void Function(String message);

/// A callback for logging error messages.
typedef LogErrorCallback = void Function(String message);

/// {@template safe_cache_info_repository}
/// A safe wrapper around [JsonCacheInfoRepository] that handles corrupted
/// JSON files.
///
/// The standard [JsonCacheInfoRepository] crashes with [FormatException] when
/// the cache JSON file is empty or corrupted (e.g., due to app crash during
/// write). This wrapper catches those errors and deletes the corrupted file
/// so a fresh cache can be created.
///
/// Example:
/// ```dart
/// final repo = SafeCacheInfoRepository(
///   databaseName: 'my_cache',
///   onWarning: (msg) => print('Warning: $msg'),
/// );
/// ```
/// {@endtemplate}
class SafeCacheInfoRepository extends JsonCacheInfoRepository {
  /// {@macro safe_cache_info_repository}
  SafeCacheInfoRepository({
    required String databaseName,
    this.onWarning,
    this.onInfo,
    this.onError,
  }) : _databaseName = databaseName,
       super(databaseName: databaseName);

  final String _databaseName;

  /// Optional callback for warning messages.
  final LogWarningCallback? onWarning;

  /// Optional callback for info messages.
  final LogInfoCallback? onInfo;

  /// Optional callback for error messages.
  final LogErrorCallback? onError;

  @override
  Future<bool> open() async {
    try {
      return await super.open();
    } on FormatException catch (e) {
      // JSON file is corrupted - delete it and retry
      onWarning?.call(
        'Cache JSON corrupted for $_databaseName, clearing cache: $e',
      );
      await _deleteCacheFile();
      return super.open();
    } on Exception catch (e) {
      // Handle other errors (null content, type errors, etc.)
      if (e.toString().contains('Unexpected end of input') ||
          e.toString().contains("type 'Null'")) {
        onWarning?.call(
          'Cache JSON empty/null for $_databaseName, clearing cache: $e',
        );
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
    try {
      final directory = await getApplicationSupportDirectory();
      final filePath = path.join(directory.path, '$_databaseName.json');
      final file = File(filePath);
      if (file.existsSync()) {
        await file.delete();
        onInfo?.call('Deleted corrupted cache file: $filePath');
      }
    } on Exception catch (e) {
      onError?.call('Failed to delete corrupted cache file: $e');
    }
  }
}
