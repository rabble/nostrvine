// ABOUTME: Utility for resolving file paths for iOS compatibility
// ABOUTME: iOS changes container paths on app updates, so we store only filenames

import 'package:path/path.dart' as p;

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
