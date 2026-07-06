// ABOUTME: Tests for LogCaptureService on-disk session persistence:
// ABOUTME: cross-session export, flush behavior, pruning, and rotation.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:unified_logger/unified_logger.dart';

void main() {
  group('LogCaptureService persistence', () {
    late LogCaptureService service;
    late Directory tempDir;

    setUp(() {
      LogCaptureService.resetForTesting();
      service = LogCaptureService();
      tempDir = Directory.systemTemp.createTempSync('log_persistence_test');
    });

    tearDown(() async {
      await service.disablePersistence();
      // Also release any instance created mid-test (simulated restarts).
      await LogCaptureService().disablePersistence();
      LogCaptureService.resetForTesting();
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    LogEntry entry(String message, {LogLevel level = LogLevel.info}) =>
        LogEntry(timestamp: DateTime.now(), level: level, message: message);

    List<File> sessionFiles() =>
        tempDir.listSync().whereType<File>().toList()
          ..sort((a, b) => a.path.compareTo(b.path));

    test('export spans previous sessions after a simulated restart', () async {
      await service.enablePersistence(directoryPath: tempDir.path);
      service.captureLog(entry('from-first-session'));
      await service.flush();

      // Simulated app restart: new singleton, same log directory.
      LogCaptureService.resetForTesting();
      final secondSession = LogCaptureService();
      await secondSession.enablePersistence(directoryPath: tempDir.path);
      secondSession.captureLog(entry('from-second-session'));

      final lines = await secondSession.getAllLogsAsText();
      final first = lines.indexWhere((l) => l.contains('from-first-session'));
      final second = lines.indexWhere((l) => l.contains('from-second-session'));
      expect(first, isNonNegative);
      expect(second, isNonNegative);
      expect(first, lessThan(second));
      expect(
        lines.where((l) => l.contains('app session started')),
        hasLength(2),
      );

      final stats = await secondSession.getLogStatistics();
      expect(stats['fileCount'], equals(2));
    });

    test('warning entries reach disk without an explicit flush', () async {
      await service.enablePersistence(directoryPath: tempDir.path);
      service.captureLog(entry('important-warning', level: LogLevel.warning));

      // Wait only for the internal write chain — no manual flush() call.
      await service.disablePersistence();

      final contents = sessionFiles().map((f) => f.readAsStringSync()).join();
      expect(contents, contains('important-warning'));
    });

    test('info entries below the threshold stay pending until flush', () async {
      await service.enablePersistence(
        directoryPath: tempDir.path,
        flushThreshold: 100,
      );
      final baseline = sessionFiles().map((f) => f.readAsStringSync()).join();

      service.captureLog(entry('buffered-info'));
      expect(
        sessionFiles().map((f) => f.readAsStringSync()).join(),
        equals(baseline),
      );

      await service.flush();
      expect(
        sessionFiles().map((f) => f.readAsStringSync()).join(),
        contains('buffered-info'),
      );
    });

    test('enablePersistence prunes files older than maxFileAge', () async {
      final oldMillis = DateTime.now()
          .subtract(const Duration(hours: 2))
          .millisecondsSinceEpoch;
      final oldFile = File('${tempDir.path}/divine_logs_${oldMillis}_000.log')
        ..writeAsStringSync('stale line\n');

      await service.enablePersistence(
        directoryPath: tempDir.path,
        maxFileAge: const Duration(hours: 1),
      );

      expect(oldFile.existsSync(), isFalse);
    });

    test(
      'enablePersistence prunes oldest files beyond maxTotalBytes',
      () async {
        final now = DateTime.now().millisecondsSinceEpoch;
        final older = File('${tempDir.path}/divine_logs_${now - 2000}_000.log')
          ..writeAsStringSync('x' * 80);
        final newer = File('${tempDir.path}/divine_logs_${now - 1000}_000.log')
          ..writeAsStringSync('y' * 80);

        await service.enablePersistence(
          directoryPath: tempDir.path,
          maxTotalBytes: 100,
        );

        expect(older.existsSync(), isFalse);
        expect(newer.existsSync(), isTrue);
      },
    );

    test(
      'rotates to a new part file when maxBytesPerFile is exceeded',
      () async {
        await service.enablePersistence(
          directoryPath: tempDir.path,
          maxBytesPerFile: 50,
        );
        service.captureLog(entry('first-part-message'));
        await service.flush();
        service.captureLog(entry('second-part-message'));
        await service.flush();

        expect(sessionFiles().length, greaterThanOrEqualTo(2));

        final lines = await service.getAllLogsAsText();
        final first = lines.indexWhere((l) => l.contains('first-part-message'));
        final second = lines.indexWhere(
          (l) => l.contains('second-part-message'),
        );
        expect(first, isNonNegative);
        expect(second, isNonNegative);
        expect(first, lessThan(second));
        // Rotated parts belong to one session — exactly one marker.
        expect(
          lines.where((l) => l.contains('app session started')),
          hasLength(1),
        );
      },
    );

    test(
      'without persistence, export uses memory and reports zero files',
      () async {
        service.captureLog(entry('memory-only'));

        final lines = await service.getAllLogsAsText();
        expect(lines.single, contains('memory-only'));

        final stats = await service.getLogStatistics();
        expect(stats['fileCount'], equals(0));
        expect(sessionFiles(), isEmpty);
      },
    );

    test('clearAllLogs deletes persisted session files', () async {
      await service.enablePersistence(directoryPath: tempDir.path);
      service.captureLog(entry('to-be-cleared'));
      await service.flush();
      expect(sessionFiles(), isNotEmpty);

      await service.clearAllLogs();

      expect(sessionFiles(), isEmpty);
      expect(await service.getAllLogsAsText(), isEmpty);
    });

    test(
      'disablePersistence flushes pending lines and stops writing',
      () async {
        await service.enablePersistence(
          directoryPath: tempDir.path,
          flushThreshold: 100,
        );
        service.captureLog(entry('flushed-on-disable'));
        await service.disablePersistence();

        final contents = sessionFiles().map((f) => f.readAsStringSync()).join();
        expect(contents, contains('flushed-on-disable'));

        service.captureLog(entry('after-disable'));
        await service.flush();
        final after = sessionFiles().map((f) => f.readAsStringSync()).join();
        expect(after, isNot(contains('after-disable')));
      },
    );
  });
}
