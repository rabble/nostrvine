// ABOUTME: Utility for migrating Android files from old /files/ path to /app_flutter/
// ABOUTME: Used when native camera saved to context.filesDir but Flutter expects app_flutter

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:path/path.dart' as p;

/// Checks if Android path migration is needed and migrates files if necessary.
/// Returns true if any files were migrated.
Future<bool> migrateAndroidPaths({
  required String documentsPath,
  required List<String?> filePaths,
}) async {
  // Only migrate on Android when using app_flutter directory
  if (kIsWeb || !Platform.isAndroid || !documentsPath.contains('app_flutter')) {
    return false;
  }

  var migrated = false;
  for (final path in filePaths) {
    if (path != null && path.contains('/files/')) {
      await _migrateFile(path, documentsPath);
      migrated = true;
    }
  }
  return migrated;
}

/// Migrate a file from old /files/ path to new /app_flutter/ path
Future<void> _migrateFile(String oldPath, String documentsPath) async {
  final filename = p.basename(oldPath);
  final newPath = p.join(documentsPath, filename);
  final oldFile = File(oldPath);
  final newFile = File(newPath);

  // Skip if already migrated or old file doesn't exist
  if (newFile.existsSync() || !oldFile.existsSync()) return;

  try {
    await oldFile.copy(newPath);
    await oldFile.delete();
    Log.info('📂 Migrated: $filename', name: 'AndroidPathMigration');
  } catch (e) {
    Log.warning(
      '📂 Failed to migrate $filename: $e',
      name: 'AndroidPathMigration',
    );
  }
}
