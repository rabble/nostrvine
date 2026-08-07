// ABOUTME: Models for server-driven featured hashtag tabs on Explore.
// ABOUTME: The configured hashtag is never exposed — tabs carry an opaque id.

import 'package:meta/meta.dart';

/// Key of the required fallback entry in a featured tab's locale map.
const featuredTabLabelDefaultKey = 'default';

/// Platform key the mobile client reads out of a tab's `position` object.
const featuredTabMobilePlatformKey = 'mobile';

/// Placement of a featured tab relative to an existing Explore tab.
///
/// Placement is always expressed by tab **name**, never by index, because
/// Explore's optional tabs shift indices at runtime.
@immutable
class FeaturedTabPosition {
  /// Creates a placement anchored after or before a named tab.
  const FeaturedTabPosition({this.after, this.before});

  /// Parses the mobile entry of a `position` object.
  ///
  /// Returns an anchorless position when [json] is missing the mobile key or
  /// carries no usable anchor, which callers treat as "append at the end".
  factory FeaturedTabPosition.fromJson(Map<String, dynamic>? json) {
    final mobile = json?[featuredTabMobilePlatformKey];
    if (mobile is! Map) return const FeaturedTabPosition();
    final after = mobile['after'];
    final before = mobile['before'];
    return FeaturedTabPosition(
      after: after is String && after.isNotEmpty ? after : null,
      before: before is String && before.isNotEmpty ? before : null,
    );
  }

  /// Name of the tab this tab is placed after.
  final String? after;

  /// Name of the tab this tab is placed before.
  final String? before;

  @override
  bool operator ==(Object other) =>
      other is FeaturedTabPosition &&
      other.after == after &&
      other.before == before;

  @override
  int get hashCode => Object.hash(after, before);
}

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
    this.position = const FeaturedTabPosition(),
    this.enabled = false,
    this.visibleToMinors = false,
    this.disclosureLabel = const {},
    this.hasContent = false,
  });

  /// Parses a featured tab entry from the public config endpoint.
  factory FeaturedTabConfig.fromJson(Map<String, dynamic> json) {
    return FeaturedTabConfig(
      id: json['id']?.toString() ?? '',
      slug: json['slug']?.toString() ?? '',
      label: _parseLocaleMap(json['label']),
      position: FeaturedTabPosition.fromJson(
        json['position'] as Map<String, dynamic>?,
      ),
      startsAt: _parseTimestamp(json['starts_at']),
      endsAt: _parseTimestamp(json['ends_at']),
      enabled: json['enabled'] as bool? ?? false,
      visibleToMinors: json['visible_to_minors'] as bool? ?? false,
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

  /// Placement relative to the canonical Explore tabs.
  final FeaturedTabPosition position;

  /// Start of the configured display window.
  final DateTime? startsAt;

  /// End of the configured display window.
  final DateTime? endsAt;

  /// Server kill switch. A disabled tab never renders.
  final bool enabled;

  /// Whether the tab may be shown to accounts flagged as minors.
  final bool visibleToMinors;

  /// Optional locale map for a short disclosure marker.
  final Map<String, String> disclosureLabel;

  /// Whether the server has precomputed content for this tab.
  final bool hasContent;

  /// Localized label for [localeCode], falling back to the `default` entry.
  ///
  /// Returns an empty string when the map carries neither, which callers
  /// treat as an unrenderable tab.
  String labelFor(String? localeCode) => _resolveLocale(label, localeCode);

  /// Localized disclosure marker for [localeCode], or `null` when unset.
  String? disclosureLabelFor(String? localeCode) {
    final resolved = _resolveLocale(disclosureLabel, localeCode);
    return resolved.isEmpty ? null : resolved;
  }

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

    return FeaturedTabsResponse(
      tabs: tabs,
      pollInterval: seconds != null && seconds > 0
          ? Duration(seconds: seconds)
          : defaultPollInterval,
    );
  }

  /// Poll cadence used when the server omits or malforms the interval.
  static const defaultPollInterval = Duration(minutes: 5);

  /// Tabs the server currently considers renderable.
  final List<FeaturedTabConfig> tabs;

  /// Server-supplied poll cadence for refetching this config.
  final Duration pollInterval;
}
