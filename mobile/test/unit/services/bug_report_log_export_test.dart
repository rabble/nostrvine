// ABOUTME: Tests for BugReportService log export result value type and surface.
// ABOUTME: The full export flow is exercised via manual testing because it
// ABOUTME: depends on the device's Downloads directory and LogCaptureService
// ABOUTME: file IO that is awkward to mock in pure unit tests.

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/bug_report_service.dart';
import 'package:openvine/utils/app_uptime.dart';
import 'package:openvine/utils/device_memory_util.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group(LogExportResult, () {
    test('preserves success and filePath when both are provided', () {
      const result = LogExportResult(
        success: true,
        filePath: '/Users/rabble/Downloads/openvine_full_logs.txt',
      );

      expect(result.success, isTrue);
      expect(
        result.filePath,
        equals('/Users/rabble/Downloads/openvine_full_logs.txt'),
      );
    });

    test('defaults filePath to null when not provided', () {
      const result = LogExportResult(success: true);

      expect(result.success, isTrue);
      expect(result.filePath, isNull);
    });

    test('represents failure with no filePath', () {
      const result = LogExportResult(success: false);

      expect(result.success, isFalse);
      expect(result.filePath, isNull);
      expect(result.cancelled, isFalse);
    });

    test('cancelled named constructor sets the cancelled flag', () {
      const result = LogExportResult.cancelled();

      expect(result.cancelled, isTrue);
      expect(result.success, isFalse);
      expect(result.filePath, isNull);
    });

    test('default cancelled flag is false', () {
      const result = LogExportResult(success: true, filePath: '/tmp/logs.txt');

      expect(result.cancelled, isFalse);
    });
  });

  group('buildDeviceDescription', () {
    const channel = MethodChannel('dev.fluttercommunity.plus/device_info');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

    Map<String, dynamic>? deviceInfoResponse;

    setUp(() {
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'getDeviceInfo') {
          final response = deviceInfoResponse;
          if (response == null) {
            throw PlatformException(code: 'unavailable');
          }
          return response;
        }
        return null;
      });
    });

    tearDown(() {
      messenger.setMockMethodCallHandler(channel, null);
      debugDefaultTargetPlatformOverride = null;
      deviceInfoResponse = null;
    });

    test('returns the utsname machine identifier on iOS', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      deviceInfoResponse = {
        'name': 'iPhone',
        'systemName': 'iOS',
        'systemVersion': '26.5.1',
        'model': 'iPhone',
        'localizedModel': 'iPhone',
        'identifierForVendor': null,
        'isPhysicalDevice': true,
        'utsname': {
          'sysname': 'Darwin',
          'nodename': 'iPhone',
          'release': '25.5.0',
          'version': 'Darwin Kernel',
          'machine': 'iPhone17,2',
        },
      };

      final description = await BugReportService.buildDeviceDescription();

      expect(description, equals('iPhone17,2'));
    });

    test('returns null when the device info probe fails', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      deviceInfoResponse = null;

      final description = await BugReportService.buildDeviceDescription();

      expect(description, isNull);
    });

    test('marks iOS simulators', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      deviceInfoResponse = {
        'name': 'iPhone',
        'systemName': 'iOS',
        'systemVersion': '26.5.1',
        'model': 'iPhone',
        'localizedModel': 'iPhone',
        'identifierForVendor': null,
        'isPhysicalDevice': false,
        'utsname': {
          'sysname': 'Darwin',
          'nodename': 'iPhone',
          'release': '25.5.0',
          'version': 'Darwin Kernel',
          'machine': 'arm64',
        },
      };

      final description = await BugReportService.buildDeviceDescription();

      expect(description, equals('arm64 (Simulator)'));
    });

    test('returns null on Windows so no computer name leaks', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;

      final description = await BugReportService.buildDeviceDescription();

      expect(description, isNull);
    });
  });

  group('buildEnvironmentDiagnostics', () {
    const connectivityChannel = MethodChannel(
      'dev.fluttercommunity.plus/connectivity',
    );
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

    setUp(() {
      messenger.setMockMethodCallHandler(connectivityChannel, (call) async {
        if (call.method == 'check') return <String>['wifi'];
        return null;
      });
    });

    tearDown(() {
      messenger.setMockMethodCallHandler(connectivityChannel, null);
      AppUptime.reset();
      DeviceMemoryUtil.resetCache();
    });

    test('reports network, text scale and memory tier', () async {
      final diagnostics = await BugReportService()
          .buildEnvironmentDiagnostics();

      expect(diagnostics, contains('Network: wifi'));
      expect(diagnostics, contains('Text Scale: '));
      expect(diagnostics, contains('Memory Tier: '));
    });

    test('reports app uptime once marked and omits it before', () async {
      final before = await BugReportService().buildEnvironmentDiagnostics();
      expect(before, isNot(contains('App Uptime: ')));

      AppUptime.markStarted();
      final after = await BugReportService().buildEnvironmentDiagnostics();
      expect(after, contains('App Uptime: '));
    });

    test('omits the cache line without a storage service', () async {
      final diagnostics = await BugReportService()
          .buildEnvironmentDiagnostics();

      expect(diagnostics, isNot(contains('Cache: ')));
    });
  });

  group('buildRuntimeDiagnostics', () {
    test('reports platform, CPU count and build mode', () {
      final diagnostics = BugReportService.buildRuntimeDiagnostics();

      expect(diagnostics, contains('Platform: '));
      expect(diagnostics, contains('CPU Cores: '));
      expect(diagnostics, contains('Build Mode: '));
    });

    test('reports process memory when ProcessInfo is supported', () {
      final diagnostics = BugReportService.buildRuntimeDiagnostics();

      // The production code omits this line if the ProcessInfo probe throws
      // on an unsupported platform, so only assert its format when present.
      if (diagnostics.contains('Process Memory: ')) {
        expect(diagnostics, contains('Process Memory: RSS '));
      }
    });

    test('reports a positive CPU core count', () {
      final diagnostics = BugReportService.buildRuntimeDiagnostics();
      final cpuLine = diagnostics
          .split('\n')
          .firstWhere((line) => line.startsWith('CPU Cores: '));
      final cores = int.parse(cpuLine.substring('CPU Cores: '.length).trim());

      expect(cores, greaterThan(0));
    });
  });
}
