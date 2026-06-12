import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/services/pro_video_editor_log_forwarder.dart';
import 'package:pro_video_editor/pro_video_editor.dart';
import 'package:unified_logger/unified_logger.dart';

class _MockProVideoEditor extends Mock implements ProVideoEditor {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  LogEntry? latestWithMessage(String message) {
    final matches = LogCaptureService().getRecentLogs().where(
      (entry) => entry.message == message,
    );
    return matches.isEmpty ? null : matches.last;
  }

  NativeLogEntry entry(
    NativeLogLevel level,
    String message, {
    String? tag,
    String? stackTrace,
  }) => NativeLogEntry(
    level: level,
    message: message,
    tag: tag,
    stackTrace: stackTrace,
    timestamp: DateTime.now(),
  );

  tearDown(() async {
    await ProVideoEditorLogForwarder.stop();
  });

  group('ProVideoEditorLogForwarder.forwardEntry', () {
    test('forwards an error with stack trace under the video category', () {
      const message = 'pve-fwd-error-unique';
      ProVideoEditorLogForwarder.forwardEntry(
        entry(
          NativeLogLevel.error,
          message,
          tag: 'ProVideoEditor-Renderer',
          stackTrace: 'at foo\nat bar',
        ),
      );

      final logged = latestWithMessage(message);
      expect(logged, isNotNull);
      expect(logged!.level, LogLevel.error);
      expect(logged.name, 'ProVideoEditor-Renderer');
      expect(logged.category, LogCategory.video);
      expect(logged.stackTrace, isNotNull);
    });

    test('maps the warning level', () {
      const message = 'pve-fwd-warning-unique';
      ProVideoEditorLogForwarder.forwardEntry(
        entry(NativeLogLevel.warning, message),
      );
      expect(latestWithMessage(message)?.level, LogLevel.warning);
    });

    test('maps the info level', () {
      const message = 'pve-fwd-info-unique';
      ProVideoEditorLogForwarder.forwardEntry(
        entry(NativeLogLevel.info, message),
      );
      expect(latestWithMessage(message)?.level, LogLevel.info);
    });

    test('maps the debug level', () {
      const message = 'pve-fwd-debug-unique';
      ProVideoEditorLogForwarder.forwardEntry(
        entry(NativeLogLevel.debug, message),
      );
      expect(latestWithMessage(message)?.level, LogLevel.debug);
    });

    test('maps the verbose level', () {
      const message = 'pve-fwd-verbose-unique';
      ProVideoEditorLogForwarder.forwardEntry(
        entry(NativeLogLevel.verbose, message),
      );
      expect(latestWithMessage(message)?.level, LogLevel.verbose);
    });

    test('maps the none level to info', () {
      const message = 'pve-fwd-none-unique';
      ProVideoEditorLogForwarder.forwardEntry(
        entry(NativeLogLevel.none, message),
      );
      expect(latestWithMessage(message)?.level, LogLevel.info);
    });

    test('falls back to a default name when tag is missing', () {
      const message = 'pve-fwd-default-name-unique';
      ProVideoEditorLogForwarder.forwardEntry(
        entry(NativeLogLevel.info, message),
      );
      expect(latestWithMessage(message)?.name, 'ProVideoEditorNative');
    });

    test('ignores an entry with an empty message', () {
      final before = LogCaptureService().bufferSize;
      ProVideoEditorLogForwarder.forwardEntry(entry(NativeLogLevel.error, ''));
      expect(LogCaptureService().bufferSize, before);
    });
  });

  group('ProVideoEditorLogForwarder start/stop', () {
    test('forwards stream entries while subscribed, stops on cancel', () async {
      final mock = _MockProVideoEditor();
      final controller = StreamController<NativeLogEntry>.broadcast();
      when(() => mock.logStream).thenAnswer((_) => controller.stream);

      ProVideoEditorLogForwarder.start(proVideoEditor: mock);

      const live = 'pve-stream-live-unique';
      controller.add(entry(NativeLogLevel.warning, live));
      await Future<void>.delayed(Duration.zero);
      expect(latestWithMessage(live), isNotNull);

      await ProVideoEditorLogForwarder.stop();

      const afterStop = 'pve-stream-afterstop-unique';
      controller.add(entry(NativeLogLevel.warning, afterStop));
      await Future<void>.delayed(Duration.zero);
      expect(latestWithMessage(afterStop), isNull);

      await controller.close();
    });

    test(
      'start is idempotent — a second call does not double-subscribe',
      () async {
        final mock = _MockProVideoEditor();
        final controller = StreamController<NativeLogEntry>.broadcast();
        var listenCount = 0;
        when(() => mock.logStream).thenAnswer((_) {
          listenCount++;
          return controller.stream;
        });

        ProVideoEditorLogForwarder.start(proVideoEditor: mock);
        ProVideoEditorLogForwarder.start(proVideoEditor: mock);

        expect(listenCount, 1);
        await ProVideoEditorLogForwarder.stop();
        await controller.close();
      },
    );
  });
}
