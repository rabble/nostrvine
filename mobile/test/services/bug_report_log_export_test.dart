// ABOUTME: Tests for BugReportService log export result value type and surface.
// ABOUTME: The full export flow is exercised via manual testing because it
// ABOUTME: depends on the device's Downloads directory and LogCaptureService
// ABOUTME: file IO that is awkward to mock in pure unit tests.

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart' show LogEntry, LogLevel;
import 'package:openvine/services/bug_report_service.dart';
import 'package:openvine/services/storage_management_service.dart';
import 'package:openvine/utils/app_uptime.dart';
import 'package:openvine/utils/device_memory_util.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:unified_logger/unified_logger.dart' show LogCaptureService;

class _MockStorageManagementService extends Mock
    implements StorageManagementService {}

Future<PackageInfo> _loadPackageInfo() async => PackageInfo(
  appName: 'Divine',
  packageName: 'video.divine',
  version: '1.0.21',
  buildNumber: '849',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group(LogExportResult, () {
    test('saved carries the path the user picked', () {
      const path = '/Users/rabble/Downloads/openvine_full_logs.txt';
      const result = LogExportResult.saved(path);

      expect(result.status, equals(LogExportStatus.saved));
      expect(result.filePath, equals(path));
    });

    test('shared has no file path', () {
      const result = LogExportResult.shared();

      expect(result.filePath, isNull);
    });

    // The regression in #8113: an Android share whose outcome the platform
    // declines to report is not a failure, and reporting it as one told the
    // user log export was broken when it had just worked.
    test('unconfirmed stays distinct from failure', () {
      const result = LogExportResult.unconfirmed();

      expect(result.status, equals(LogExportStatus.unconfirmed));
    });

    test('cancelled has its own status and no path', () {
      const result = LogExportResult.cancelled();

      expect(result.status, equals(LogExportStatus.cancelled));
      expect(result.filePath, isNull);
    });

    // #8114: an empty capture buffer is the user's to fix by reproducing
    // without restarting, so it must stay distinguishable from a real error.
    test('noLogs is distinct from failed', () {
      const noLogs = LogExportResult.noLogs();
      const failed = LogExportResult.failed();

      expect(noLogs.status, equals(LogExportStatus.noLogs));
      expect(failed.status, equals(LogExportStatus.failed));
      expect(noLogs.status, isNot(equals(failed.status)));
    });
  });

  group('buildLogClipboardText', () {
    setUp(() async {
      await LogCaptureService().clearAllLogs();
    });

    tearDown(() async {
      await LogCaptureService().clearAllLogs();
      AppUptime.reset();
      DeviceMemoryUtil.resetCache();
    });

    // #8114: an empty buffer has to be reportable as "nothing captured"
    // rather than handed over as a bare header the user would paste into a
    // ticket believing it held their logs.
    test('reports no logs when nothing has been captured', () async {
      final result = await BugReportService(
        packageInfoLoader: _loadPackageInfo,
      ).buildLogClipboardText();

      expect(result.status, equals(LogClipboardStatus.noLogs));
      expect(result.text, isNull);
    });

    test('includes the header and the captured line', () async {
      LogCaptureService().captureLog(
        LogEntry(
          timestamp: DateTime(2026, 8, 24),
          level: LogLevel.error,
          message: 'upload stalled at 40 percent',
        ),
      );

      final result = await BugReportService(
        packageInfoLoader: _loadPackageInfo,
      ).buildLogClipboardText();

      expect(result.status, equals(LogClipboardStatus.success));
      expect(result.text, contains('OpenVine Comprehensive Log Export'));
      expect(result.text, contains('App Version: 1.0.21+849'));
      expect(result.text, contains('upload stalled at 40 percent'));
    });

    // #8112: the clipboard crosses a Binder transaction, so an uncapped
    // copy of a full 5-10 MB buffer is the one outcome that cannot work.
    test('caps the copy and keeps the newest entries', () async {
      final filler = 'x' * 512;
      for (var i = 0; i < 400; i++) {
        LogCaptureService().captureLog(
          LogEntry(
            timestamp: DateTime(2026, 8, 24).add(Duration(seconds: i)),
            level: LogLevel.info,
            message: 'entry $i $filler',
          ),
        );
      }

      final result = await BugReportService(
        packageInfoLoader: _loadPackageInfo,
      ).buildLogClipboardText();
      final text = result.text!;

      expect(
        utf8.encode(text).length,
        lessThanOrEqualTo(BugReportService.logClipboardByteBudget),
      );
      expect(text, contains('entry 399'));
      expect(text, contains('earlier entries omitted'));
      expect(text, isNot(contains('entry 0 ')));
    });

    test('includes the omission marker within the byte ceiling', () async {
      for (var i = 0; i < 200; i++) {
        LogCaptureService().captureLog(
          LogEntry(
            timestamp: DateTime(2026, 8, 24).add(Duration(seconds: i)),
            level: LogLevel.info,
            message: 'entry $i ${'x' * 1024}',
          ),
        );
      }

      final result = await BugReportService(
        packageInfoLoader: _loadPackageInfo,
      ).buildLogClipboardText();

      expect(result.status, equals(LogClipboardStatus.success));
      expect(
        utf8.encode(result.text!).length,
        lessThanOrEqualTo(BugReportService.logClipboardByteBudget),
      );
      expect(result.text, contains('earlier entries omitted'));
    });

    test(
      'keeps useful content when the newest line exceeds the budget',
      () async {
        LogCaptureService().captureLog(
          LogEntry(
            timestamp: DateTime(2026, 8, 24),
            level: LogLevel.error,
            message:
                'newest failure ${'z' * BugReportService.logClipboardByteBudget}',
          ),
        );

        final result = await BugReportService(
          packageInfoLoader: _loadPackageInfo,
        ).buildLogClipboardText();

        expect(result.status, equals(LogClipboardStatus.success));
        expect(result.text, contains('newest failure'));
        expect(
          utf8.encode(result.text!).length,
          lessThanOrEqualTo(BugReportService.logClipboardByteBudget),
        );
      },
    );

    test(
      'reports a header diagnostic failure separately from no logs',
      () async {
        LogCaptureService().captureLog(
          LogEntry(
            timestamp: DateTime(2026, 8, 24),
            level: LogLevel.error,
            message: 'captured before diagnostics failed',
          ),
        );

        final result = await BugReportService(
          packageInfoLoader: () async =>
              throw StateError('diagnostics unavailable'),
        ).buildLogClipboardText();

        expect(result.status, equals(LogClipboardStatus.failed));
        expect(result.text, isNull);
      },
    );
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

    test('reports cache usage against matching category budgets', () async {
      final storage = _MockStorageManagementService();
      when(storage.cacheUsage).thenAnswer(
        (_) async => const CacheUsage(
          video: CacheUsageCategory(
            usedBytes: 1536 * 1024 * 1024,
            limitBytes: 2 * 1024 * 1024 * 1024,
          ),
          images: CacheUsageCategory(
            usedBytes: 128 * 1024 * 1024,
            limitBytes: 256 * 1024 * 1024,
          ),
          transitionSeams: CacheUsageCategory(
            usedBytes: 64 * 1024 * 1024,
            limitBytes: 200 * 1024 * 1024,
          ),
          tempRenders: CacheUsageCategory(usedBytes: 32 * 1024 * 1024),
        ),
      );

      final diagnostics = await BugReportService(
        storageManagementService: storage,
      ).buildEnvironmentDiagnostics();

      expect(
        diagnostics,
        contains(
          'Cache: video 1.5 GB/2.0 GB '
          '(75.0%, within limit, 1610612736/2147483648 bytes) · '
          'images 128.0 MB/256.0 MB '
          '(50.0%, within limit, 134217728/268435456 bytes) · '
          'seams 64.0 MB/200.0 MB '
          '(32.0%, within limit, 67108864/209715200 bytes) · '
          'temp 32.0 MB',
        ),
      );
      expect(diagnostics, isNot(contains('used /')));
      expect(diagnostics, contains('within limit'));
    });

    test('reports exact cache limit status at and over budget', () async {
      final storage = _MockStorageManagementService();
      when(storage.cacheUsage).thenAnswer(
        (_) async => const CacheUsage(
          video: CacheUsageCategory(
            usedBytes: 2 * 1024 * 1024 * 1024,
            limitBytes: 2 * 1024 * 1024 * 1024,
          ),
          images: CacheUsageCategory(
            usedBytes: 300 * 1024 * 1024,
            limitBytes: 256 * 1024 * 1024,
          ),
          transitionSeams: CacheUsageCategory(
            usedBytes: 0,
            limitBytes: 200 * 1024 * 1024,
          ),
          tempRenders: CacheUsageCategory(usedBytes: 0),
        ),
      );

      final diagnostics = await BugReportService(
        storageManagementService: storage,
      ).buildEnvironmentDiagnostics();

      expect(
        diagnostics,
        contains(
          'video 2.0 GB/2.0 GB '
          '(100.0%, at limit, 2147483648/2147483648 bytes)',
        ),
      );
      expect(
        diagnostics,
        contains(
          'images 300.0 MB/256.0 MB '
          '(117.2%, over limit by 44.0 MB, 314572800/268435456 bytes)',
        ),
      );
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
