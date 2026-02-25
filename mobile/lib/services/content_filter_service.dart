// ABOUTME: Service for per-category content filtering with Show/Warn/Hide preferences
// ABOUTME: Stores preferences in SharedPreferences, enforces age gate for adult categories

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:openvine/models/content_label.dart';
import 'package:openvine/services/age_verification_service.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// User preference for how a content category should be handled in feeds.
enum ContentFilterPreference {
  /// Show content normally without any overlay.
  show,

  /// Show content with a blur overlay and "View Anyway" button.
  warn,

  /// Filter content completely from feeds (not visible at all).
  hide,
}

/// Service that manages per-category content filter preferences.
///
/// Each [ContentLabel] can be independently set to [ContentFilterPreference]
/// (show, warn, or hide). Adult content categories are locked to [hide]
/// unless the user has verified they are 18+.
///
/// Persists preferences in SharedPreferences as a JSON map.
class ContentFilterService extends ChangeNotifier {
  ContentFilterService({required this.ageVerificationService});

  static const String _prefsKey = 'content_filter_prefs';
  static const String _migratedKey = 'content_filter_migrated';

  final AgeVerificationService ageVerificationService;

  final Map<ContentLabel, ContentFilterPreference> _preferences = {};
  bool _initialized = false;

  /// Categories considered "adult content" — locked to hide unless 18+ verified.
  static const Set<ContentLabel> adultCategories = {
    ContentLabel.nudity,
    ContentLabel.sexual,
    ContentLabel.porn,
  };

  /// Default preferences for each category.
  static const Map<ContentLabel, ContentFilterPreference> _defaults = {
    // Adult content — hide by default
    ContentLabel.nudity: ContentFilterPreference.hide,
    ContentLabel.sexual: ContentFilterPreference.hide,
    ContentLabel.porn: ContentFilterPreference.hide,
    // Violence — warn by default
    ContentLabel.graphicMedia: ContentFilterPreference.warn,
    ContentLabel.violence: ContentFilterPreference.warn,
    ContentLabel.selfHarm: ContentFilterPreference.warn,
    // Substances — show by default
    ContentLabel.drugs: ContentFilterPreference.show,
    ContentLabel.alcohol: ContentFilterPreference.show,
    ContentLabel.tobacco: ContentFilterPreference.show,
    ContentLabel.gambling: ContentFilterPreference.show,
    // Other — show by default
    ContentLabel.profanity: ContentFilterPreference.show,
    ContentLabel.hate: ContentFilterPreference.warn,
    ContentLabel.harassment: ContentFilterPreference.warn,
    ContentLabel.flashingLights: ContentFilterPreference.warn,
    ContentLabel.aiGenerated: ContentFilterPreference.show,
    ContentLabel.spoiler: ContentFilterPreference.show,
    ContentLabel.misleading: ContentFilterPreference.warn,
  };

  /// Whether the service has been initialized.
  bool get isInitialized => _initialized;

  /// Load preferences from SharedPreferences.
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      final prefs = await SharedPreferences.getInstance();

      // Run migration from old AdultContentPreference if needed
      await _migrateFromOldPreferences(prefs);

      // Load saved preferences
      final json = prefs.getString(_prefsKey);
      if (json != null) {
        final map = jsonDecode(json) as Map<String, dynamic>;
        for (final entry in map.entries) {
          final label = ContentLabel.fromValue(entry.key);
          final pref = _preferenceFromString(entry.value as String);
          if (label != null && pref != null) {
            _preferences[label] = pref;
          }
        }
      }

      // Fill in defaults for any missing categories
      for (final label in ContentLabel.values) {
        if (label == ContentLabel.other) continue;
        _preferences.putIfAbsent(label, () => _defaultFor(label));
      }

      _initialized = true;

      Log.debug(
        'Content filter preferences loaded: ${_preferences.length} categories',
        name: 'ContentFilterService',
        category: LogCategory.system,
      );
    } catch (e) {
      Log.error(
        'Error loading content filter preferences: $e',
        name: 'ContentFilterService',
        category: LogCategory.system,
      );
      // Fall back to defaults
      for (final label in ContentLabel.values) {
        if (label == ContentLabel.other) continue;
        _preferences.putIfAbsent(label, () => _defaultFor(label));
      }
      _initialized = true;
    }
  }

  /// Get the preference for a specific content label.
  ContentFilterPreference getPreference(ContentLabel label) {
    // Adult categories are locked to hide if not age-verified
    if (adultCategories.contains(label) &&
        !ageVerificationService.isAdultContentVerified) {
      return ContentFilterPreference.hide;
    }
    return _preferences[label] ?? _defaultFor(label);
  }

  /// Set the preference for a specific content label.
  ///
  /// Adult categories cannot be set to anything other than [hide]
  /// unless the user is age-verified.
  Future<void> setPreference(
    ContentLabel label,
    ContentFilterPreference preference,
  ) async {
    // Enforce age gate for adult categories
    if (adultCategories.contains(label) &&
        !ageVerificationService.isAdultContentVerified &&
        preference != ContentFilterPreference.hide) {
      Log.warning(
        'Cannot set adult category $label to $preference without age '
        'verification',
        name: 'ContentFilterService',
        category: LogCategory.system,
      );
      return;
    }

    _preferences[label] = preference;
    await _save();
    notifyListeners();

    Log.debug(
      'Content filter updated: ${label.displayName} → ${preference.name}',
      name: 'ContentFilterService',
      category: LogCategory.system,
    );
  }

  /// Get the most restrictive preference for a list of label value strings.
  ///
  /// Returns the most restrictive match:
  /// hide > warn > show
  ///
  /// Returns [ContentFilterPreference.show] if no labels match.
  ContentFilterPreference getPreferenceForLabels(List<String> labelValues) {
    var mostRestrictive = ContentFilterPreference.show;

    for (final value in labelValues) {
      final label = ContentLabel.fromValue(value);
      if (label == null) continue;

      final pref = getPreference(label);
      if (pref == ContentFilterPreference.hide) {
        return ContentFilterPreference.hide;
      }
      if (pref == ContentFilterPreference.warn) {
        mostRestrictive = ContentFilterPreference.warn;
      }
    }

    return mostRestrictive;
  }

  /// Get all current preferences as a map.
  Map<ContentLabel, ContentFilterPreference> get allPreferences =>
      Map.unmodifiable(_preferences);

  /// Reset all adult categories to hide.
  ///
  /// Called when the user un-checks age verification.
  Future<void> lockAdultCategories() async {
    for (final label in adultCategories) {
      _preferences[label] = ContentFilterPreference.hide;
    }
    await _save();
    notifyListeners();
  }

  /// Migrate from the old [AdultContentPreference] system.
  ///
  /// Maps:
  /// - alwaysShow → adult categories set to show
  /// - askEachTime → adult categories set to warn
  /// - neverShow → adult categories set to hide
  Future<void> _migrateFromOldPreferences(SharedPreferences prefs) async {
    // Only migrate once
    if (prefs.getBool(_migratedKey) == true) return;

    final oldPreferenceIndex = prefs.getInt('adult_content_preference');
    if (oldPreferenceIndex != null &&
        oldPreferenceIndex >= 0 &&
        oldPreferenceIndex < AdultContentPreference.values.length) {
      final oldPref = AdultContentPreference.values[oldPreferenceIndex];

      final newPref = switch (oldPref) {
        AdultContentPreference.alwaysShow => ContentFilterPreference.show,
        AdultContentPreference.askEachTime => ContentFilterPreference.warn,
        AdultContentPreference.neverShow => ContentFilterPreference.hide,
      };

      // Apply to all adult categories
      for (final label in adultCategories) {
        _preferences[label] = newPref;
      }

      Log.info(
        'Migrated old adult content preference '
        '(${oldPref.name}) → ${newPref.name} for adult categories',
        name: 'ContentFilterService',
        category: LogCategory.system,
      );
    }

    await prefs.setBool(_migratedKey, true);
  }

  /// Persist current preferences to SharedPreferences.
  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final map = <String, String>{};
      for (final entry in _preferences.entries) {
        map[entry.key.value] = entry.value.name;
      }
      await prefs.setString(_prefsKey, jsonEncode(map));
    } catch (e) {
      Log.error(
        'Error saving content filter preferences: $e',
        name: 'ContentFilterService',
        category: LogCategory.system,
      );
    }
  }

  /// Get the default preference for a given label.
  static ContentFilterPreference _defaultFor(ContentLabel label) {
    return _defaults[label] ?? ContentFilterPreference.show;
  }

  /// Parse a preference from its string name.
  static ContentFilterPreference? _preferenceFromString(String value) {
    for (final pref in ContentFilterPreference.values) {
      if (pref.name == value) return pref;
    }
    return null;
  }
}
