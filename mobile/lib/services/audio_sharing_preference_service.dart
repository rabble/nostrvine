// ABOUTME: Service for managing the global audio sharing preference
// ABOUTME: Controls whether user's audio is available for reuse by default

import 'package:openvine/utils/unified_logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service for managing the user's preference for making audio available
/// for reuse by other users. This is a global setting that can be overridden
/// on a per-video basis during publishing.
class AudioSharingPreferenceService {
  /// SharedPreferences key for the audio sharing preference
  static const String prefsKey = 'audio_sharing_enabled';

  bool _isAudioSharingEnabled = false;

  /// Whether the user has enabled audio sharing by default
  bool get isAudioSharingEnabled => _isAudioSharingEnabled;

  /// Initialize the service by loading the saved preference
  Future<void> initialize() async {
    await _loadPreference();
  }

  Future<void> _loadPreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isAudioSharingEnabled = prefs.getBool(prefsKey) ?? false;
    } catch (e) {
      Log.error(
        'Error loading audio sharing preference: $e',
        name: 'AudioSharingPreferenceService',
        category: LogCategory.system,
      );
    }
  }

  /// Set the audio sharing preference
  Future<void> setAudioSharingEnabled(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(prefsKey, enabled);
      _isAudioSharingEnabled = enabled;

      Log.debug(
        'Audio sharing preference set to: $enabled',
        name: 'AudioSharingPreferenceService',
        category: LogCategory.system,
      );
    } catch (e) {
      Log.error(
        'Error saving audio sharing preference: $e',
        name: 'AudioSharingPreferenceService',
        category: LogCategory.system,
      );
    }
  }
}
