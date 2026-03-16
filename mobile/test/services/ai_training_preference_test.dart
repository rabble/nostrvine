// ABOUTME: Tests for AiTrainingPreferenceService
// ABOUTME: Tests preference persistence and default opt-out for AI training

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/ai_training_preference_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group(AiTrainingPreferenceService, () {
    late AiTrainingPreferenceService service;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      service = AiTrainingPreferenceService();
      await service.initialize();
    });

    test('default preference is true (opted out)', () {
      expect(service.isOptOutEnabled, isTrue);
    });

    test('can disable opt-out', () async {
      await service.setOptOutEnabled(false);
      expect(service.isOptOutEnabled, isFalse);
    });

    test('can re-enable opt-out', () async {
      await service.setOptOutEnabled(false);
      expect(service.isOptOutEnabled, isFalse);

      await service.setOptOutEnabled(true);
      expect(service.isOptOutEnabled, isTrue);
    });

    test('preference persists after reinitialization', () async {
      await service.setOptOutEnabled(false);

      final newService = AiTrainingPreferenceService();
      await newService.initialize();

      expect(newService.isOptOutEnabled, isFalse);
    });

    test('preference key is correct', () {
      expect(
        AiTrainingPreferenceService.prefsKey,
        equals('ai_training_opt_out_enabled'),
      );
    });
  });
}
