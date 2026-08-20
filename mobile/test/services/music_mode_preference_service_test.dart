import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/music_mode_preference_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group(MusicModePreferenceService, () {
    late SharedPreferences prefs;
    late MusicModePreferenceService service;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      service = MusicModePreferenceService(prefs);
    });

    test('defaults to disabled so speech capture keeps its cleanup', () {
      expect(service.isMusicModeEnabled, isFalse);
    });

    test('persists enabled preference', () async {
      await service.setMusicModeEnabled(true);

      final reloaded = MusicModePreferenceService(prefs);

      expect(reloaded.isMusicModeEnabled, isTrue);
    });

    test('persists disabled preference', () async {
      await service.setMusicModeEnabled(true);
      await service.setMusicModeEnabled(false);

      final reloaded = MusicModePreferenceService(prefs);

      expect(reloaded.isMusicModeEnabled, isFalse);
    });

    test('uses the key VideoRecorderBloc reads at camera init', () {
      // The bloc reads this key straight off SharedPreferences, so a rename
      // here silently strands the setting.
      expect(MusicModePreferenceService.prefsKey, 'music_mode_enabled');
    });
  });
}
