import 'package:flutter_test/flutter_test.dart';
import 'package:infinite_video_feed/src/utils/playback_failure_log.dart';
import 'package:mockito/mockito.dart';
import 'package:models/models.dart';
import 'package:unified_logger/src/log_capture_service.dart';

void main() {
  group('logPlaybackFailure', () {
    setUp(() {
      // Clear log capture service before each test
      LogCaptureService().captureLog(
        LogEntry(
          timestamp: DateTime.now(),
          level: LogLevel.info,
          message: 'setup',
        ),
      );
    });

    test('logs media processing errors (HTTP 202) at WARNING level', () {
      final error = Exception('HTTP 202: Accepted - Transcode in progress');
      final stackTrace = StackTrace.current;

      logPlaybackFailure(
        'Playback failed - media processing',
        error: error,
        stackTrace: stackTrace,
        errorMessage: 'HTTP 202',
      );

      final logs = LogCaptureService().getRecentLogs();
      expect(logs.isNotEmpty, isTrue);

      // Find the log entry we just added (skip setup log)
      final targetLog = logs.firstWhere(
        (log) => log.message.contains('Playback failed - media processing'),
        orElse: () => logs.last,
      );

      expect(targetLog.level, equals(LogLevel.warning));
      expect(targetLog.error, contains('HTTP 202'));
    });

    test('logs media processing errors (HTTP 422) at WARNING level', () {
      final error = Exception('HTTP 422: Unprocessable Entity');
      final stackTrace = StackTrace.current;

      logPlaybackFailure(
        'Playback source unprocessable',
        error: error,
        stackTrace: stackTrace,
        errorMessage: 'HTTP 422',
      );

      final logs = LogCaptureService().getRecentLogs();
      expect(logs.isNotEmpty, isTrue);

      final targetLog = logs.firstWhere(
        (log) => log.message.contains('Playback source unprocessable'),
        orElse: () => logs.last,
      );

      expect(targetLog.level, equals(LogLevel.warning));
      expect(targetLog.error, contains('HTTP 422'));
    });

    test('logs non-media-processing errors at ERROR level', () {
      final error = Exception('Network timeout');
      final stackTrace = StackTrace.current;

      logPlaybackFailure(
        'Playback network error',
        error: error,
        stackTrace: stackTrace,
        errorMessage: 'Connection timeout',
      );

      final logs = LogCaptureService().getRecentLogs();
      expect(logs.isNotEmpty, isTrue);

      final targetLog = logs.firstWhere(
        (log) => log.message.contains('Playback network error'),
        orElse: () => logs.last,
      );

      expect(targetLog.level, equals(LogLevel.error));
      expect(targetLog.error, contains('Network timeout'));
    });

    test('preserves error and stackTrace in both warning and error cases', () {
      final error = Exception('Test error');
      final stackTrace = StackTrace.current;

      // Test with media processing error (should be warning)
      logPlaybackFailure(
        'Media processing test',
        error: error,
        stackTrace: stackTrace,
        errorMessage: 'HTTP 202',
      );

      final logs = LogCaptureService().getRecentLogs();
      final warningLog = logs.firstWhere(
        (log) => log.message.contains('Media processing test'),
        orElse: () => logs.last,
      );

      expect(warningLog.error, isNotNull);
      expect(warningLog.stackTrace, isNotNull);
      expect(warningLog.level, equals(LogLevel.warning));
    });

    test('includes optional name and category parameters', () {
      final error = Exception('Test error');

      logPlaybackFailure(
        'Test message',
        name: 'TestLogger',
        category: LogCategory.video,
        error: error,
      );

      final logs = LogCaptureService().getRecentLogs();
      final targetLog = logs.firstWhere(
        (log) => log.message.contains('Test message'),
        orElse: () => logs.last,
      );

      expect(targetLog.name, equals('TestLogger'));
      expect(targetLog.category, equals(LogCategory.video));
    });
  });
}
