import 'package:flutter_test/flutter_test.dart';
import 'package:infinite_video_feed/src/utils/playback_failure_log.dart';
import 'package:unified_logger/unified_logger.dart';

void main() {
  late LogCaptureService logService;

  setUp(() async {
    logService = LogCaptureService();
    await logService.clearAllLogs();
  });

  void logFailure(Object error) {
    logPlaybackFailure(
      'Playback failed',
      name: 'PlaybackFailureLogTest',
      error: error,
      stackTrace: StackTrace.current,
    );
  }

  test('logs HTTP 202 media-processing failures as warnings', () {
    logFailure(Exception('CoreMediaErrorDomain error -12667 - HTTP 202'));

    final log = logService.getRecentLogs().single;
    expect(log.level, LogLevel.warning);
    expect(log.message, 'Playback failed');
    expect(log.category, LogCategory.video);
    expect(log.name, 'PlaybackFailureLogTest');
    expect(log.error, contains('HTTP 202'));
    expect(log.stackTrace, isNotNull);
  });

  test('logs HTTP 422 media-processing failures as warnings', () {
    logFailure(Exception('Source error. Response code: 422'));

    final log = logService.getRecentLogs().single;
    expect(log.level, LogLevel.warning);
    expect(log.error, contains('Response code: 422'));
    expect(log.stackTrace, isNotNull);
  });

  test('logs generic playback failures as errors', () {
    logFailure(Exception('Decoder failed'));

    final log = logService.getRecentLogs().single;
    expect(log.level, LogLevel.error);
    expect(log.error, contains('Decoder failed'));
    expect(log.stackTrace, isNotNull);
  });
}
