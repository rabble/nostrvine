// ABOUTME: Content-moderation value types shared by the reporting and
// ABOUTME: content-warning flows (report reasons, severity, mute entries).

/// Reasons for content filtering/reporting.
///
/// Categories for content filtering and report flows.
enum ContentFilterReason {
  spam,
  harassment,
  violence,
  sexualContent,
  copyright,
  falseInformation,
  childSafety,
  csam,
  underageUser,
  aiGenerated,
  other,
}

/// Content severity levels for filtering
enum ContentSeverity {
  info, // Informational only
  warning, // Show warning but allow viewing
  hide, // Hide by default, show if requested
  block, // Completely block content
}

/// Mute list entry representing filtered content
class MuteListEntry {
  const MuteListEntry({
    required this.type,
    required this.value,
    required this.reason,
    required this.severity,
    required this.createdAt,
    this.note,
  });
  final String type; // 'pubkey', 'event', 'keyword', 'content-type'
  final String value;
  final ContentFilterReason reason;
  final ContentSeverity severity;
  final DateTime createdAt;
  final String? note;

  Map<String, dynamic> toJson() => {
    'type': type,
    'value': value,
    'reason': reason.name,
    'severity': severity.name,
    'createdAt': createdAt.toIso8601String(),
    'note': note,
  };

  static MuteListEntry fromJson(Map<String, dynamic> json) => MuteListEntry(
    type: json['type'] as String,
    value: json['value'] as String,
    reason: ContentFilterReason.values.firstWhere(
      (r) => r.name == json['reason'],
      orElse: () => ContentFilterReason.other,
    ),
    severity: ContentSeverity.values.firstWhere(
      (s) => s.name == json['severity'],
      orElse: () => ContentSeverity.hide,
    ),
    createdAt: DateTime.parse(json['createdAt'] as String),
    note: json['note'] as String?,
  );

  /// Convert to NIP-51 list entry tag format
  List<String> toNIP51Tag() {
    final tag = [type, value];
    if (note != null) tag.add(note!);
    return tag;
  }
}

/// Content moderation result
class ModerationResult {
  const ModerationResult({
    required this.shouldFilter,
    required this.severity,
    required this.reasons,
    required this.matchingEntries,
    this.warningMessage,
  });
  final bool shouldFilter;
  final ContentSeverity severity;
  final List<ContentFilterReason> reasons;
  final String? warningMessage;
  final List<MuteListEntry> matchingEntries;

  static const ModerationResult clean = ModerationResult(
    shouldFilter: false,
    severity: ContentSeverity.info,
    reasons: [],
    matchingEntries: [],
  );
}
