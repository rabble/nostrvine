// ABOUTME: Removes stale empty files left by legacy failed C2PA signing.
// ABOUTME: Protects recordings, valid derived media, and fresh signing output.

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:unified_logger/unified_logger.dart';

/// Best-effort cleanup for abandoned C2PA signing destinations.
abstract final class C2paDebrisJanitor {
  /// Files newer than this may still belong to an active signing operation.
  static const staleDebrisAge = Duration(hours: 1);

  static final RegExp _debrisName = RegExp(r'^c2pa_signed_[0-9]+\.mp4$');

  /// Deletes stale, empty signing destinations directly inside [directory].
  ///
  /// This is intentionally non-recursive and best-effort: inaccessible files
  /// are retried on a later launch, and filesystem failures never reach the
  /// startup coordinator.
  static void deleteStaleDebris(
    Directory directory, {
    DateTime? now,
    Duration staleAge = staleDebrisAge,
  }) {
    final cutoff = (now ?? DateTime.now()).subtract(staleAge);
    var deletedCount = 0;

    try {
      for (final entity in directory.listSync(followLinks: false)) {
        if (entity is! File) continue;
        if (!_debrisName.hasMatch(p.basename(entity.path))) continue;

        try {
          final stat = entity.statSync();
          if (stat.type != FileSystemEntityType.file || stat.size != 0) {
            continue;
          }
          if (!stat.modified.isBefore(cutoff)) continue;

          entity.deleteSync();
          deletedCount++;
        } on Object {
          // Best-effort; a file we cannot delete is retried next launch.
        }
      }
    } on Object {
      // Best-effort; a listing failure must not block startup.
    }

    if (deletedCount > 0) {
      Log.info(
        'Removed $deletedCount stale C2PA signing file(s) from '
        '${directory.path}',
        name: 'C2paDebrisJanitor',
        category: LogCategory.video,
      );
    }
  }
}
