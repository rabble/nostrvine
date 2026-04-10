// ABOUTME: Service for persisting the user's preferred app display locale
// ABOUTME: Separate from LanguagePreferenceService which handles Nostr content
// tagging

import 'package:openvine/utils/unified_logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists the user's preferred app display locale to SharedPreferences.
///
/// This controls the `locale:` parameter on [MaterialApp], overriding the
/// device default when set. A `null` locale means "follow device language".
///
/// This is separate from [LanguagePreferenceService], which manages the
/// content language for NIP-32 tagging on video events.
class LocalePreferenceService {
  /// Creates a [LocalePreferenceService] backed by [sharedPreferences].
  const LocalePreferenceService({
    required SharedPreferences sharedPreferences,
  }) : _prefs = sharedPreferences;

  final SharedPreferences _prefs;

  /// SharedPreferences key for the app locale preference.
  static const String prefsKey = 'app_locale';

  /// Returns the stored locale code, or `null` if using device default.
  String? getLocale() {
    try {
      return _prefs.getString(prefsKey);
    } catch (e) {
      Log.error(
        'Error reading app locale preference: $e',
        name: 'LocalePreferenceService',
        category: LogCategory.system,
      );
      return null;
    }
  }

  /// Persists the selected locale code.
  ///
  /// [localeCode] must be an ISO-639-1 code (e.g. `'en'`, `'es'`, `'tr'`).
  Future<void> setLocale(String localeCode) async {
    try {
      await _prefs.setString(prefsKey, localeCode);
      Log.debug(
        'App locale set to: $localeCode',
        name: 'LocalePreferenceService',
        category: LogCategory.system,
      );
    } catch (e) {
      Log.error(
        'Error saving app locale preference: $e',
        name: 'LocalePreferenceService',
        category: LogCategory.system,
      );
    }
  }

  /// Clears the custom locale, reverting to device default.
  Future<void> clearLocale() async {
    try {
      await _prefs.remove(prefsKey);
      Log.debug(
        'App locale cleared, using device default',
        name: 'LocalePreferenceService',
        category: LogCategory.system,
      );
    } catch (e) {
      Log.error(
        'Error clearing app locale preference: $e',
        name: 'LocalePreferenceService',
        category: LogCategory.system,
      );
    }
  }

  /// Map of supported locale codes to their native display names.
  ///
  /// Only include locales that have full (or near-full) translations.
  /// Add new entries here as translations are completed.
  static const Map<String, String> supportedLocales = {
    'en': 'English',
    'es': 'Espa\u00f1ol',
  };

  /// Returns the native display name for a locale code, or the code
  /// uppercased if not in the supported list.
  static String nativeNameFor(String localeCode) {
    return supportedLocales[localeCode] ?? localeCode.toUpperCase();
  }
}
