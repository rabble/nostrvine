// ABOUTME: Unit tests for UsernameRepository
// ABOUTME: Tests availability checking and registration delegation to Nip05Service

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
    group('checkUsernameAvailability', () {
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

    group('registerUsername', () {
      const validPubkey =
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
      final relays = ['wss://relay1.com', 'wss://relay2.com'];

      test('delegates to Nip05Service and returns success result', () async {
        // Arrange
        when(
          () =>
              mockNip05Service.registerUsername('newuser', validPubkey, relays),
        ).thenAnswer(
          (_) async => const UsernameRegistrationResult(
            status: UsernameRegistrationStatus.success,
          ),
        );

        // Act
        final result = await repository.register(
          username: 'newuser',
          pubkey: validPubkey,
          relays: relays,
        );

        // Assert
        expect(result.isSuccess, true);
        verify(
          () =>
              mockNip05Service.registerUsername('newuser', validPubkey, relays),
        ).called(1);
      });

      test('returns taken result from service', () async {
        // Arrange
        when(
          () => mockNip05Service.registerUsername(
            'takenuser',
            validPubkey,
            relays,
          ),
        ).thenAnswer(
          (_) async => const UsernameRegistrationResult(
            status: UsernameRegistrationStatus.taken,
            errorMessage: 'Username already taken',
          ),
        );

        // Act
        final result = await repository.register(
          username: 'takenuser',
          pubkey: validPubkey,
          relays: relays,
        );

        // Assert
        expect(result.isTaken, true);
        expect(result.errorMessage, 'Username already taken');
      });

      test('returns reserved result from service', () async {
        // Arrange
        when(
          () => mockNip05Service.registerUsername(
            'reserved',
            validPubkey,
            relays,
          ),
        ).thenAnswer(
          (_) async => const UsernameRegistrationResult(
            status: UsernameRegistrationStatus.reserved,
            errorMessage: 'Username is reserved',
          ),
        );

        // Act
        final result = await repository.register(
          username: 'reserved',
          pubkey: validPubkey,
          relays: relays,
        );

        // Assert
        expect(result.isReserved, true);
        expect(result.errorMessage, 'Username is reserved');
      });
    });
  });
}
