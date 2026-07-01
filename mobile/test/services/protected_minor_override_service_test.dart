// ABOUTME: Tests the debug-only protected-minor override service (#174 QA aid)

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/protected_minor_override_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('override is null by default, then reflects set and clear', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final service = ProtectedMinorOverrideService(prefs: prefs);

    expect(service.getOverride(), isNull);

    await service.setOverride(true);
    expect(service.getOverride(), isTrue);

    await service.setOverride(false);
    expect(service.getOverride(), isFalse);

    await service.clearOverride();
    expect(service.getOverride(), isNull);
  });
}
