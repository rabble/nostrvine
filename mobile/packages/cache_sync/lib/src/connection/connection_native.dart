// ABOUTME: Native platform database connection for cache_sync.
// ABOUTME: Provides file-based SQLite storage for iOS, Android, macOS, etc.
// coverage:ignore-file

import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Opens a database connection for native platforms.
QueryExecutor openConnection() {
  if (_isFlutterTestProcess) {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    return NativeDatabase.memory();
  }

  return LazyDatabase(() async {
    final dir = await getApplicationSupportDirectory();
    final file = File(p.join(dir.path, 'openvine', 'cache', 'cache_sync.db'));
    await file.parent.create(recursive: true);
    // Open on a background isolate so cache reads/writes stay off the UI
    // thread (#5391). This DB is unencrypted, so there is no setup callback.
    return NativeDatabase.createInBackground(file);
  });
}

bool get _isFlutterTestProcess =>
    Platform.executable.contains('flutter_tester');
