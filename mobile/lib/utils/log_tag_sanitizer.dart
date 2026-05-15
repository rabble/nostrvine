const Set<String> _kRedactedTagNames = {'proofmode', 'device_attestation'};
const int _kMaxLoggedTagPartLength = 180;

/// Sanitizes a single Nostr event tag for log output.
///
/// Redacts the value of privacy-sensitive tags and truncates any part longer
/// than 180 characters so log lines stay manageable.
List<String> sanitizeTagForLog(List<String> tag) {
  if (tag.isEmpty) {
    return tag;
  }

  final tagName = tag.first;
  if (_kRedactedTagNames.contains(tagName)) {
    return <String>[tagName, '[FILTERED_FROM_LOGS]'];
  }

  return <String>[
    tagName,
    ...tag.skip(1).map((part) {
      if (part.length <= _kMaxLoggedTagPartLength) {
        return part;
      }

      return '${part.substring(0, _kMaxLoggedTagPartLength)}...(truncated)';
    }),
  ];
}
