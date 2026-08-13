// ABOUTME: Sole owner of Hive's process-global home path, set once at startup
// ABOUTME: Migrates boxes stranded in the legacy documents directory into it

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:hive_ce/hive.dart';
import 'package:openvine/constants/hive_box_names.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:unified_logger/unified_logger.dart';

/// Single owner of Hive's process-global home path.
///
/// `Hive.init` assigns a process-global home path and `openBox` resolves a
/// box's file from whatever that path holds at open time. A second `init`
/// therefore relocates every box opened after it. The app used to call it
/// twice per launch — `Hive.initFlutter()` (documents directory) in the
/// critical startup phase, then again from the uploads-box initializer
/// (`{appSupport}/openvine`) in the standard phase — so a box landed in
/// whichever directory happened to be current when it opened, and the same box
/// could exist in both places with different contents (#6958).
///
/// [initialize] is the only place the app sets the home path.
abstract final class HiveStorageService {
  static const String _logName = 'HiveStorage';

  /// Subdirectory of Application Support that holds every Hive box file.
  ///
  /// Boxes have lived here since the uploads-box initializer started
  /// re-pointing Hive at it, and `CacheRecoveryService` protects the durable
  /// ones from a cache wipe by absolute path underneath it.
  static const String homeDirectoryName = 'openvine';

  static Future<void>? _initialization;

  /// Points Hive at its one home directory, migrating stranded boxes first.
  ///
  /// Must complete before the first `Hive.openBox`: the startup coordinator
  /// runs it in the critical phase, and every box owner sits in a later phase.
  /// Repeat calls return the first call's future, so the home path is assigned
  /// exactly once per process and never reassigned.
  static Future<void> initialize() => _initialization ??= _initialize();

  static Future<void> _initialize() async {
    if (kIsWeb) {
      // Web keeps boxes in IndexedDB, so there is no home path to resolve.
      Hive.init(null);
      return;
    }

    final home = Directory(
      p.join((await getApplicationSupportDirectory()).path, homeDirectoryName),
    );
    if (!home.existsSync()) {
      await home.create(recursive: true);
    }

    await _migrateLegacyBoxes(home);

    Hive.init(home.path);

    Log.info(
      'Hive home path set to ${home.path}',
      name: _logName,
      category: LogCategory.storage,
    );
  }

  /// Best-effort move of the boxes left in the legacy home into [home].
  ///
  /// The legacy home is the documents directory, where `Hive.initFlutter()`
  /// pointed. A split box can hold real writes on both sides, so the more
  /// recently written file wins and the other is deleted — the newest data
  /// survives and nothing is left behind to be picked up again. Lock files
  /// carry no data and are recreated on open, so legacy ones are just removed.
  ///
  /// A failure here must not block startup: the files stay put and the next
  /// launch tries again.
  static Future<void> _migrateLegacyBoxes(Directory home) async {
    try {
      final legacy = await getApplicationDocumentsDirectory();
      if (!legacy.existsSync() || p.equals(legacy.path, home.path)) return;

      var migrated = 0;
      for (final boxName in HiveBoxNames.all) {
        await _deleteIfPresent(File(p.join(legacy.path, '$boxName.lock')));

        final legacyFile = File(p.join(legacy.path, '$boxName.hive'));
        if (!legacyFile.existsSync()) continue;

        final targetFile = File(p.join(home.path, '$boxName.hive'));
        if (targetFile.existsSync() &&
            !targetFile.lastModifiedSync().isBefore(
              legacyFile.lastModifiedSync(),
            )) {
          await _deleteIfPresent(legacyFile);
          continue;
        }

        if (await _move(legacyFile, targetFile)) migrated++;
      }

      if (migrated > 0) {
        Log.info(
          'Migrated $migrated stranded Hive box file(s) into ${home.path}',
          name: _logName,
          category: LogCategory.storage,
        );
      }
    } catch (e) {
      Log.warning(
        'Failed to migrate stranded Hive boxes: $e',
        name: _logName,
        category: LogCategory.storage,
      );
    }
  }

  /// Renames [source] onto [target], falling back to copy + delete when the
  /// two sit on different filesystems. Returns whether the move happened.
  static Future<bool> _move(File source, File target) async {
    try {
      await source.rename(target.path);
      return true;
    } on FileSystemException {
      try {
        await source.copy(target.path);
        await source.delete();
        return true;
      } catch (e) {
        Log.warning(
          'Could not move ${source.path} to ${target.path}: $e',
          name: _logName,
          category: LogCategory.storage,
        );
        return false;
      }
    }
  }

  static Future<void> _deleteIfPresent(File file) async {
    if (!file.existsSync()) return;
    try {
      await file.delete();
    } catch (e) {
      Log.debug(
        'Could not delete ${file.path}: $e',
        name: _logName,
        category: LogCategory.storage,
      );
    }
  }

  @visibleForTesting
  static void resetForTesting() => _initialization = null;
}
