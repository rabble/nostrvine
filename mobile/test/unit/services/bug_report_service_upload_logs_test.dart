// ABOUTME: Tests for BugReportService.uploadFullLogs()
// ABOUTME: Verifies Blossom upload success, failure fallback, and null service handling

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart' show BugReportData, LogEntry, LogLevel;
import 'package:openvine/services/blossom_upload_service.dart';
import 'package:openvine/services/bug_report_service.dart';

class _MockBlossomUploadService extends Mock implements BlossomUploadService {}

void main() {
  group('BugReportService.uploadFullLogs', () {
    late _MockBlossomUploadService mockBlossom;

    setUp(() {
      mockBlossom = _MockBlossomUploadService();
      registerFallbackValue(File(''));
    });

    BugReportData makeReportData({int logCount = 5}) {
      return BugReportData(
        reportId: 'test-123',
        timestamp: DateTime(2026, 3, 30),
        userDescription: 'Upload failed',
        deviceInfo: {'platform': 'ios', 'version': '18.0'},
        appVersion: '1.0.7+602',
        recentLogs: List.generate(
          logCount,
          (i) => LogEntry(
            timestamp: DateTime(2026, 3, 30, 10, 0, i),
            level: i % 3 == 0 ? LogLevel.error : LogLevel.info,
            message: 'Log entry $i',
          ),
        ),
        errorCounts: {'upload_failed': 2},
      );
    }

    test('returns Blossom URL on successful upload', () async {
      when(
        () => mockBlossom.uploadBugReport(
          bugReportFile: any(named: 'bugReportFile'),
        ),
      ).thenAnswer((_) async => 'https://media.divine.video/abc123.txt');

      final service = BugReportService(blossomUploadService: mockBlossom);
      final data = makeReportData();
      final url = await service.uploadFullLogs(data);

      expect(url, 'https://media.divine.video/abc123.txt');
      verify(
        () => mockBlossom.uploadBugReport(
          bugReportFile: any(named: 'bugReportFile'),
        ),
      ).called(1);
    });

    test('returns null when Blossom upload fails', () async {
      when(
        () => mockBlossom.uploadBugReport(
          bugReportFile: any(named: 'bugReportFile'),
        ),
      ).thenAnswer((_) async => null);

      final service = BugReportService(blossomUploadService: mockBlossom);
      final data = makeReportData();
      final url = await service.uploadFullLogs(data);

      expect(url, isNull);
    });

    test('returns null when Blossom upload throws', () async {
      when(
        () => mockBlossom.uploadBugReport(
          bugReportFile: any(named: 'bugReportFile'),
        ),
      ).thenThrow(Exception('network error'));

      final service = BugReportService(blossomUploadService: mockBlossom);
      final data = makeReportData();
      final url = await service.uploadFullLogs(data);

      expect(url, isNull);
    });

    test('returns null when BlossomUploadService is null', () async {
      final service = BugReportService();
      final data = makeReportData();
      final url = await service.uploadFullLogs(data);

      expect(url, isNull);
    });
  });
}
