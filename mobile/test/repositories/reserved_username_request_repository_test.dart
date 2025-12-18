// ABOUTME: Unit tests for ReservedUsernameRequestRepository
// ABOUTME: Tests result constructors and submitRequest method with timing verification

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:openvine/repositories/reserved_username_request_repository.dart';

class MockHttpClient extends Mock implements http.Client {}

void main() {
  late MockHttpClient mockHttpClient;
  late ReservedUsernameRequestRepository repository;

  setUp(() {
    mockHttpClient = MockHttpClient();
    repository = ReservedUsernameRequestRepository(mockHttpClient);
  });

  group('ReservedUsernameRequestRepository', () {
    group('ReservedUsernameRequestResult', () {
      group('success constructor', () {
        test('creates result with success=true and null error', () {
          // Act
          const result = ReservedUsernameRequestResult.success();

          // Assert
          expect(result.success, true);
          expect(result.error, null);
        });
      });

      group('failure constructor', () {
        test('creates result with success=false and error message', () {
          // Arrange
          const errorMessage = 'Network error occurred';

          // Act
          const result = ReservedUsernameRequestResult.failure(errorMessage);

          // Assert
          expect(result.success, false);
          expect(result.error, errorMessage);
        });

        test('creates result with different error messages', () {
          // Act
          const result1 = ReservedUsernameRequestResult.failure('Error 1');
          const result2 = ReservedUsernameRequestResult.failure('Error 2');

          // Assert
          expect(result1.error, 'Error 1');
          expect(result2.error, 'Error 2');
        });
      });
    });

    group('submitRequest', () {
      const testUsername = 'testuser';
      const testEmail = 'test@example.com';
      const testJustification = 'I am a verified public figure';

      test('returns success result', () async {
        // Act
        final result = await repository.submitRequest(
          username: testUsername,
          email: testEmail,
          justification: testJustification,
        );

        // Assert
        expect(result.success, true);
        expect(result.error, null);
      });

      test('takes approximately 1 second to complete', () async {
        // Arrange
        final stopwatch = Stopwatch()..start();

        // Act
        await repository.submitRequest(
          username: testUsername,
          email: testEmail,
          justification: testJustification,
        );

        // Assert
        stopwatch.stop();
        final elapsedMs = stopwatch.elapsedMilliseconds;

        // Allow 100ms tolerance for timing (should be ~1000ms)
        expect(elapsedMs, greaterThanOrEqualTo(900));
        expect(elapsedMs, lessThan(1100));
      });

      test('accepts various username values', () async {
        // Act
        final result1 = await repository.submitRequest(
          username: 'shortname',
          email: testEmail,
          justification: testJustification,
        );
        final result2 = await repository.submitRequest(
          username: 'verylongusernamewithmanycharacters',
          email: testEmail,
          justification: testJustification,
        );

        // Assert
        expect(result1.success, true);
        expect(result2.success, true);
      });

      test('accepts various email values', () async {
        // Act
        final result1 = await repository.submitRequest(
          username: testUsername,
          email: 'user@domain.com',
          justification: testJustification,
        );
        final result2 = await repository.submitRequest(
          username: testUsername,
          email: 'another.user@example.org',
          justification: testJustification,
        );

        // Assert
        expect(result1.success, true);
        expect(result2.success, true);
      });

      test('accepts various justification values', () async {
        // Act
        final result1 = await repository.submitRequest(
          username: testUsername,
          email: testEmail,
          justification: 'Short reason',
        );
        final result2 = await repository.submitRequest(
          username: testUsername,
          email: testEmail,
          justification: 'A much longer and more detailed justification '
              'explaining why this username should be reserved for this user '
              'with extensive background information.',
        );

        // Assert
        expect(result1.success, true);
        expect(result2.success, true);
      });
    });
  });
}
