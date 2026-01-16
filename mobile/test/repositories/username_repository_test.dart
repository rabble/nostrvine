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

    group('register', () {
      const validPubkey =
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

      test('returns UsernameClaimSuccess on successful registration', () async {
        // Arrange
        when(
          () => mockNip05Service.registerUsername('newuser', validPubkey),
        ).thenAnswer((_) async {});

        // Act
        final result = await repository.register(
          username: 'newuser',
          pubkey: validPubkey,
        );

        // Assert
        expect(result, isA<UsernameClaimSuccess>());
        verify(
          () => mockNip05Service.registerUsername('newuser', validPubkey),
        ).called(1);
      });

      test(
        'returns UsernameClaimTaken when service throws UsernameTakenException',
        () async {
          // Arrange
          when(
            () => mockNip05Service.registerUsername('takenuser', validPubkey),
          ).thenThrow(const UsernameTakenException());

          // Act
          final result = await repository.register(
            username: 'takenuser',
            pubkey: validPubkey,
          );

          // Assert
          expect(result, isA<UsernameClaimTaken>());
        },
      );

      test(
        'returns UsernameClaimReserved when service throws UsernameReservedException',
        () async {
          // Arrange
          when(
            () => mockNip05Service.registerUsername('reserved', validPubkey),
          ).thenThrow(const UsernameReservedException());

          // Act
          final result = await repository.register(
            username: 'reserved',
            pubkey: validPubkey,
          );

          // Assert
          expect(result, isA<UsernameClaimReserved>());
        },
      );

      test(
        'returns UsernameClaimError when service throws Nip05ServiceException',
        () async {
          // Arrange
          when(
            () => mockNip05Service.registerUsername('erroruser', validPubkey),
          ).thenThrow(const Nip05ServiceException('Network error'));

          // Act
          final result = await repository.register(
            username: 'erroruser',
            pubkey: validPubkey,
          );

          // Assert
          expect(result, isA<UsernameClaimError>());
          expect((result as UsernameClaimError).message, 'Network error');
        },
      );
    });
  });
}
