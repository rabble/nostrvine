// ABOUTME: Unit tests for UsernameNotifier Riverpod notifier
// ABOUTME: Tests availability checking and registration flow

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/username_notifier.dart';
import 'package:openvine/repositories/username_repository.dart';
import 'package:openvine/services/nip05_service.dart';
import 'package:openvine/state/username_state.dart';

class MockUsernameRepository extends Mock implements UsernameRepository {}

void main() {
  late MockUsernameRepository usernameRepository;

  setUp(() {
    usernameRepository = MockUsernameRepository();
  });

  /// Helper to create a container with mocked repository
  ProviderContainer createContainer() {
    final container = ProviderContainer(
      overrides: [
        usernameRepositoryProvider.overrideWithValue(usernameRepository),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('UsernameNotifier', () {
    group('onUsernameChanged', () {
      test('sets idle state for empty username', () {
        final container = createContainer();

        // Act
        container.read(usernameProvider.notifier).onUsernameChanged('');

        // Assert
        final state = container.read(usernameProvider);
        expect(state.status, UsernameCheckStatus.idle);
        expect(state.username, '');
      });

      test('sets idle state for short username (< 3 chars)', () {
        final container = createContainer();

        // Act
        container.read(usernameProvider.notifier).onUsernameChanged('ab');

        // Assert
        final state = container.read(usernameProvider);
        expect(state.status, UsernameCheckStatus.idle);
        expect(state.username, 'ab');
      });

      test('sets error state for invalid format', () {
        final container = createContainer();

        // Act
        container
            .read(usernameProvider.notifier)
            .onUsernameChanged('user@name');

        // Assert
        final state = container.read(usernameProvider);
        expect(state.status, UsernameCheckStatus.error);
        expect(state.errorMessage, 'Invalid format');
      });

      test('sets checking state immediately for valid username', () {
        final container = createContainer();

        // Act
        container
            .read(usernameProvider.notifier)
            .onUsernameChanged('validuser');

        // Assert
        final state = container.read(usernameProvider);
        expect(state.status, UsernameCheckStatus.checking);
        expect(state.username, 'validuser');
      });

      test('converts username to lowercase', () {
        final container = createContainer();

        // Act
        container
            .read(usernameProvider.notifier)
            .onUsernameChanged('ValidUser');

        // Assert
        final state = container.read(usernameProvider);
        expect(state.username, 'validuser');
      });

      test(
        'debounce timer triggers checkAvailability after delay',
        () async {
          // Create container without auto-dispose to let timer fire
          final container = ProviderContainer(
            overrides: [
              usernameRepositoryProvider.overrideWithValue(usernameRepository),
            ],
          );

          // Arrange
          when(
            () => usernameRepository.checkAvailability('validuser'),
          ).thenAnswer((_) async => UsernameAvailability.available);

          // Keep a listener active to prevent auto-dispose
          final sub = container.listen(usernameProvider, (_, __) {});

          // Act - trigger onUsernameChanged which starts debounce timer
          container
              .read(usernameProvider.notifier)
              .onUsernameChanged('validuser');

          // Initially should be checking
          expect(
            container.read(usernameProvider).status,
            UsernameCheckStatus.checking,
          );

          // Wait for debounce timer (500ms) plus buffer for async completion
          await Future<void>.delayed(const Duration(milliseconds: 700));

          // Assert - state should have updated to available after timer fired
          expect(
            container.read(usernameProvider).status,
            UsernameCheckStatus.available,
          );

          // Clean up
          sub.close();
          container.dispose();
        },
        timeout: const Timeout(Duration(seconds: 5)),
      );

      test('trims whitespace from username', () {
        final container = createContainer();

        // Act
        container
            .read(usernameProvider.notifier)
            .onUsernameChanged('  validuser  ');

        // Assert
        final state = container.read(usernameProvider);
        expect(state.username, 'validuser');
      });
    });

    group('checkAvailability', () {
      test('updates state to available when username is available', () async {
        final container = createContainer();

        // Arrange
        when(
          () => usernameRepository.checkAvailability('validuser'),
        ).thenAnswer((_) async => UsernameAvailability.available);

        // Set up checking state first (simulating onUsernameChanged)
        container
            .read(usernameProvider.notifier)
            .onUsernameChanged('validuser');

        // Act - call checkAvailability directly (bypassing debounce timer)
        await container
            .read(usernameProvider.notifier)
            .checkAvailability('validuser');

        // Assert
        final state = container.read(usernameProvider);
        expect(state.status, UsernameCheckStatus.available);
        expect(state.isAvailable, true);
        expect(state.canRegister, true);
        verify(
          () => usernameRepository.checkAvailability('validuser'),
        ).called(1);
      });

      test('updates state to taken when username is taken', () async {
        final container = createContainer();

        // Arrange
        when(
          () => usernameRepository.checkAvailability('takenuser'),
        ).thenAnswer((_) async => UsernameAvailability.taken);

        // Set up checking state first
        container
            .read(usernameProvider.notifier)
            .onUsernameChanged('takenuser');

        // Act
        await container
            .read(usernameProvider.notifier)
            .checkAvailability('takenuser');

        // Assert
        final state = container.read(usernameProvider);
        expect(state.status, UsernameCheckStatus.taken);
        expect(state.isTaken, true);
        expect(state.canRegister, false);
      });

      test('sets error state when availability check fails', () async {
        final container = createContainer();

        // Arrange
        when(
          () => usernameRepository.checkAvailability('erroruser'),
        ).thenAnswer((_) async => UsernameAvailability.error);

        // Set up checking state first
        container
            .read(usernameProvider.notifier)
            .onUsernameChanged('erroruser');

        // Act
        await container
            .read(usernameProvider.notifier)
            .checkAvailability('erroruser');

        // Assert
        final state = container.read(usernameProvider);
        expect(state.status, UsernameCheckStatus.error);
        expect(state.hasError, true);
        expect(state.errorMessage, 'Failed to check availability');
      });

      test('does not update state if username changed during check', () async {
        final container = createContainer();

        // Arrange
        when(
          () => usernameRepository.checkAvailability('olduser'),
        ).thenAnswer((_) async => UsernameAvailability.available);

        // Set up state for 'olduser'
        container.read(usernameProvider.notifier).onUsernameChanged('olduser');

        // Change to different username before check completes
        container.read(usernameProvider.notifier).onUsernameChanged('newuser');

        // Act - check for old username
        await container
            .read(usernameProvider.notifier)
            .checkAvailability('olduser');

        // Assert - state should still be for 'newuser' (checking), not 'olduser'
        final state = container.read(usernameProvider);
        expect(state.username, 'newuser');
        expect(state.status, UsernameCheckStatus.checking);
      });
    });

    group('registerUsername', () {
      const validPubkey =
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
      final relays = ['wss://relay1.com', 'wss://relay2.com'];

      test('returns error when username is not available', () async {
        final container = createContainer();

        // State is idle (not available)
        final result = await container
            .read(usernameProvider.notifier)
            .registerUsername(pubkey: validPubkey, relays: relays);

        expect(result.status, UsernameRegistrationStatus.error);
        expect(result.errorMessage, 'Username not available for registration');
      });

      test('registers successfully when username is available', () async {
        final container = createContainer();

        // Arrange - set up available state
        when(
          () => usernameRepository.checkAvailability('newuser'),
        ).thenAnswer((_) async => UsernameAvailability.available);
        when(
          () => usernameRepository.register(
            username: 'newuser',
            pubkey: validPubkey,
            relays: relays,
          ),
        ).thenAnswer(
          (_) async => const UsernameRegistrationResult(
            status: UsernameRegistrationStatus.success,
          ),
        );

        // Get to available state
        container.read(usernameProvider.notifier).onUsernameChanged('newuser');
        await container
            .read(usernameProvider.notifier)
            .checkAvailability('newuser');

        // Verify available state
        expect(container.read(usernameProvider).isAvailable, true);

        // Act
        final result = await container
            .read(usernameProvider.notifier)
            .registerUsername(pubkey: validPubkey, relays: relays);

        // Assert
        expect(result.isSuccess, true);
        verify(
          () => usernameRepository.register(
            username: 'newuser',
            pubkey: validPubkey,
            relays: relays,
          ),
        ).called(1);
      });

      test(
        'updates state to reserved when registration returns reserved',
        () async {
          final container = createContainer();

          // Arrange
          when(
            () => usernameRepository.checkAvailability('reserved'),
          ).thenAnswer((_) async => UsernameAvailability.available);
          when(
            () => usernameRepository.register(
              username: 'reserved',
              pubkey: validPubkey,
              relays: relays,
            ),
          ).thenAnswer(
            (_) async => const UsernameRegistrationResult(
              status: UsernameRegistrationStatus.reserved,
              errorMessage: 'Username is reserved',
            ),
          );

          // Get to available state
          container
              .read(usernameProvider.notifier)
              .onUsernameChanged('reserved');
          await container
              .read(usernameProvider.notifier)
              .checkAvailability('reserved');

          // Act
          final result = await container
              .read(usernameProvider.notifier)
              .registerUsername(pubkey: validPubkey, relays: relays);

          // Assert
          expect(result.isReserved, true);
          final state = container.read(usernameProvider);
          expect(state.isReserved, true);
          expect(state.status, UsernameCheckStatus.reserved);
        },
      );

      test('updates state to taken when registration returns taken', () async {
        final container = createContainer();

        // Arrange
        when(
          () => usernameRepository.checkAvailability('justtaken'),
        ).thenAnswer((_) async => UsernameAvailability.available);
        when(
          () => usernameRepository.register(
            username: 'justtaken',
            pubkey: validPubkey,
            relays: relays,
          ),
        ).thenAnswer(
          (_) async => const UsernameRegistrationResult(
            status: UsernameRegistrationStatus.taken,
            errorMessage: 'Username already taken',
          ),
        );

        // Get to available state
        container
            .read(usernameProvider.notifier)
            .onUsernameChanged('justtaken');
        await container
            .read(usernameProvider.notifier)
            .checkAvailability('justtaken');

        // Act
        final result = await container
            .read(usernameProvider.notifier)
            .registerUsername(pubkey: validPubkey, relays: relays);

        // Assert
        expect(result.isTaken, true);
        final state = container.read(usernameProvider);
        expect(state.isTaken, true);
        expect(state.status, UsernameCheckStatus.taken);
      });
    });

    group('clear', () {
      test('resets state to initial', () async {
        final container = createContainer();

        // Arrange - get into a non-initial state
        when(
          () => usernameRepository.checkAvailability('testuser'),
        ).thenAnswer((_) async => UsernameAvailability.available);

        container.read(usernameProvider.notifier).onUsernameChanged('testuser');
        await container
            .read(usernameProvider.notifier)
            .checkAvailability('testuser');

        // Verify we're not in initial state
        expect(
          container.read(usernameProvider).status,
          UsernameCheckStatus.available,
        );

        // Act
        container.read(usernameProvider.notifier).clear();

        // Assert
        final state = container.read(usernameProvider);
        expect(state.status, UsernameCheckStatus.idle);
        expect(state.username, '');
        expect(state.errorMessage, isNull);
      });
    });
  });
}
