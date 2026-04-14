// ABOUTME: Tests for StartupPerformanceService auth shell readiness
// ABOUTME: Verifies that auth shell ready is tracked separately from UI ready

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/startup_performance_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('StartupPerformanceService', () {
    test('markAuthShellReady sets authShellReadyTime', () async {
      final service = StartupPerformanceService.instance;

      // Initialize if not already
      await service.initialize();

      service.markAuthShellReady();

      expect(service.authShellReadyTime, isNotNull);
    });

    test('markAuthShellReady is idempotent', () async {
      final service = StartupPerformanceService.instance;

      await service.initialize();

      service.markAuthShellReady();
      final firstTime = service.authShellReadyTime;

      // Call again — should not change
      service.markAuthShellReady();
      expect(service.authShellReadyTime, equals(firstTime));
    });

    test('auth shell ready is tracked separately from UI ready', () async {
      final service = StartupPerformanceService.instance;

      await service.initialize();

      service.markAuthShellReady();

      // Auth shell is ready but UI (home feed) may not be
      expect(service.authShellReadyTime, isNotNull);

      final metrics = service.getMetrics();
      expect(metrics['auth_shell_ready_ms'], isA<int>());
    });
  });
}
