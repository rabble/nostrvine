// ABOUTME: TDD tests for AudioSharingPreferenceService
// ABOUTME: Tests preference persistence and retrieval for audio reuse opt-in

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:openvine/services/audio_sharing_preference_service.dart';

void main() {
  group('AudioSharingPreferenceService', () {
    late AudioSharingPreferenceService service;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      service = AudioSharingPreferenceService();
      await service.initialize();
    });

    test('default preference is false (OFF)', () {
      expect(service.isAudioSharingEnabled, false);
    });

    test('can enable audio sharing', () async {
      await service.setAudioSharingEnabled(true);
      expect(service.isAudioSharingEnabled, true);
    });

    test('can disable audio sharing', () async {
      await service.setAudioSharingEnabled(true);
      expect(service.isAudioSharingEnabled, true);

      await service.setAudioSharingEnabled(false);
      expect(service.isAudioSharingEnabled, false);
    });

    test('preference persists after reinitialization', () async {
      await service.setAudioSharingEnabled(true);

      // Create new instance and reinitialize
      final newService = AudioSharingPreferenceService();
      await newService.initialize();

      expect(newService.isAudioSharingEnabled, true);
    });

    test('preference key is correct', () {
      expect(AudioSharingPreferenceService.prefsKey, 'audio_sharing_enabled');
    });
  });
}
