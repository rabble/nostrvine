// ABOUTME: Unit tests for UsernameRepository
// ABOUTME: Tests availability checking delegation to Nip05Service

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/repositories/username_repository.dart';
import 'package:openvine/services/nip05_service.dart';

class MockNip05Service extends Mock implements Nip05Service {}

void main() {
  late MockNip05Service mockNip05Service;
  late UsernameRepository repository;

  setUp(() {
    mockNip05Service = MockNip05Service();
    repository = UsernameRepository(mockNip05Service);
  });

  group('UsernameRepository', () {
    group('checkAvailability', () {
      test('returns available when service returns true', () async {
        // Arrange
        when(
          () => mockNip05Service.checkUsernameAvailability('testuser'),
        ).thenAnswer((_) async => true);

        // Act
        final result = await repository.checkAvailability('testuser');

        // Assert
        expect(result, UsernameAvailability.available);
        verify(
          () => mockNip05Service.checkUsernameAvailability('testuser'),
        ).called(1);
      });

      test('returns taken when service returns false', () async {
        // Arrange
        when(
          () => mockNip05Service.checkUsernameAvailability('takenuser'),
        ).thenAnswer((_) async => false);

        // Act
        final result = await repository.checkAvailability('takenuser');

        // Assert
        expect(result, UsernameAvailability.taken);
        verify(
          () => mockNip05Service.checkUsernameAvailability('takenuser'),
        ).called(1);
      });

      test('returns error when service throws exception', () async {
        // Arrange
        when(
          () => mockNip05Service.checkUsernameAvailability('erroruser'),
        ).thenThrow(Exception('Network error'));

        // Act
        final result = await repository.checkAvailability('erroruser');

        // Assert
        expect(result, UsernameAvailability.error);
        verify(
          () => mockNip05Service.checkUsernameAvailability('erroruser'),
        ).called(1);
      });
    });
  });
}
