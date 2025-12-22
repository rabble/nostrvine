// ABOUTME: Unit tests for ReservedUsernameRequestNotifier
// ABOUTME: Tests form field updates, validation, and submission flow

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/reserved_username_request_notifier.dart';
import 'package:openvine/repositories/reserved_username_request_repository.dart';
import 'package:openvine/state/reserved_username_request_state.dart';

class MockReservedUsernameRequestRepository extends Mock
    implements ReservedUsernameRequestRepository {}

void main() {
  late MockReservedUsernameRequestRepository mockRepository;

  setUp(() {
    mockRepository = MockReservedUsernameRequestRepository();
  });

  /// Helper to create a container with mocked repository
  ProviderContainer createContainer() {
    final container = ProviderContainer(
      overrides: [
        reservedUsernameRequestRepositoryProvider.overrideWithValue(
          mockRepository,
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('ReservedUsernameRequestNotifier', () {
    group('isEmailValid', () {
      test('is true when email is empty', () {
        final container = createContainer();

        expect(
          container.read(reservedUsernameRequestProvider.notifier).isEmailValid,
          isTrue,
        );
      });

      test('is true when email is valid', () {
        final container = createContainer();
        final notifier = container.read(
          reservedUsernameRequestProvider.notifier,
        );

        notifier.setEmail('test@example.com');

        expect(notifier.isEmailValid, isTrue);
      });

      test('is false when email is not valid', () {
        final container = createContainer();
        final notifier = container.read(
          reservedUsernameRequestProvider.notifier,
        );

        notifier.setEmail('test@example.%com');

        expect(notifier.isEmailValid, isFalse);
      });
    });

    group('build', () {
      test('returns initial state with empty fields and idle status', () {
        final container = createContainer();

        final state = container.read(reservedUsernameRequestProvider);

        expect(state.email, '');
        expect(state.justification, '');
        expect(state.status, ReservedUsernameRequestStatus.idle);
        expect(state.errorMessage, isNull);
      });
    });

    group('setEmail', () {
      test('updates email in state', () {
        final container = createContainer();

        container
            .read(reservedUsernameRequestProvider.notifier)
            .setEmail('user@example.com');

        final state = container.read(reservedUsernameRequestProvider);
        expect(state.email, 'user@example.com');
      });

      test('trims whitespace from email', () {
        final container = createContainer();

        container
            .read(reservedUsernameRequestProvider.notifier)
            .setEmail('  user@example.com  ');

        final state = container.read(reservedUsernameRequestProvider);
        expect(state.email, 'user@example.com');
      });

      test('does not convert email to lowercase', () {
        final container = createContainer();

        container
            .read(reservedUsernameRequestProvider.notifier)
            .setEmail('User@Example.COM');

        final state = container.read(reservedUsernameRequestProvider);
        // Email should preserve case as per RFC 5321 (local-part is case-sensitive)
        expect(state.email, 'User@Example.COM');
      });

      test('preserves other fields when updating email', () {
        final container = createContainer();
        final notifier = container.read(
          reservedUsernameRequestProvider.notifier,
        );

        // Set other fields first
        notifier.setJustification('I am the owner');

        // Update email
        notifier.setEmail('new@example.com');

        final state = container.read(reservedUsernameRequestProvider);
        expect(state.email, 'new@example.com');
        expect(state.justification, 'I am the owner');
      });
    });

    group('setJustification', () {
      test('updates justification in state', () {
        final container = createContainer();

        container
            .read(reservedUsernameRequestProvider.notifier)
            .setJustification('I own the brand');

        final state = container.read(reservedUsernameRequestProvider);
        expect(state.justification, 'I own the brand');
      });

      test('trims whitespace from justification', () {
        final container = createContainer();

        container
            .read(reservedUsernameRequestProvider.notifier)
            .setJustification('  I own the brand  ');

        final state = container.read(reservedUsernameRequestProvider);
        expect(state.justification, 'I own the brand');
      });

      test('preserves case and special characters', () {
        final container = createContainer();

        container
            .read(reservedUsernameRequestProvider.notifier)
            .setJustification('I am the CEO of Example Inc. - www.example.com');

        final state = container.read(reservedUsernameRequestProvider);
        expect(
          state.justification,
          'I am the CEO of Example Inc. - www.example.com',
        );
      });

      test('preserves other fields when updating justification', () {
        final container = createContainer();
        final notifier = container.read(
          reservedUsernameRequestProvider.notifier,
        );

        // Set other fields first
        notifier.setEmail('test@example.com');

        // Update justification
        notifier.setJustification('New justification');

        final state = container.read(reservedUsernameRequestProvider);
        expect(state.email, 'test@example.com');
        expect(state.justification, 'New justification');
      });
    });

    group('submitRequest', () {
      test('returns false when canSubmit is false (missing email)', () async {
        final container = createContainer();
        final notifier = container.read(
          reservedUsernameRequestProvider.notifier,
        );

        // Set only username and justification
        notifier.setJustification('I am the owner');

        final result = await notifier.submitRequest(username: 'username');

        expect(result, false);
        verifyNever(
          () => mockRepository.submitRequest(
            username: any(named: 'username'),
            email: any(named: 'email'),
            justification: any(named: 'justification'),
          ),
        );
      });

      test('returns false when canSubmit is false (invalid email)', () async {
        final container = createContainer();
        final notifier = container.read(
          reservedUsernameRequestProvider.notifier,
        );

        // Set invalid email
        notifier.setEmail('invalid-email');
        notifier.setJustification('I am the owner');

        final result = await notifier.submitRequest(username: 'username');

        expect(result, false);
        verifyNever(
          () => mockRepository.submitRequest(
            username: any(named: 'username'),
            email: any(named: 'email'),
            justification: any(named: 'justification'),
          ),
        );
      });

      test(
        'returns false when canSubmit is false (missing justification)',
        () async {
          final container = createContainer();
          final notifier = container.read(
            reservedUsernameRequestProvider.notifier,
          );

          // Set only username and email
          notifier.setEmail('test@example.com');

          final result = await notifier.submitRequest(username: 'username');

          expect(result, false);
          verifyNever(
            () => mockRepository.submitRequest(
              username: any(named: 'username'),
              email: any(named: 'email'),
              justification: any(named: 'justification'),
            ),
          );
        },
      );

      test('sets status to submitting during request', () async {
        final container = createContainer();
        final notifier = container.read(
          reservedUsernameRequestProvider.notifier,
        );

        // Arrange
        when(
          () => mockRepository.submitRequest(
            username: 'username',
            email: 'test@example.com',
            justification: 'I am the owner',
          ),
        ).thenAnswer((_) async {
          // Check state during repository call
          final stateWhileSubmitting = container.read(
            reservedUsernameRequestProvider,
          );
          expect(
            stateWhileSubmitting.status,
            ReservedUsernameRequestStatus.submitting,
          );
          return const ReservedUsernameRequestResult.success();
        });

        notifier.setEmail('test@example.com');
        notifier.setJustification('I am the owner');

        // Act
        await notifier.submitRequest(username: 'username');

        // Assert - verify submitting state was set
        verify(
          () => mockRepository.submitRequest(
            username: 'username',
            email: 'test@example.com',
            justification: 'I am the owner',
          ),
        ).called(1);
      });

      test('calls repository with correct parameters', () async {
        final container = createContainer();
        final notifier = container.read(
          reservedUsernameRequestProvider.notifier,
        );

        // Arrange
        when(
          () => mockRepository.submitRequest(
            username: 'username',
            email: 'test@example.com',
            justification: 'I am the brand owner',
          ),
        ).thenAnswer(
          (_) async => const ReservedUsernameRequestResult.success(),
        );

        notifier.setEmail('test@example.com');
        notifier.setJustification('I am the brand owner');

        // Act
        await notifier.submitRequest(username: 'username');

        // Assert
        verify(
          () => mockRepository.submitRequest(
            username: 'username',
            email: 'test@example.com',
            justification: 'I am the brand owner',
          ),
        ).called(1);
      });

      test('sets status to success on successful response', () async {
        final container = createContainer();
        final notifier = container.read(
          reservedUsernameRequestProvider.notifier,
        );

        // Arrange
        when(
          () => mockRepository.submitRequest(
            username: any(named: 'username'),
            email: any(named: 'email'),
            justification: any(named: 'justification'),
          ),
        ).thenAnswer(
          (_) async => const ReservedUsernameRequestResult.success(),
        );

        notifier.setEmail('test@example.com');
        notifier.setJustification('I am the owner');

        // Act
        final result = await notifier.submitRequest(username: 'username');

        // Assert
        expect(result, true);
        final state = container.read(reservedUsernameRequestProvider);
        expect(state.status, ReservedUsernameRequestStatus.success);
        expect(state.isSuccess, true);
        expect(state.errorMessage, isNull);
      });

      test('sets status to error with message on failed response', () async {
        final container = createContainer();
        final notifier = container.read(
          reservedUsernameRequestProvider.notifier,
        );

        // Arrange
        const errorMsg = 'Server error';
        when(
          () => mockRepository.submitRequest(
            username: any(named: 'username'),
            email: any(named: 'email'),
            justification: any(named: 'justification'),
          ),
        ).thenAnswer(
          (_) async => const ReservedUsernameRequestResult.failure(errorMsg),
        );

        notifier.setEmail('test@example.com');
        notifier.setJustification('I am the owner');

        // Act
        final result = await notifier.submitRequest(username: 'username');

        // Assert
        expect(result, false);
        final state = container.read(reservedUsernameRequestProvider);
        expect(state.status, ReservedUsernameRequestStatus.error);
        expect(state.hasError, true);
        expect(state.errorMessage, errorMsg);
      });

      test('returns true on success', () async {
        final container = createContainer();
        final notifier = container.read(
          reservedUsernameRequestProvider.notifier,
        );

        // Arrange
        when(
          () => mockRepository.submitRequest(
            username: any(named: 'username'),
            email: any(named: 'email'),
            justification: any(named: 'justification'),
          ),
        ).thenAnswer(
          (_) async => const ReservedUsernameRequestResult.success(),
        );

        notifier.setEmail('test@example.com');
        notifier.setJustification('I am the owner');

        // Act
        final result = await notifier.submitRequest(username: 'username');

        // Assert
        expect(result, true);
      });

      test('returns false on error', () async {
        final container = createContainer();
        final notifier = container.read(
          reservedUsernameRequestProvider.notifier,
        );

        // Arrange
        when(
          () => mockRepository.submitRequest(
            username: any(named: 'username'),
            email: any(named: 'email'),
            justification: any(named: 'justification'),
          ),
        ).thenAnswer(
          (_) async =>
              const ReservedUsernameRequestResult.failure('Network error'),
        );

        notifier.setEmail('test@example.com');
        notifier.setJustification('I am the owner');

        // Act
        final result = await notifier.submitRequest(username: 'username');

        // Assert
        expect(result, false);
      });

      test('handles exceptions gracefully', () async {
        final container = createContainer();
        final notifier = container.read(
          reservedUsernameRequestProvider.notifier,
        );

        // Arrange
        when(
          () => mockRepository.submitRequest(
            username: any(named: 'username'),
            email: any(named: 'email'),
            justification: any(named: 'justification'),
          ),
        ).thenThrow(Exception('Network timeout'));

        notifier.setEmail('test@example.com');
        notifier.setJustification('I am the owner');

        // Act
        final result = await notifier.submitRequest(username: 'username');

        // Assert
        expect(result, false);
        final state = container.read(reservedUsernameRequestProvider);
        expect(state.status, ReservedUsernameRequestStatus.error);
        expect(state.hasError, true);
        expect(state.errorMessage, 'An unexpected error occurred');
      });

      test('clears previous error message on new submission', () async {
        final container = createContainer();
        final notifier = container.read(
          reservedUsernameRequestProvider.notifier,
        );

        // Arrange - first submission fails
        when(
          () => mockRepository.submitRequest(
            username: any(named: 'username'),
            email: any(named: 'email'),
            justification: any(named: 'justification'),
          ),
        ).thenAnswer(
          (_) async =>
              const ReservedUsernameRequestResult.failure('First error'),
        );

        notifier.setEmail('test@example.com');
        notifier.setJustification('I am the owner');

        await notifier.submitRequest(username: 'username');

        // Verify error state
        var state = container.read(reservedUsernameRequestProvider);
        expect(state.errorMessage, 'First error');

        // Arrange - second submission succeeds
        when(
          () => mockRepository.submitRequest(
            username: any(named: 'username'),
            email: any(named: 'email'),
            justification: any(named: 'justification'),
          ),
        ).thenAnswer(
          (_) async => const ReservedUsernameRequestResult.success(),
        );

        // Act - submit again
        await notifier.submitRequest(username: 'username');

        // Assert - error should be cleared
        state = container.read(reservedUsernameRequestProvider);
        expect(state.status, ReservedUsernameRequestStatus.success);
        expect(state.errorMessage, isNull);
      });

      test(
        'uses default error message when failure has no error text',
        () async {
          final container = createContainer();
          final notifier = container.read(
            reservedUsernameRequestProvider.notifier,
          );

          // Arrange
          when(
            () => mockRepository.submitRequest(
              username: any(named: 'username'),
              email: any(named: 'email'),
              justification: any(named: 'justification'),
            ),
          ).thenAnswer(
            (_) async => const ReservedUsernameRequestResult(
              success: false,
              error: null, // No error message provided
            ),
          );

          notifier.setEmail('test@example.com');
          notifier.setJustification('I am the owner');

          // Act
          final result = await notifier.submitRequest(username: 'username');

          // Assert
          expect(result, false);
          final state = container.read(reservedUsernameRequestProvider);
          expect(state.errorMessage, 'Failed to submit request');
        },
      );
    });
  });
}
