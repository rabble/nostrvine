// ABOUTME: Service for managing the user's preferred content language
// ABOUTME: Stores ISO-639-1 language code used for NIP-32 labeling on video events

import 'dart:ui';

import 'package:openvine/utils/unified_logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service for managing the user's preferred content language.
///
/// The language code is used to tag published video events with NIP-32
/// self-labeling (`L`/`l` tags with ISO-639-1 namespace).
///
/// When no custom language is set, the device's OS language is used.
class LanguagePreferenceService {
  /// SharedPreferences key for the content language preference
  static const String prefsKey = 'content_language';

  String? _customLanguage;

  /// Whether the user has overridden the default device language.
  bool get isCustomLanguageSet => _customLanguage != null;

  /// Returns the content language code (ISO-639-1).
  ///
  /// If the user has set a custom language, returns that.
  /// Otherwise returns the device's OS language code.
  String get contentLanguage =>
      _customLanguage ?? PlatformDispatcher.instance.locale.languageCode;

  /// Initialize the service by loading the saved preference.
  Future<void> initialize() async {
    await _loadPreference();
  }

  Future<void> _loadPreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _customLanguage = prefs.getString(prefsKey);
    } catch (e) {
      Log.error(
        'Error loading language preference: $e',
        name: 'LanguagePreferenceService',
        category: LogCategory.system,
      );
    }
  }

  /// Set the content language preference.
  ///
  /// [languageCode] must be an ISO-639-1 code (e.g. `'en'`, `'es'`, `'pt'`).
  Future<void> setContentLanguage(String languageCode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(prefsKey, languageCode);
      _customLanguage = languageCode;

      Log.debug(
        'Content language set to: $languageCode',
        name: 'LanguagePreferenceService',
        category: LogCategory.system,
      );
    } catch (e) {
      Log.error(
        'Error saving language preference: $e',
        name: 'LanguagePreferenceService',
        category: LogCategory.system,
      );
    }
  }

  /// Clear the custom language preference, reverting to device default.
  Future<void> clearContentLanguage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(prefsKey);
      _customLanguage = null;

      Log.debug(
        'Content language cleared, using device default',
        name: 'LanguagePreferenceService',
        category: LogCategory.system,
      );
    } catch (e) {
      Log.error(
        'Error clearing language preference: $e',
        name: 'LanguagePreferenceService',
        category: LogCategory.system,
      );
    }
  }

  /// Map of common ISO-639-1 language codes to display names.
  static const Map<String, String> supportedLanguages = {
    'en': 'English',
    'es': 'Spanish',
    'pt': 'Portuguese',
    'ja': 'Japanese',
    'fr': 'French',
    'de': 'German',
    'zh': 'Chinese',
    'ko': 'Korean',
    'ar': 'Arabic',
    'hi': 'Hindi',
    'it': 'Italian',
    'ru': 'Russian',
    'tr': 'Turkish',
    'nl': 'Dutch',
    'pl': 'Polish',
    'sv': 'Swedish',
    'th': 'Thai',
    'vi': 'Vietnamese',
    'id': 'Indonesian',
    'uk': 'Ukrainian',
  };

  /// Returns the display name for a language code, or the code itself
  /// if not found in the supported languages map.
  static String displayNameFor(String languageCode) {
    return supportedLanguages[languageCode] ?? languageCode.toUpperCase();
  }
}
