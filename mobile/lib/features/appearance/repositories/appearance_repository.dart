import 'package:openvine/features/appearance/models/appearance_mode.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists the user's appearance choice on the current device.
class AppearanceRepository {
  AppearanceRepository(this._preferences);

  static const _preferenceKey = 'appearance_mode_preference';

  final SharedPreferences _preferences;

  Future<AppearanceMode> load() async {
    final storedValue = _preferences.getString(_preferenceKey);
    return AppearanceMode.values.firstWhere(
      (mode) => mode.name == storedValue,
      orElse: () => AppearanceMode.system,
    );
  }

  Future<void> save(AppearanceMode mode) async {
    final saved = await _preferences.setString(_preferenceKey, mode.name);
    if (!saved) {
      throw StateError('Unable to persist appearance preference');
    }
  }
}
