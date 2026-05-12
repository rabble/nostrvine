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
}
