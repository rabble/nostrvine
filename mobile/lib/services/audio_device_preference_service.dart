// ABOUTME: Service for managing the preferred audio input device on macOS
// ABOUTME: Stores user's preferred microphone choice for video recording

import 'package:openvine/utils/unified_logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service for managing the user's preferred audio input device for recording.
/// On macOS, users can have multiple audio devices (built-in mic, USB mics,
/// virtual devices like Zoom). This service stores the user's preferred choice.
class AudioDevicePreferenceService {
  /// SharedPreferences key for the preferred audio device ID
  static const String prefsKey = 'preferred_audio_device_id';

  String? _preferredDeviceId;

  /// The user's preferred audio device ID, or null if none set (use auto-select)
  String? get preferredDeviceId => _preferredDeviceId;

  /// Initialize the service by loading the saved preference
  Future<void> initialize() async {
    await _loadPreference();
  }

  Future<void> _loadPreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _preferredDeviceId = prefs.getString(prefsKey);
      if (_preferredDeviceId != null) {
        Log.debug(
          'Loaded preferred audio device: $_preferredDeviceId',
          name: 'AudioDevicePreferenceService',
          category: LogCategory.system,
        );
      }
    } catch (e) {
      Log.error(
        'Error loading audio device preference: $e',
        name: 'AudioDevicePreferenceService',
        category: LogCategory.system,
      );
    }
  }

  /// Set the preferred audio device ID.
  /// Pass null to reset to auto-select mode.
  Future<void> setPreferredDeviceId(String? deviceId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (deviceId == null) {
        await prefs.remove(prefsKey);
      } else {
        await prefs.setString(prefsKey, deviceId);
      }
      _preferredDeviceId = deviceId;

      Log.debug(
        'Audio device preference set to: ${deviceId ?? "auto-select"}',
        name: 'AudioDevicePreferenceService',
        category: LogCategory.system,
      );
    } catch (e) {
      Log.error(
        'Error saving audio device preference: $e',
        name: 'AudioDevicePreferenceService',
        category: LogCategory.system,
      );
    }
  }

  /// Check if the user has a manually set preference (vs auto-select)
  bool get hasManualPreference => _preferredDeviceId != null;
}
