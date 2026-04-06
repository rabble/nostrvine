/// Compares semantic version strings.
///
/// Returns:
/// - negative if [a] < [b]
/// - zero if [a] == [b]
/// - positive if [a] > [b]
int compareVersions(String a, String b) {
  final aParts = a.split('.').map(int.tryParse).toList();
  final bParts = b.split('.').map(int.tryParse).toList();

  for (var i = 0; i < 3; i++) {
    final aVal = i < aParts.length ? (aParts[i] ?? 0) : 0;
    final bVal = i < bParts.length ? (bParts[i] ?? 0) : 0;
    if (aVal != bVal) return aVal.compareTo(bVal);
  }
  return 0;
}

/// Returns true if [current] is older than [latest].
bool isOlderThan(String current, String latest) =>
    compareVersions(current, latest) < 0;

/// Returns true if [current] is below [minimum].
bool isBelowMinimum(String current, String minimum) =>
    compareVersions(current, minimum) < 0;
