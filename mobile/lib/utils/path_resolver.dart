// ABOUTME: Utility for resolving file paths for iOS compatibility
// ABOUTME: iOS changes container paths on app updates, so we store only filenames

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart' as path_provider;

/// Returns the application documents directory path.
///
/// On web, path_provider has no documents directory; returns `''` so callers
/// can join basenames without calling the plugin (avoids MissingPluginException).
///
/// The web branch is covered by `test/utils/path_resolver_test.dart` when run
/// locally as `flutter test test/utils/path_resolver_test.dart --platform chrome`
/// (not run in CI).
Future<String> getDocumentsPath() async {
  if (kIsWeb) {
    return '';
  }
  final dir = await path_provider.getApplicationDocumentsDirectory();
  return dir.path;
}

/// Resolves a file path for storage/retrieval.
///
/// When [useOriginalPath] is true, returns the raw path unchanged (for migration checks).
/// Otherwise, joins [documentsPath] with only the basename of [rawPath].
///
/// This ensures iOS compatibility since the container path changes on app updates.
String? resolvePath(
  String? rawPath,
  String documentsPath, {
  bool useOriginalPath = false,
}) {
  if (rawPath == null) return null;
  return useOriginalPath ? rawPath : p.join(documentsPath, p.basename(rawPath));
}
