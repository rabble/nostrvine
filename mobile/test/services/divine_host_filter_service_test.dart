import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/divine_host_filter_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('DivineHostFilterService', () {
    test('defaults to disabled', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final service = DivineHostFilterService(prefs);

      expect(service.showDivineHostedOnly, isFalse);
    });

    test('persists enabled state', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final service = DivineHostFilterService(prefs);
      await service.setShowDivineHostedOnly(true);

      expect(service.showDivineHostedOnly, isTrue);

      final reloaded = DivineHostFilterService(prefs);
      expect(reloaded.showDivineHostedOnly, isTrue);
    });

    test('notifies listeners when value changes', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final service = DivineHostFilterService(prefs);
      var notificationCount = 0;
      service.addListener(() => notificationCount++);

      await service.setShowDivineHostedOnly(true);
      await service.setShowDivineHostedOnly(true);

      expect(notificationCount, 1);
    });
  });
}
