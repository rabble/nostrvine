// ABOUTME: Service for managing the AI training opt-out preference
// ABOUTME: Controls whether CAWG training-mining assertion is embedded in C2PA manifests

import 'package:openvine/utils/unified_logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service for managing the user's preference for opting out of AI training
/// and data mining. When enabled, a `cawg.training-mining` assertion is
/// embedded in C2PA manifests marking all training/mining uses as "notAllowed".
///
/// Based on the CAWG Training and Data Mining specification v1.1:
/// https://cawg.io/training-and-data-mining/1.1/
class AiTrainingPreferenceService {
  /// SharedPreferences key for the AI training opt-out preference
  static const String prefsKey = 'ai_training_opt_out_enabled';

  bool _isOptOutEnabled = true;

  /// Whether the user has opted out of AI training and data mining.
  /// Defaults to true (opted out) to protect creators by default.
  bool get isOptOutEnabled => _isOptOutEnabled;

  /// Initialize the service by loading the saved preference
  Future<void> initialize() async {
    await _loadPreference();
  }

  Future<void> _loadPreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Default to true - protect creators by default
      _isOptOutEnabled = prefs.getBool(prefsKey) ?? true;
    } catch (e) {
      Log.error(
        'Error loading AI training preference: $e',
        name: 'AiTrainingPreferenceService',
        category: LogCategory.system,
      );
    }
  }

  /// Set the AI training opt-out preference
  Future<void> setOptOutEnabled(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(prefsKey, enabled);
      _isOptOutEnabled = enabled;

      Log.debug(
        'AI training opt-out preference set to: $enabled',
        name: 'AiTrainingPreferenceService',
        category: LogCategory.system,
      );
    } catch (e) {
      Log.error(
        'Error saving AI training preference: $e',
        name: 'AiTrainingPreferenceService',
        category: LogCategory.system,
      );
    }
  }
}
