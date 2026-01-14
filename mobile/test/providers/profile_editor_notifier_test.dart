// ABOUTME: Unit tests for ProfileEditorNotifier Riverpod notifier
// ABOUTME: Tests profile publishing and username claiming with rollback on failure

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/models/user_profile.dart' as app_models;
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/profile_editor_notifier.dart';
import 'package:openvine/repositories/username_repository.dart';
import 'package:openvine/services/user_profile_service.dart';
import 'package:profile_repository/profile_repository.dart';

class MockUsernameRepository extends Mock implements UsernameRepository {}

class MockProfileRepository extends Mock implements ProfileRepository {}

class MockUserProfileService extends Mock implements UserProfileService {}

void main() {
  late MockUsernameRepository mockUsernameRepository;
  late MockProfileRepository mockProfileRepository;
  late MockUserProfileService mockUserProfileService;

  // Test data constants - using full 64-character hex pubkey as required
  const testPubkey =
      'a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2';
  const testDisplayName = 'Test User';
  const testAbout = 'Test bio';
  const testUsername = 'testuser';
  const testPicture = 'https://example.com/avatar.png';
  const testNip05 = '$testUsername@divine.video';
  const testOriginalNip05 = 'original@example.com';

  setUpAll(() {
    // Register fallback value for app_models.UserProfile (used by UserProfileService)
    registerFallbackValue(
      app_models.UserProfile(
        pubkey: testPubkey,
        displayName: testDisplayName,
        rawData: const {},
        createdAt: DateTime.now(),
        eventId:
            'fallback12345678901234567890123456789012345678901234567890123456',
      ),
    );
  });

  setUp(() {
    mockUsernameRepository = MockUsernameRepository();
    mockProfileRepository = MockProfileRepository();
    mockUserProfileService = MockUserProfileService();

    // Default stub for updateCachedProfile - tests can override if needed
    when(
      () => mockUserProfileService.updateCachedProfile(any()),
    ).thenAnswer((_) async {});
  });

  /// Helper to create a test UserProfile
  UserProfile createTestProfile({String? nip05}) {
    return UserProfile(
      pubkey: testPubkey,
      displayName: testDisplayName,
      about: testAbout,
      picture: testPicture,
      nip05: nip05,
      rawData: const {},
      createdAt: DateTime.now(),
      eventId:
          'event123456789012345678901234567890123456789012345678901234567890',
    );
  }

  /// Helper to create a container with mocked dependencies
  ProviderContainer createContainer() {
    final container = ProviderContainer(
      overrides: [
        usernameRepositoryProvider.overrideWithValue(mockUsernameRepository),
        profileRepositoryProvider.overrideWithValue(mockProfileRepository),
        userProfileServiceProvider.overrideWithValue(mockUserProfileService),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('ProfileEditorNotifier', () {
    group('build', () {
      test('returns null initially', () async {
        final container = createContainer();

        final state = container.read(profileEditorProvider);

        expect(state, isA<AsyncData<ProfileSaveResult?>>());
        expect(state.value, isNull);
      });
    });

    group('saveProfile', () {
      group('without username', () {
        test(
          'publishes profile and returns success when no username provided',
          () async {
            // Arrange
            final container = createContainer();
            when(
              () => mockProfileRepository.getProfile(pubkey: testPubkey),
            ).thenAnswer((_) async => null);
            when(
              () => mockProfileRepository.saveProfileEvent(
                displayName: testDisplayName,
                about: testAbout,
                nip05: null,
                picture: testPicture,
                currentProfile: null,
              ),
            ).thenAnswer((_) async => createTestProfile());

            // Act
            await container
                .read(profileEditorProvider.notifier)
                .saveProfile(
                  pubkey: testPubkey,
                  displayName: testDisplayName,
                  about: testAbout,
                  picture: testPicture,
                );

            // Assert
            final state = container.read(profileEditorProvider);
            expect(state, isA<AsyncData<ProfileSaveResult?>>());
            expect(state.value, ProfileSaveResult.success);
            verify(
              () => mockProfileRepository.saveProfileEvent(
                displayName: testDisplayName,
                about: testAbout,
                nip05: null,
                picture: testPicture,
                currentProfile: null,
              ),
            ).called(1);
            verifyNever(
              () => mockUsernameRepository.register(
                username: any(named: 'username'),
                pubkey: any(named: 'pubkey'),
              ),
            );
          },
        );

        test('publishes profile with existing profile data', () async {
          // Arrange
          final container = createContainer();
          final existingProfile = createTestProfile(nip05: testOriginalNip05);
          when(
            () => mockProfileRepository.getProfile(pubkey: testPubkey),
          ).thenAnswer((_) async => existingProfile);
          when(
            () => mockProfileRepository.saveProfileEvent(
              displayName: testDisplayName,
              about: testAbout,
              nip05: null,
              picture: testPicture,
              currentProfile: existingProfile,
            ),
          ).thenAnswer((_) async => createTestProfile());

          // Act
          await container
              .read(profileEditorProvider.notifier)
              .saveProfile(
                pubkey: testPubkey,
                displayName: testDisplayName,
                about: testAbout,
                picture: testPicture,
              );

          // Assert
          final state = container.read(profileEditorProvider);
          expect(state.value, ProfileSaveResult.success);
          verify(
            () => mockProfileRepository.saveProfileEvent(
              displayName: testDisplayName,
              about: testAbout,
              nip05: null,
              picture: testPicture,
              currentProfile: existingProfile,
            ),
          ).called(1);
        });

        test(
          'publishes profile with null nip05 when username is empty string',
          () async {
            // Arrange
            final container = createContainer();
            when(
              () => mockProfileRepository.getProfile(pubkey: testPubkey),
            ).thenAnswer((_) async => null);
            when(
              () => mockProfileRepository.saveProfileEvent(
                displayName: testDisplayName,
                about: testAbout,
                nip05: null,
                picture: testPicture,
                currentProfile: null,
              ),
            ).thenAnswer((_) async => createTestProfile());
            // Note: Current implementation still calls register with empty
            // string when username is '' (not null). This mocks that behavior.
            when(
              () => mockUsernameRepository.register(
                username: '',
                pubkey: testPubkey,
              ),
            ).thenAnswer((_) async => const UsernameClaimSuccess());

            // Act
            await container
                .read(profileEditorProvider.notifier)
                .saveProfile(
                  pubkey: testPubkey,
                  displayName: testDisplayName,
                  about: testAbout,
                  picture: testPicture,
                  username: '', // Empty string
                );

            // Assert
            final state = container.read(profileEditorProvider);
            expect(state.value, ProfileSaveResult.success);
            // Verify nip05 was null (not '@divine.video')
            verify(
              () => mockProfileRepository.saveProfileEvent(
                displayName: testDisplayName,
                about: testAbout,
                nip05: null,
                picture: testPicture,
                currentProfile: null,
              ),
            ).called(1);
          },
        );
      });

      group('with username', () {
        test(
          'publishes profile with nip05, claims username, and returns success',
          () async {
            // Arrange
            final container = createContainer();
            when(
              () => mockProfileRepository.getProfile(pubkey: testPubkey),
            ).thenAnswer((_) async => null);
            when(
              () => mockProfileRepository.saveProfileEvent(
                displayName: testDisplayName,
                about: testAbout,
                nip05: testNip05,
                picture: testPicture,
                currentProfile: null,
              ),
            ).thenAnswer((_) async => createTestProfile());
            when(
              () => mockUsernameRepository.register(
                username: testUsername,
                pubkey: testPubkey,
              ),
            ).thenAnswer((_) async => const UsernameClaimSuccess());

            // Act
            await container
                .read(profileEditorProvider.notifier)
                .saveProfile(
                  pubkey: testPubkey,
                  displayName: testDisplayName,
                  about: testAbout,
                  picture: testPicture,
                  username: testUsername,
                );

            // Assert
            final state = container.read(profileEditorProvider);
            expect(state, isA<AsyncData<ProfileSaveResult?>>());
            expect(state.value, ProfileSaveResult.success);
            verify(
              () => mockProfileRepository.saveProfileEvent(
                displayName: testDisplayName,
                about: testAbout,
                nip05: testNip05,
                picture: testPicture,
                currentProfile: null,
              ),
            ).called(1);
            verify(
              () => mockUsernameRepository.register(
                username: testUsername,
                pubkey: testPubkey,
              ),
            ).called(1);
          },
        );

        test(
          'does not call saveProfileEvent again when username claim succeeds',
          () async {
            // Arrange
            final container = createContainer();
            final existingProfile = createTestProfile(nip05: testOriginalNip05);
            when(
              () => mockProfileRepository.getProfile(pubkey: testPubkey),
            ).thenAnswer((_) async => existingProfile);
            when(
              () => mockProfileRepository.saveProfileEvent(
                displayName: testDisplayName,
                about: testAbout,
                nip05: testNip05,
                picture: testPicture,
                currentProfile: existingProfile,
              ),
            ).thenAnswer((_) async => createTestProfile());
            when(
              () => mockUsernameRepository.register(
                username: testUsername,
                pubkey: testPubkey,
              ),
            ).thenAnswer((_) async => const UsernameClaimSuccess());

            // Act
            await container
                .read(profileEditorProvider.notifier)
                .saveProfile(
                  pubkey: testPubkey,
                  displayName: testDisplayName,
                  about: testAbout,
                  picture: testPicture,
                  username: testUsername,
                );

            // Assert - saveProfileEvent should only be called once (no rollback)
            verify(
              () => mockProfileRepository.saveProfileEvent(
                displayName: testDisplayName,
                about: testAbout,
                nip05: testNip05,
                picture: testPicture,
                currentProfile: existingProfile,
              ),
            ).called(1);
          },
        );
      });

      group('profile publish failure', () {
        test(
          'returns profilePublishFailed when saveProfileEvent throws',
          () async {
            // Arrange
            final container = createContainer();
            when(
              () => mockProfileRepository.getProfile(pubkey: testPubkey),
            ).thenAnswer((_) async => null);
            when(
              () => mockProfileRepository.saveProfileEvent(
                displayName: testDisplayName,
                about: testAbout,
                nip05: null,
                picture: testPicture,
                currentProfile: null,
              ),
            ).thenThrow(const ProfilePublishFailedException('Network error'));

            // Act
            await container
                .read(profileEditorProvider.notifier)
                .saveProfile(
                  pubkey: testPubkey,
                  displayName: testDisplayName,
                  about: testAbout,
                  picture: testPicture,
                );

            // Assert
            final state = container.read(profileEditorProvider);
            expect(state, isA<AsyncError<ProfileSaveResult?>>());
            expect(state.error, ProfileSaveResult.profilePublishFailed);
          },
        );

        test(
          'does not attempt username claim when profile publish fails',
          () async {
            // Arrange
            final container = createContainer();
            when(
              () => mockProfileRepository.getProfile(pubkey: testPubkey),
            ).thenAnswer((_) async => null);
            when(
              () => mockProfileRepository.saveProfileEvent(
                displayName: testDisplayName,
                about: testAbout,
                nip05: testNip05,
                picture: testPicture,
                currentProfile: null,
              ),
            ).thenThrow(const ProfilePublishFailedException('Network error'));

            // Act
            await container
                .read(profileEditorProvider.notifier)
                .saveProfile(
                  pubkey: testPubkey,
                  displayName: testDisplayName,
                  about: testAbout,
                  picture: testPicture,
                  username: testUsername,
                );

            // Assert
            verifyNever(
              () => mockUsernameRepository.register(
                username: any(named: 'username'),
                pubkey: any(named: 'pubkey'),
              ),
            );
          },
        );
      });

      group('username claim failure - taken', () {
        test('returns usernameTaken when username is already taken', () async {
          // Arrange
          final container = createContainer();
          final existingProfile = createTestProfile(nip05: testOriginalNip05);
          when(
            () => mockProfileRepository.getProfile(pubkey: testPubkey),
          ).thenAnswer((_) async => existingProfile);
          when(
            () => mockProfileRepository.saveProfileEvent(
              displayName: testDisplayName,
              about: testAbout,
              nip05: testNip05,
              picture: testPicture,
              currentProfile: existingProfile,
            ),
          ).thenAnswer((_) async => createTestProfile());
          when(
            () => mockUsernameRepository.register(
              username: testUsername,
              pubkey: testPubkey,
            ),
          ).thenAnswer((_) async => const UsernameClaimTaken());
          // Rollback call
          when(
            () => mockProfileRepository.saveProfileEvent(
              displayName: testDisplayName,
              about: testAbout,
              nip05: testOriginalNip05,
              picture: testPicture,
              currentProfile: existingProfile,
            ),
          ).thenAnswer((_) async => createTestProfile());

          // Act
          await container
              .read(profileEditorProvider.notifier)
              .saveProfile(
                pubkey: testPubkey,
                displayName: testDisplayName,
                about: testAbout,
                picture: testPicture,
                username: testUsername,
              );

          // Assert
          final state = container.read(profileEditorProvider);
          expect(state, isA<AsyncData<ProfileSaveResult?>>());
          expect(state.value, ProfileSaveResult.usernameTaken);
        });

        test(
          'rolls back profile with original nip05 when username is taken',
          () async {
            // Arrange
            final container = createContainer();
            final existingProfile = createTestProfile(nip05: testOriginalNip05);
            when(
              () => mockProfileRepository.getProfile(pubkey: testPubkey),
            ).thenAnswer((_) async => existingProfile);
            when(
              () => mockProfileRepository.saveProfileEvent(
                displayName: testDisplayName,
                about: testAbout,
                nip05: testNip05,
                picture: testPicture,
                currentProfile: existingProfile,
              ),
            ).thenAnswer((_) async => createTestProfile());
            when(
              () => mockUsernameRepository.register(
                username: testUsername,
                pubkey: testPubkey,
              ),
            ).thenAnswer((_) async => const UsernameClaimTaken());
            when(
              () => mockProfileRepository.saveProfileEvent(
                displayName: testDisplayName,
                about: testAbout,
                nip05: testOriginalNip05,
                picture: testPicture,
                currentProfile: existingProfile,
              ),
            ).thenAnswer((_) async => createTestProfile());

            // Act
            await container
                .read(profileEditorProvider.notifier)
                .saveProfile(
                  pubkey: testPubkey,
                  displayName: testDisplayName,
                  about: testAbout,
                  picture: testPicture,
                  username: testUsername,
                );

            // Assert - verify saveProfileEvent was called twice
            // First with new nip05, second with original nip05 (rollback)
            verifyInOrder([
              () => mockProfileRepository.saveProfileEvent(
                displayName: testDisplayName,
                about: testAbout,
                nip05: testNip05,
                picture: testPicture,
                currentProfile: existingProfile,
              ),
              () => mockProfileRepository.saveProfileEvent(
                displayName: testDisplayName,
                about: testAbout,
                nip05: testOriginalNip05,
                picture: testPicture,
                currentProfile: existingProfile,
              ),
            ]);
          },
        );

        test('rolls back to null nip05 when no existing profile', () async {
          // Arrange
          final container = createContainer();
          when(
            () => mockProfileRepository.getProfile(pubkey: testPubkey),
          ).thenAnswer((_) async => null);
          when(
            () => mockProfileRepository.saveProfileEvent(
              displayName: testDisplayName,
              about: testAbout,
              nip05: testNip05,
              picture: testPicture,
              currentProfile: null,
            ),
          ).thenAnswer((_) async => createTestProfile());
          when(
            () => mockUsernameRepository.register(
              username: testUsername,
              pubkey: testPubkey,
            ),
          ).thenAnswer((_) async => const UsernameClaimTaken());
          when(
            () => mockProfileRepository.saveProfileEvent(
              displayName: testDisplayName,
              about: testAbout,
              nip05: null,
              picture: testPicture,
              currentProfile: null,
            ),
          ).thenAnswer((_) async => createTestProfile());

          // Act
          await container
              .read(profileEditorProvider.notifier)
              .saveProfile(
                pubkey: testPubkey,
                displayName: testDisplayName,
                about: testAbout,
                picture: testPicture,
                username: testUsername,
              );

          // Assert - verify rollback with null nip05
          verifyInOrder([
            () => mockProfileRepository.saveProfileEvent(
              displayName: testDisplayName,
              about: testAbout,
              nip05: testNip05,
              picture: testPicture,
              currentProfile: null,
            ),
            () => mockProfileRepository.saveProfileEvent(
              displayName: testDisplayName,
              about: testAbout,
              nip05: null,
              picture: testPicture,
              currentProfile: null,
            ),
          ]);
        });
      });

      group('username claim failure - reserved', () {
        test('returns usernameReserved when username is reserved', () async {
          // Arrange
          final container = createContainer();
          final existingProfile = createTestProfile(nip05: testOriginalNip05);
          when(
            () => mockProfileRepository.getProfile(pubkey: testPubkey),
          ).thenAnswer((_) async => existingProfile);
          when(
            () => mockProfileRepository.saveProfileEvent(
              displayName: testDisplayName,
              about: testAbout,
              nip05: testNip05,
              picture: testPicture,
              currentProfile: existingProfile,
            ),
          ).thenAnswer((_) async => createTestProfile());
          when(
            () => mockUsernameRepository.register(
              username: testUsername,
              pubkey: testPubkey,
            ),
          ).thenAnswer((_) async => const UsernameClaimReserved());
          when(
            () => mockProfileRepository.saveProfileEvent(
              displayName: testDisplayName,
              about: testAbout,
              nip05: testOriginalNip05,
              picture: testPicture,
              currentProfile: existingProfile,
            ),
          ).thenAnswer((_) async => createTestProfile());

          // Act
          await container
              .read(profileEditorProvider.notifier)
              .saveProfile(
                pubkey: testPubkey,
                displayName: testDisplayName,
                about: testAbout,
                picture: testPicture,
                username: testUsername,
              );

          // Assert
          final state = container.read(profileEditorProvider);
          expect(state, isA<AsyncData<ProfileSaveResult?>>());
          expect(state.value, ProfileSaveResult.usernameReserved);
        });

        test(
          'rolls back profile with original nip05 when username is reserved',
          () async {
            // Arrange
            final container = createContainer();
            final existingProfile = createTestProfile(nip05: testOriginalNip05);
            when(
              () => mockProfileRepository.getProfile(pubkey: testPubkey),
            ).thenAnswer((_) async => existingProfile);
            when(
              () => mockProfileRepository.saveProfileEvent(
                displayName: testDisplayName,
                about: testAbout,
                nip05: testNip05,
                picture: testPicture,
                currentProfile: existingProfile,
              ),
            ).thenAnswer((_) async => createTestProfile());
            when(
              () => mockUsernameRepository.register(
                username: testUsername,
                pubkey: testPubkey,
              ),
            ).thenAnswer((_) async => const UsernameClaimReserved());
            when(
              () => mockProfileRepository.saveProfileEvent(
                displayName: testDisplayName,
                about: testAbout,
                nip05: testOriginalNip05,
                picture: testPicture,
                currentProfile: existingProfile,
              ),
            ).thenAnswer((_) async => createTestProfile());

            // Act
            await container
                .read(profileEditorProvider.notifier)
                .saveProfile(
                  pubkey: testPubkey,
                  displayName: testDisplayName,
                  about: testAbout,
                  picture: testPicture,
                  username: testUsername,
                );

            // Assert - verify saveProfileEvent was called twice with rollback
            verifyInOrder([
              () => mockProfileRepository.saveProfileEvent(
                displayName: testDisplayName,
                about: testAbout,
                nip05: testNip05,
                picture: testPicture,
                currentProfile: existingProfile,
              ),
              () => mockProfileRepository.saveProfileEvent(
                displayName: testDisplayName,
                about: testAbout,
                nip05: testOriginalNip05,
                picture: testPicture,
                currentProfile: existingProfile,
              ),
            ]);
          },
        );
      });

      group('username claim failure - error', () {
        test('returns AsyncError when username claim returns error', () async {
          // Arrange
          final container = createContainer();
          final existingProfile = createTestProfile(nip05: testOriginalNip05);
          when(
            () => mockProfileRepository.getProfile(pubkey: testPubkey),
          ).thenAnswer((_) async => existingProfile);
          when(
            () => mockProfileRepository.saveProfileEvent(
              displayName: testDisplayName,
              about: testAbout,
              nip05: testNip05,
              picture: testPicture,
              currentProfile: existingProfile,
            ),
          ).thenAnswer((_) async => createTestProfile());
          when(
            () => mockUsernameRepository.register(
              username: testUsername,
              pubkey: testPubkey,
            ),
          ).thenAnswer(
            (_) async => const UsernameClaimError('Server unavailable'),
          );
          when(
            () => mockProfileRepository.saveProfileEvent(
              displayName: testDisplayName,
              about: testAbout,
              nip05: testOriginalNip05,
              picture: testPicture,
              currentProfile: existingProfile,
            ),
          ).thenAnswer((_) async => createTestProfile());

          // Act
          await container
              .read(profileEditorProvider.notifier)
              .saveProfile(
                pubkey: testPubkey,
                displayName: testDisplayName,
                about: testAbout,
                picture: testPicture,
                username: testUsername,
              );

          // Assert
          final state = container.read(profileEditorProvider);
          expect(state, isA<AsyncError<ProfileSaveResult?>>());
          expect(state.error, 'Server unavailable');
        });

        test('rolls back profile when username claim returns error', () async {
          // Arrange
          final container = createContainer();
          final existingProfile = createTestProfile(nip05: testOriginalNip05);
          when(
            () => mockProfileRepository.getProfile(pubkey: testPubkey),
          ).thenAnswer((_) async => existingProfile);
          when(
            () => mockProfileRepository.saveProfileEvent(
              displayName: testDisplayName,
              about: testAbout,
              nip05: testNip05,
              picture: testPicture,
              currentProfile: existingProfile,
            ),
          ).thenAnswer((_) async => createTestProfile());
          when(
            () => mockUsernameRepository.register(
              username: testUsername,
              pubkey: testPubkey,
            ),
          ).thenAnswer(
            (_) async => const UsernameClaimError('Server unavailable'),
          );
          when(
            () => mockProfileRepository.saveProfileEvent(
              displayName: testDisplayName,
              about: testAbout,
              nip05: testOriginalNip05,
              picture: testPicture,
              currentProfile: existingProfile,
            ),
          ).thenAnswer((_) async => createTestProfile());

          // Act
          await container
              .read(profileEditorProvider.notifier)
              .saveProfile(
                pubkey: testPubkey,
                displayName: testDisplayName,
                about: testAbout,
                picture: testPicture,
                username: testUsername,
              );

          // Assert - verify rollback was called
          verifyInOrder([
            () => mockProfileRepository.saveProfileEvent(
              displayName: testDisplayName,
              about: testAbout,
              nip05: testNip05,
              picture: testPicture,
              currentProfile: existingProfile,
            ),
            () => mockProfileRepository.saveProfileEvent(
              displayName: testDisplayName,
              about: testAbout,
              nip05: testOriginalNip05,
              picture: testPicture,
              currentProfile: existingProfile,
            ),
          ]);
        });
      });

      group('rollback failure handling', () {
        test('still returns correct error when rollback fails', () async {
          // Arrange
          final container = createContainer();
          final existingProfile = createTestProfile(nip05: testOriginalNip05);
          when(
            () => mockProfileRepository.getProfile(pubkey: testPubkey),
          ).thenAnswer((_) async => existingProfile);
          when(
            () => mockProfileRepository.saveProfileEvent(
              displayName: testDisplayName,
              about: testAbout,
              nip05: testNip05,
              picture: testPicture,
              currentProfile: existingProfile,
            ),
          ).thenAnswer((_) async => createTestProfile());
          when(
            () => mockUsernameRepository.register(
              username: testUsername,
              pubkey: testPubkey,
            ),
          ).thenAnswer((_) async => const UsernameClaimTaken());
          // Rollback fails
          when(
            () => mockProfileRepository.saveProfileEvent(
              displayName: testDisplayName,
              about: testAbout,
              nip05: testOriginalNip05,
              picture: testPicture,
              currentProfile: existingProfile,
            ),
          ).thenThrow(const ProfilePublishFailedException('Rollback failed'));

          // Act
          await container
              .read(profileEditorProvider.notifier)
              .saveProfile(
                pubkey: testPubkey,
                displayName: testDisplayName,
                about: testAbout,
                picture: testPicture,
                username: testUsername,
              );

          // Assert - state should still reflect the username taken error
          // even though rollback failed (silently logged)
          final state = container.read(profileEditorProvider);
          expect(state, isA<AsyncData<ProfileSaveResult?>>());
          expect(state.value, ProfileSaveResult.usernameTaken);
        });
      });

      group('state transitions', () {
        test('sets loading state while operation is in progress', () async {
          // Arrange
          final container = createContainer();
          when(
            () => mockProfileRepository.getProfile(pubkey: testPubkey),
          ).thenAnswer((_) async => null);
          when(
            () => mockProfileRepository.saveProfileEvent(
              displayName: testDisplayName,
              about: testAbout,
              nip05: null,
              picture: testPicture,
              currentProfile: null,
            ),
          ).thenAnswer((_) async {
            // Simulate some delay
            await Future<void>.delayed(const Duration(milliseconds: 10));
            return createTestProfile();
          });

          // Listen to state changes
          final states = <AsyncValue<ProfileSaveResult?>>[];
          final subscription = container.listen(
            profileEditorProvider,
            (_, next) => states.add(next),
          );

          // Act
          final future = container
              .read(profileEditorProvider.notifier)
              .saveProfile(
                pubkey: testPubkey,
                displayName: testDisplayName,
                about: testAbout,
                picture: testPicture,
              );

          // Wait a bit for loading state
          await Future<void>.delayed(const Duration(milliseconds: 1));

          // Check that we went through loading state
          expect(states.any((s) => s.isLoading), isTrue);

          await future;
          subscription.close();

          // Final state should be success
          final finalState = container.read(profileEditorProvider);
          expect(finalState.value, ProfileSaveResult.success);
        });
      });
    });
  });
}
