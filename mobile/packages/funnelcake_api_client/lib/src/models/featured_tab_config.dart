// ABOUTME: Models for server-driven featured hashtag tabs on Explore.
// ABOUTME: The configured hashtag is never exposed — tabs carry an opaque id.

import 'package:meta/meta.dart';

/// Key of the required fallback entry in a featured tab's locale map.
const featuredTabLabelDefaultKey = 'default';

/// A single server-configured featured tab.
///
/// The client never learns which hashtag a tab represents; [id] is the only
/// fetch and analytics key.
@immutable
class FeaturedTabConfig {
  /// Creates a featured tab configuration.
  const FeaturedTabConfig({
    required this.id,
    required this.slug,
    required this.label,
    required this.startsAt,
    required this.endsAt,
    this.enabled = false,
    this.visibleToMinors = false,
    this.pillLabel = const {},
    this.disclosureLabel = const {},
    this.hasContent = false,
  });

  /// Parses a featured tab entry from the public config endpoint.
  factory FeaturedTabConfig.fromJson(Map<String, dynamic> json) {
    return FeaturedTabConfig(
      id: json['id']?.toString() ?? '',
      slug: json['slug']?.toString() ?? '',
      label: _parseLocaleMap(json['label']),
      startsAt: _parseTimestamp(json['starts_at']),
      endsAt: _parseTimestamp(json['ends_at']),
      enabled: json['enabled'] as bool? ?? false,
      visibleToMinors: json['visible_to_minors'] as bool? ?? false,
      pillLabel: _parseLocaleMap(json['pill_label']),
      disclosureLabel: _parseLocaleMap(json['disclosure_label']),
      hasContent: json['has_content'] as bool? ?? false,
    );
  }

  /// Opaque configuration id, used for fetching and analytics.
  final String id;

  /// URL slug used for deep linking into this tab.
  final String slug;

  /// Locale map of display labels, keyed by locale code.
  final Map<String, String> label;

  /// Start of the configured display window.
  final DateTime? startsAt;

  /// End of the configured display window.
  final DateTime? endsAt;

  /// Server kill switch. A disabled tab never renders.
  final bool enabled;

  /// Whether the tab may be shown to accounts flagged as minors.
  final bool visibleToMinors;

  /// Optional locale map for the pill rendered beside the tab name.
  ///
  /// The tab itself always reads "Featured"; this carries the collection's
  /// own name. Absent or empty means no pill.
  final Map<String, String> pillLabel;

  /// Optional locale map naming the tab's commercial sponsor.
  ///
  /// This field is the *only* sponsorship signal — there is no boolean
  /// beside it. A non-empty value means the collection is sponsored and
  /// names who by; an absent, null, or empty value means it is not. An
  /// older backend omits the key entirely, which reads the same as unset.
  final Map<String, String> disclosureLabel;

  /// Whether the server has precomputed content for this tab.
  final bool hasContent;

  /// Localized label for [localeCode], falling back to the `default` entry.
  ///
  /// Returns an empty string when the map carries neither, which callers
  /// treat as an unrenderable tab.
  String labelFor(String? localeCode) => _resolveLocale(label, localeCode);

  /// Localized pill text for [localeCode], or `null` when unset.
  String? pillLabelFor(String? localeCode) {
    final resolved = _resolveLocale(pillLabel, localeCode);
    return resolved.isEmpty ? null : resolved;
  }

  /// Localized sponsor name for [localeCode], or `null` when not sponsored.
  String? sponsorNameFor(String? localeCode) {
    final resolved = _resolveLocale(disclosureLabel, localeCode);
    return resolved.isEmpty ? null : resolved;
  }

  /// Whether this tab is commercially sponsored in any locale.
  ///
  /// Answered by the presence of a sponsor name, since a sponsored tab with
  /// nobody to credit cannot be disclosed and must not be styled as one.
  bool get isSponsored =>
      disclosureLabel.values.any((value) => value.isNotEmpty);

  /// Whether [now] falls inside the configured display window.
  ///
  /// A missing bound is treated as unbounded on that side.
  bool isWithinWindow(DateTime now) {
    final start = startsAt;
    final end = endsAt;
    if (start != null && now.isBefore(start)) return false;
    if (end != null && !now.isBefore(end)) return false;
    return true;
  }

  @override
  bool operator ==(Object other) =>
      other is FeaturedTabConfig &&
      other.id == id &&
      other.slug == slug &&
      other.startsAt == startsAt &&
      other.endsAt == endsAt &&
      other.enabled == enabled &&
      other.visibleToMinors == visibleToMinors &&
      other.hasContent == hasContent &&
      _mapEquals(other.label, label) &&
      _mapEquals(other.pillLabel, pillLabel) &&
      _mapEquals(other.disclosureLabel, disclosureLabel);

  @override
  int get hashCode => Object.hash(
    id,
    slug,
    startsAt,
    endsAt,
    enabled,
    visibleToMinors,
    hasContent,
    _mapHash(label),
    _mapHash(pillLabel),
    _mapHash(disclosureLabel),
  );

  static bool _mapEquals(Map<String, String> a, Map<String, String> b) {
    if (a.length != b.length) return false;
    for (final entry in a.entries) {
      if (b[entry.key] != entry.value) return false;
    }
    return true;
  }

  static int _mapHash(Map<String, String> map) {
    final entries = map.entries.map((e) => Object.hash(e.key, e.value)).toList()
      ..sort();
    return Object.hashAll(entries);
  }

  static String _resolveLocale(Map<String, String> map, String? localeCode) {
    if (localeCode != null) {
      final exact = map[localeCode];
      if (exact != null && exact.isNotEmpty) return exact;
      final language = localeCode.split(RegExp('[-_]')).first;
      final byLanguage = map[language];
      if (byLanguage != null && byLanguage.isNotEmpty) return byLanguage;
    }
    return map[featuredTabLabelDefaultKey] ?? '';
  }

  /// Accepts either a locale map or a bare string, which the server may send
  /// for single-value fields such as `disclosure_label`.
  static Map<String, String> _parseLocaleMap(Object? raw) {
    if (raw is String) {
      return raw.isEmpty ? const {} : {featuredTabLabelDefaultKey: raw};
    }
    if (raw is! Map) return const {};
    final parsed = <String, String>{};
    for (final entry in raw.entries) {
      final value = entry.value;
      if (value is String && value.isNotEmpty) {
        parsed[entry.key.toString()] = value;
      }
    }
    return parsed;
  }

  static DateTime? _parseTimestamp(Object? raw) {
    if (raw is String) return DateTime.tryParse(raw)?.toUtc();
    if (raw is int) {
      return DateTime.fromMillisecondsSinceEpoch(raw * 1000, isUtc: true);
    }
    return null;
  }
}

/// Parsed response from the public featured tabs config endpoint.
@immutable
class FeaturedTabsResponse {
  /// Creates a featured tabs config response.
  const FeaturedTabsResponse({required this.tabs, required this.pollInterval});

  /// Parses the `{poll_interval_seconds, featured_tabs}` envelope.
  factory FeaturedTabsResponse.fromJson(Map<String, dynamic> json) {
    final rawTabs = json['featured_tabs'];
    final tabs = rawTabs is List
        ? rawTabs
              .whereType<Map<String, dynamic>>()
              .map(FeaturedTabConfig.fromJson)
              .where((tab) => tab.id.isNotEmpty)
              .toList()
        : <FeaturedTabConfig>[];

    final rawInterval = json['poll_interval_seconds'];
    final seconds = rawInterval is int
        ? rawInterval
        : int.tryParse(rawInterval?.toString() ?? '');

    final requestedInterval = seconds != null && seconds > 0
        ? Duration(seconds: seconds)
        : defaultPollInterval;

    return FeaturedTabsResponse(
      tabs: tabs,
      pollInterval: _clampPollInterval(requestedInterval),
    );
  }

  /// Poll cadence used when the server omits or malforms the interval.
  static const defaultPollInterval = Duration(minutes: 5);

  /// Fastest cadence the client accepts from the public config endpoint.
  static const minPollInterval = Duration(seconds: 30);

  /// Slowest cadence the client accepts from the public config endpoint.
  static const maxPollInterval = Duration(hours: 1);

  /// Tabs the server currently considers renderable.
  final List<FeaturedTabConfig> tabs;

  /// Server-supplied poll cadence for refetching this config.
  final Duration pollInterval;

  static Duration _clampPollInterval(Duration interval) {
    if (interval < minPollInterval) return minPollInterval;
    if (interval > maxPollInterval) return maxPollInterval;
    return interval;
  }
}
