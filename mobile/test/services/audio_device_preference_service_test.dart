// ABOUTME: Tests for AudioDevicePreferenceService.
// ABOUTME: Validates initialization, preference persistence, and error handling.

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/audio_device_preference_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group(AudioDevicePreferenceService, () {
    late AudioDevicePreferenceService service;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      service = AudioDevicePreferenceService();
    });

    group('initialize', () {
      test('loads null when no preference is stored', () async {
        await service.initialize();
        expect(service.preferredDeviceId, isNull);
      });

      test('loads stored preference', () async {
        SharedPreferences.setMockInitialValues({
          AudioDevicePreferenceService.prefsKey: 'usb-mic-001',
        });

        await service.initialize();

        expect(service.preferredDeviceId, equals('usb-mic-001'));
      });

      test('is idempotent when called multiple times', () async {
        SharedPreferences.setMockInitialValues({
          AudioDevicePreferenceService.prefsKey: 'mic-1',
        });

        await service.initialize();
        expect(service.preferredDeviceId, equals('mic-1'));

        // Change underlying prefs after first init
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(AudioDevicePreferenceService.prefsKey, 'mic-2');

        // Second call is a no-op — value stays the same
        await service.initialize();
        expect(service.preferredDeviceId, equals('mic-1'));
      });
    });

    group('setPreferredDeviceId', () {
      test('stores device ID', () async {
        await service.setPreferredDeviceId('built-in-mic');

        expect(service.preferredDeviceId, equals('built-in-mic'));

        final prefs = await SharedPreferences.getInstance();
        expect(
          prefs.getString(AudioDevicePreferenceService.prefsKey),
          equals('built-in-mic'),
        );
      });

      test('removes preference when null is passed', () async {
        // First set a value
        await service.setPreferredDeviceId('usb-mic');
        expect(service.preferredDeviceId, equals('usb-mic'));

        // Then clear it
        await service.setPreferredDeviceId(null);

        expect(service.preferredDeviceId, isNull);

        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString(AudioDevicePreferenceService.prefsKey), isNull);
      });

      test('overwrites existing preference', () async {
        await service.setPreferredDeviceId('mic-1');
        expect(service.preferredDeviceId, equals('mic-1'));

        await service.setPreferredDeviceId('mic-2');
        expect(service.preferredDeviceId, equals('mic-2'));
      });
    });

    group('hasManualPreference', () {
      test('returns false when no preference is set', () {
        expect(service.hasManualPreference, isFalse);
      });

      test('returns true after setting a preference', () async {
        await service.setPreferredDeviceId('some-device');
        expect(service.hasManualPreference, isTrue);
      });

      test('returns false after clearing preference', () async {
        await service.setPreferredDeviceId('some-device');
        expect(service.hasManualPreference, isTrue);

        await service.setPreferredDeviceId(null);
        expect(service.hasManualPreference, isFalse);
      });
    });

    group('preferredDeviceId', () {
      test('returns null by default', () {
        expect(service.preferredDeviceId, isNull);
      });

      test('returns the set value', () async {
        await service.setPreferredDeviceId('test-device');
        expect(service.preferredDeviceId, equals('test-device'));
      });
    });

    group('prefsKey', () {
      test('is a non-empty string constant', () {
        expect(
          AudioDevicePreferenceService.prefsKey,
          equals('preferred_audio_device_id'),
        );
      });
    });

    group('persistence round-trip', () {
      test('value survives across service instances', () async {
        SharedPreferences.setMockInitialValues({});

        // Write with first instance
        final service1 = AudioDevicePreferenceService();
        await service1.setPreferredDeviceId('persistent-mic');

        // Read with second instance
        final service2 = AudioDevicePreferenceService();
        await service2.initialize();

        expect(service2.preferredDeviceId, equals('persistent-mic'));
      });
    });
  });
}
