import 'package:flutter_test/flutter_test.dart';

import 'helpers/mocks.dart';
import 'helpers/test_helpers.dart';

void main() {
  setUpTestEnvironment();

  group('SafeCacheInfoRepository exception handling', () {
    setUpAll(() async {
      await setUpTestDirectories();
    });

    tearDownAll(() async {
      await tearDownTestDirectories();
    });

    group('FormatException handling', () {
      test('recovers from FormatException', () async {
        final repo = TestableSafeCacheInfoRepository(
          databaseName: 'format_exception_test',
          shouldThrowFormatException: true,
        );

        final result = await repo.open();

        expect(result, true);
      });
    });

    group('Generic Exception handling', () {
      test('handles Unexpected end of input exception', () async {
        final repo = TestableSafeCacheInfoRepository(
          databaseName: 'generic_exception_test',
          shouldThrowGenericException: true,
          genericExceptionMessage: 'Unexpected end of input',
        );

        final result = await repo.open();

        expect(result, true);
      });

      test('handles type Null exception', () async {
        final repo = TestableSafeCacheInfoRepository(
          databaseName: 'null_type_test',
          shouldThrowGenericException: true,
          genericExceptionMessage: "type 'Null' is not a subtype",
        );

        final result = await repo.open();

        expect(result, true);
      });
    });

    group('recovery behavior', () {
      test('only throws once then succeeds', () async {
        final repo = TestableSafeCacheInfoRepository(
          databaseName: 'recovery_test',
          shouldThrowFormatException: true,
        );

        // First open triggers exception and recovery
        final result1 = await repo.open();
        expect(result1, true);

        // Second open should succeed
        final result2 = await repo.open();
        expect(result2, true);
      });
    });
  });
}
