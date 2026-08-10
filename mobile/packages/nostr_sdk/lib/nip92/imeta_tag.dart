// ABOUTME: Shared parser for NIP-92 imeta tag key-value encodings.

/// Parses an `imeta` tag and calls [onKeyValue] for each metadata key-value
/// pair.
///
/// Supports both encodings seen in Divine events:
/// - `['imeta', 'url https://...', 'm video/mp4']`
/// - `['imeta', 'url', 'https://...', 'm', 'video/mp4']`
void parseImetaTag(
  List<String> tag,
  void Function(String key, String value) onKeyValue,
) {
  if (tag.length <= 1) return;

  final firstElement = tag[1];
  final hasSpaceSeparatedValues = firstElement.contains(' ');

  if (hasSpaceSeparatedValues) {
    for (var i = 1; i < tag.length; i++) {
      final element = tag[i];
      final spaceIndex = element.indexOf(' ');
      if (spaceIndex > 0) {
        final key = element.substring(0, spaceIndex);
        final value = element.substring(spaceIndex + 1);
        onKeyValue(key, value);
      }
    }
    return;
  }

  for (var i = 1; i < tag.length - 1; i += 2) {
    final key = tag[i];
    final value = tag[i + 1];
    onKeyValue(key, value);
  }
}
