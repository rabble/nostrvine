// ABOUTME: Safe wrapper around JsonCacheInfoRepository that handles corrupted cache files
// ABOUTME: Intercepts FlutterError.reportError during open() since upstream swallows exceptions

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:unified_logger/unified_logger.dart';

/// A safe wrapper around [JsonCacheInfoRepository] that handles corrupted
/// JSON files.
///
/// The upstream [JsonCacheInfoRepository._readFile] catches all exceptions
/// internally (`on Object`) and reports them via [FlutterError.reportError]
/// instead of rethrowing. This means a standard try/catch around [open] never
/// sees the error. Instead, the error flows to [FlutterError.onError], which
/// Crashlytics records as a fatal crash.
///
/// This wrapper temporarily intercepts [FlutterError.onError] during [open] to
/// detect corruption, deletes the bad file, and retries cleanly.
class SafeJsonCacheInfoRepository extends JsonCacheInfoRepository {
  SafeJsonCacheInfoRepository({required String databaseName})
    : _databaseName = databaseName,
      super(databaseName: databaseName);

  final String _databaseName;

  @override
  Future<bool> open() async {
    // Temporarily intercept FlutterError.onError to catch errors that the
    // upstream _readFile reports internally instead of rethrowing.
    Object? caughtException;
    final previousHandler = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.library == 'flutter cache manager') {
        caughtException = details.exception;
        return;
      }
      // Forward non-cache errors to the previous handler
      previousHandler?.call(details);
    };

    try {
      final result = await super.open();

      if (caughtException != null) {
        Log.warning(
          'Cache JSON corrupted for $_databaseName, '
          'clearing cache: $caughtException',
          name: 'SafeJsonCacheRepository',
          category: LogCategory.system,
        );
        await _deleteCacheFile();
        // Restore handler before retry so any further errors propagate normally
        FlutterError.onError = previousHandler;
        return super.open();
      }

      return result;
    } finally {
      FlutterError.onError = previousHandler;
    }
  }

  Future<void> _deleteCacheFile() async {
    try {
      final directory = await getApplicationSupportDirectory();
      final filePath = path.join(directory.path, '$_databaseName.json');
      final file = File(filePath);
      if (file.existsSync()) {
        await file.delete();
        Log.info(
          'Deleted corrupted cache file: $filePath',
          name: 'SafeJsonCacheRepository',
          category: LogCategory.system,
        );
      }
    } catch (e) {
      Log.error(
        'Failed to delete corrupted cache file: $e',
        name: 'SafeJsonCacheRepository',
        category: LogCategory.system,
      );
    }
  }
}
