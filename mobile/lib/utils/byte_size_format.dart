// ABOUTME: Shared human-readable byte-size formatting for storage readouts.

/// Formats [bytes] as a short human-readable size (e.g. `1.2 MB`).
///
/// Units step at 1024, and the fraction is dropped from 10 upwards so a
/// column of sizes stays roughly the same width.
String formatByteSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  const units = ['KB', 'MB', 'GB', 'TB'];
  var size = bytes / 1024;
  var unit = 0;
  while (size >= 1024 && unit < units.length - 1) {
    size /= 1024;
    unit++;
  }
  return '${size.toStringAsFixed(size >= 10 ? 0 : 1)} ${units[unit]}';
}
