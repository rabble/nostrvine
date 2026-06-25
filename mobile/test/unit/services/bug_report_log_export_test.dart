// ABOUTME: Tests for BugReportService log export result value type and surface.
// ABOUTME: The full export flow is exercised via manual testing because it
// ABOUTME: depends on the device's Downloads directory and LogCaptureService
// ABOUTME: file IO that is awkward to mock in pure unit tests.

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/bug_report_service.dart';

void main() {
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
