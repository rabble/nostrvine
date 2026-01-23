import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:media_cache/media_cache.dart';

import 'helpers/test_helpers.dart';

void main() {
  setUpTestEnvironment();

  group('SafeCacheInfoRepository', () {
    late List<String> logMessages;

    setUpAll(() async {
      await setUpTestDirectories();
    });

    tearDownAll(() async {
      await tearDownTestDirectories();
    });

    setUp(() {
      logMessages = [];
    });

    test('can be instantiated', () {
      final repo = SafeCacheInfoRepository(databaseName: 'test_db');
      expect(repo, isNotNull);
    });

    test('accepts logging callbacks', () {
      var warningCalled = false;
      var infoCalled = false;
      var errorCalled = false;

      final repo = SafeCacheInfoRepository(
        databaseName: 'test_db',
        onWarning: (_) => warningCalled = true,
        onInfo: (_) => infoCalled = true,
        onError: (_) => errorCalled = true,
      );

      repo.onWarning?.call('warning');
      repo.onInfo?.call('info');
      repo.onError?.call('error');

      expect(warningCalled, true);
      expect(infoCalled, true);
      expect(errorCalled, true);
    });

    test('callbacks are optional', () {
      final repo = SafeCacheInfoRepository(databaseName: 'test_db');

      // Should not throw when callbacks are null
      expect(() => repo.onWarning?.call('warning'), returnsNormally);
      expect(() => repo.onInfo?.call('info'), returnsNormally);
      expect(() => repo.onError?.call('error'), returnsNormally);
    });

    group('open', () {
      test('opens successfully with empty cache', () async {
        final dbName = 'test_db_${DateTime.now().millisecondsSinceEpoch}';
        final repo = SafeCacheInfoRepository(
          databaseName: dbName,
          onInfo: logMessages.add,
          onWarning: logMessages.add,
          onError: logMessages.add,
        );

        final result = await repo.open();
        expect(result, true);
      });

      test('handles corrupted JSON file gracefully', () async {
        final dbName = 'corrupted_db_${DateTime.now().millisecondsSinceEpoch}';

        // Create a corrupted JSON file
        final corruptedFile = File('$testSupportPath/$dbName.json');
        await corruptedFile.writeAsString('{ this is not valid JSON }');

        final repo = SafeCacheInfoRepository(
          databaseName: dbName,
          onWarning: logMessages.add,
          onInfo: logMessages.add,
          onError: logMessages.add,
        );

        // Should not throw - parent class handles corruption gracefully
        // by catching FormatException internally and starting fresh
        final result = await repo.open();
        expect(result, true);
      });

      test('handles empty JSON file gracefully', () async {
        final dbName = 'empty_db_${DateTime.now().millisecondsSinceEpoch}';

        // Create an empty JSON file
        final emptyFile = File('$testSupportPath/$dbName.json');
        await emptyFile.writeAsString('');

        final repo = SafeCacheInfoRepository(
          databaseName: dbName,
          onWarning: logMessages.add,
          onInfo: logMessages.add,
          onError: logMessages.add,
        );

        // Should not throw - should recover from empty file
        final result = await repo.open();
        expect(result, true);
      });

      test('handles null content in JSON file', () async {
        final dbName = 'null_db_${DateTime.now().millisecondsSinceEpoch}';

        // Create a JSON file with null content
        final nullFile = File('$testSupportPath/$dbName.json');
        await nullFile.writeAsString('null');

        final repo = SafeCacheInfoRepository(
          databaseName: dbName,
          onWarning: logMessages.add,
          onInfo: logMessages.add,
          onError: logMessages.add,
        );

        // Should not throw - should recover
        final result = await repo.open();
        expect(result, true);
      });

      test('handles valid JSON file', () async {
        final dbName = 'valid_db_${DateTime.now().millisecondsSinceEpoch}';

        // Create a valid JSON cache file
        final validFile = File('$testSupportPath/$dbName.json');
        await validFile.writeAsString('{}');

        final repo = SafeCacheInfoRepository(
          databaseName: dbName,
          onWarning: logMessages.add,
          onInfo: logMessages.add,
          onError: logMessages.add,
        );

        final result = await repo.open();
        expect(result, true);
      });

      test('can be opened multiple times', () async {
        final dbName = 'multi_open_${DateTime.now().millisecondsSinceEpoch}';
        final repo = SafeCacheInfoRepository(
          databaseName: dbName,
          onInfo: logMessages.add,
        );

        final result1 = await repo.open();
        final result2 = await repo.open();

        expect(result1, true);
        expect(result2, true);
      });
    });

    group('logging callbacks', () {
      test('callbacks can be invoked manually', () {
        var warningCalled = false;
        var infoCalled = false;
        var errorCalled = false;

        final repo = SafeCacheInfoRepository(
          databaseName: 'callback_test',
          onWarning: (_) => warningCalled = true,
          onInfo: (_) => infoCalled = true,
          onError: (_) => errorCalled = true,
        );

        // Manually invoke callbacks to test they work
        repo.onWarning?.call('test warning');
        repo.onInfo?.call('test info');
        repo.onError?.call('test error');

        expect(warningCalled, true);
        expect(infoCalled, true);
        expect(errorCalled, true);
      });

      test('callbacks receive correct messages', () {
        String? warningMsg;
        String? infoMsg;
        String? errorMsg;

        final repo = SafeCacheInfoRepository(
          databaseName: 'msg_test',
          onWarning: (msg) => warningMsg = msg,
          onInfo: (msg) => infoMsg = msg,
          onError: (msg) => errorMsg = msg,
        );

        repo.onWarning?.call('warning message');
        repo.onInfo?.call('info message');
        repo.onError?.call('error message');

        expect(warningMsg, 'warning message');
        expect(infoMsg, 'info message');
        expect(errorMsg, 'error message');
      });

      test('null callbacks do not throw when invoked', () {
        final repo = SafeCacheInfoRepository(databaseName: 'null_cb_test');

        // Should not throw
        expect(() => repo.onWarning?.call('test'), returnsNormally);
        expect(() => repo.onInfo?.call('test'), returnsNormally);
        expect(() => repo.onError?.call('test'), returnsNormally);
      });
    });
  });
}
