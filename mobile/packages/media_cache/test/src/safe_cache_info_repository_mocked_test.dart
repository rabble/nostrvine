import 'package:flutter_test/flutter_test.dart';

import 'helpers/mocks.dart';
import 'helpers/test_helpers.dart';

void main() {
  setUpTestEnvironment();

  group('SafeCacheInfoRepository exception handling', () {
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

    group('FormatException handling', () {
      test('logs warning and recovers from FormatException', () async {
        final repo = TestableSafeCacheInfoRepository(
          databaseName: 'format_exception_test',
          shouldThrowFormatException: true,
          onWarning: logMessages.add,
          onInfo: logMessages.add,
        );

        final result = await repo.open();

        expect(result, true);
        expect(
          logMessages.any((m) => m.contains('corrupted')),
          true,
        );
        expect(
          logMessages.any((m) => m.contains('Deleted corrupted cache file')),
          true,
        );
      });

      test('onWarning receives correct message format', () async {
        String? warningMessage;
        final repo = TestableSafeCacheInfoRepository(
          databaseName: 'warning_format_test',
          shouldThrowFormatException: true,
          onWarning: (msg) => warningMessage = msg,
          onInfo: (_) {},
        );

        await repo.open();

        expect(warningMessage, isNotNull);
        expect(warningMessage, contains('Cache JSON corrupted'));
        expect(warningMessage, contains('clearing cache'));
      });
    });

    group('Generic Exception handling', () {
      test('handles Unexpected end of input exception', () async {
        final repo = TestableSafeCacheInfoRepository(
          databaseName: 'generic_exception_test',
          shouldThrowGenericException: true,
          genericExceptionMessage: 'Unexpected end of input',
          onWarning: logMessages.add,
          onInfo: logMessages.add,
        );

        final result = await repo.open();

        expect(result, true);
        expect(
          logMessages.any((m) => m.contains('empty/null')),
          true,
        );
      });

      test('handles type Null exception', () async {
        final repo = TestableSafeCacheInfoRepository(
          databaseName: 'null_type_test',
          shouldThrowGenericException: true,
          genericExceptionMessage: "type 'Null' is not a subtype",
          onWarning: logMessages.add,
          onInfo: logMessages.add,
        );

        final result = await repo.open();

        expect(result, true);
        expect(
          logMessages.any((m) => m.contains('empty/null')),
          true,
        );
      });
    });

    group('callback invocation', () {
      test('onInfo is called when deleting corrupted file', () async {
        String? infoMessage;
        final repo = TestableSafeCacheInfoRepository(
          databaseName: 'info_callback_test',
          shouldThrowFormatException: true,
          onWarning: (_) {},
          onInfo: (msg) => infoMessage = msg,
        );

        await repo.open();

        expect(infoMessage, isNotNull);
        expect(infoMessage, contains('Deleted corrupted cache file'));
      });

      test('works with null callbacks', () async {
        final repo = TestableSafeCacheInfoRepository(
          databaseName: 'null_callbacks_test',
          shouldThrowFormatException: true,
        );

        // Should not throw even with null callbacks
        final result = await repo.open();
        expect(result, true);
      });
    });

    group('recovery behavior', () {
      test('only throws once then succeeds', () async {
        var warningCount = 0;
        final repo = TestableSafeCacheInfoRepository(
          databaseName: 'recovery_test',
          shouldThrowFormatException: true,
          onWarning: (_) => warningCount++,
          onInfo: (_) {},
        );

        // First open triggers exception and recovery
        await repo.open();
        expect(warningCount, 1);

        // Second open should succeed without warning
        final result = await repo.open();
        expect(result, true);
        expect(warningCount, 1); // No additional warnings
      });
    });
  });
}
