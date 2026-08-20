// ABOUTME: Service for the Music mode recording preference (iOS)
// ABOUTME: Controls whether the mic is captured without speech-tuned cleanup

import 'package:shared_preferences/shared_preferences.dart';
import 'package:unified_logger/unified_logger.dart';

/// Service for the user's "Music mode" recording preference.
///
/// When enabled, the camera captures the microphone without the platform's
/// speech-tuned noise suppression, which otherwise treats a sustained
/// instrument as noise and gates it away (#7796). Off by default: the
/// processing is what keeps ordinary talking clips clean.
///
/// iOS is the only platform that acts on this today — see
/// `DivineCamera.initialize(preferUnprocessedAudio:)`.
class MusicModePreferenceService {
  MusicModePreferenceService(this._prefs)
    : _isMusicModeEnabled = _prefs.getBool(prefsKey) ?? false;

  /// SharedPreferences key for the Music mode preference.
  static const String prefsKey = 'music_mode_enabled';

  final SharedPreferences _prefs;
  bool _isMusicModeEnabled;

  /// Whether the user has opted into unprocessed audio capture.
  bool get isMusicModeEnabled => _isMusicModeEnabled;

  /// Set the Music mode preference.
  ///
  /// Takes effect the next time the camera is initialized — the audio session
  /// mode is chosen once per capture session.
  Future<void> setMusicModeEnabled(bool enabled) async {
    try {
      await _prefs.setBool(prefsKey, enabled);
      _isMusicModeEnabled = enabled;

      Log.debug(
        'Music mode preference set to: $enabled',
        name: 'MusicModePreferenceService',
        category: LogCategory.system,
      );
    } catch (e) {
      Log.error(
        'Error saving music mode preference: $e',
        name: 'MusicModePreferenceService',
        category: LogCategory.system,
      );
    }
  }
}
