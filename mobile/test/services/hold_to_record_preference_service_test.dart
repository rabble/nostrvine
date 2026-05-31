import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/hold_to_record_preference_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group(HoldToRecordPreferenceService, () {
    late SharedPreferences prefs;
    late HoldToRecordPreferenceService service;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      service = HoldToRecordPreferenceService(prefs);
    });

    test('defaults to disabled', () {
      expect(service.isHoldToRecordEnabled, isFalse);
    });

    test('persists enabled preference', () async {
      await service.setHoldToRecordEnabled(true);

      final reloaded = HoldToRecordPreferenceService(prefs);

      expect(reloaded.isHoldToRecordEnabled, isTrue);
    });

    test('persists disabled preference', () async {
      await service.setHoldToRecordEnabled(true);
      await service.setHoldToRecordEnabled(false);

      final reloaded = HoldToRecordPreferenceService(prefs);

      expect(reloaded.isHoldToRecordEnabled, isFalse);
    });

    test('uses stable preference key', () {
      expect(HoldToRecordPreferenceService.prefsKey, 'hold_to_record_enabled');
    });
  });
}
