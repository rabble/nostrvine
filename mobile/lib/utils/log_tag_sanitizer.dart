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

/// Sanitizes an event JSON map for log output.
///
/// Redacts privacy-sensitive tag values and truncates oversized tag parts
/// while preserving non-tag fields exactly as-is.
Map<String, dynamic> sanitizeEventJsonForLog(Map<String, dynamic> eventMap) {
  final rawTags = eventMap['tags'];
  if (rawTags is! List) {
    return eventMap;
  }

  final sanitizedTags = rawTags
      .map((rawTag) {
        if (rawTag is! List) {
          return rawTag;
        }

        final tagParts = rawTag.map((part) => part.toString()).toList();
        return sanitizeTagForLog(tagParts);
      })
      .toList(growable: false);

  return <String, dynamic>{...eventMap, 'tags': sanitizedTags};
}
