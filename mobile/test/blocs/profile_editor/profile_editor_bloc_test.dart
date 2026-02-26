// ABOUTME: Unit tests for ProfileEditorBloc
// ABOUTME: Tests profile publishing and username claiming with rollback on failure

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/profile_editor/profile_editor_bloc.dart';
import 'package:openvine/services/user_profile_service.dart';
import 'package:profile_repository/profile_repository.dart';

class _MockProfileRepository extends Mock implements ProfileRepository {}

class _MockUserProfileService extends Mock implements UserProfileService {}

void main() {
  group('ProfileEditorBloc', () {
    late _MockProfileRepository mockProfileRepository;
    late _MockUserProfileService mockUserProfileService;

    // Test data constants - using full 64-character hex pubkey as required
    const testPubkey =
        'a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2';
    const testDisplayName = 'Test User';
    const testAbout = 'Test bio';
    const testUsername = 'testuser';
    const testPicture = 'https://example.com/avatar.png';

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

    setUpAll(() {
      registerFallbackValue(
        UserProfile(
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
      mockProfileRepository = _MockProfileRepository();
      mockUserProfileService = _MockUserProfileService();

      when(
        () => mockUserProfileService.updateCachedProfile(any()),
      ).thenAnswer((_) async {});
    });

    ProfileEditorBloc createBloc({bool hasExistingProfile = true}) =>
        ProfileEditorBloc(
          profileRepository: mockProfileRepository,
          userProfileService: mockUserProfileService,
          hasExistingProfile: hasExistingProfile,
        );

    test('initial state is ProfileEditorStatus.initial', () {
      final bloc = createBloc();
      expect(bloc.state.status, ProfileEditorStatus.initial);
      expect(bloc.state.error, isNull);
      bloc.close();
    });

    group('ProfileSaved', () {
      group('without username', () {
        blocTest<ProfileEditorBloc, ProfileEditorState>(
          'emits [loading, success] when profile publishes successfully',
          setUp: () {
            when(
              () => mockProfileRepository.getCachedProfile(pubkey: testPubkey),
            ).thenAnswer((_) async => null);
            when(
              () => mockProfileRepository.saveProfileEvent(
                displayName: testDisplayName,
                about: testAbout,
                picture: testPicture,
              ),
            ).thenAnswer((_) async => createTestProfile());
          },
          build: createBloc,
          act: (bloc) => bloc.add(
            const ProfileSaved(
              pubkey: testPubkey,
              displayName: testDisplayName,
              about: testAbout,
              picture: testPicture,
            ),
          ),
          expect: () => [
            isA<ProfileEditorState>().having(
              (s) => s.status,
              'status',
              ProfileEditorStatus.loading,
            ),
            isA<ProfileEditorState>().having(
              (s) => s.status,
              'status',
              ProfileEditorStatus.success,
            ),
          ],
          verify: (_) {
            verify(
              () => mockProfileRepository.saveProfileEvent(
                displayName: testDisplayName,
                about: testAbout,
                picture: testPicture,
              ),
            ).called(1);
            verifyNever(
              () => mockProfileRepository.claimUsername(
                username: any(named: 'username'),
              ),
            );
          },
        );

        blocTest<ProfileEditorBloc, ProfileEditorState>(
          'publishes profile with existing profile data',
          setUp: () {
            final existingProfile = createTestProfile(
              nip05: 'original@example.com',
            );
            when(
              () => mockProfileRepository.getCachedProfile(pubkey: testPubkey),
            ).thenAnswer((_) async => existingProfile);
            when(
              () => mockProfileRepository.saveProfileEvent(
                displayName: testDisplayName,
                about: testAbout,
                picture: testPicture,
                currentProfile: existingProfile,
              ),
            ).thenAnswer((_) async => createTestProfile());
          },
          build: createBloc,
          act: (bloc) => bloc.add(
            const ProfileSaved(
              pubkey: testPubkey,
              displayName: testDisplayName,
              about: testAbout,
              picture: testPicture,
            ),
          ),
          expect: () => [
            isA<ProfileEditorState>().having(
              (s) => s.status,
              'status',
              ProfileEditorStatus.loading,
            ),
            isA<ProfileEditorState>().having(
              (s) => s.status,
              'status',
              ProfileEditorStatus.success,
            ),
          ],
        );

        blocTest<ProfileEditorBloc, ProfileEditorState>(
          'publishes profile with null username when username is empty string',
          setUp: () {
            when(
              () => mockProfileRepository.getCachedProfile(pubkey: testPubkey),
            ).thenAnswer((_) async => null);
            when(
              () => mockProfileRepository.saveProfileEvent(
                displayName: testDisplayName,
                about: testAbout,
                picture: testPicture,
              ),
            ).thenAnswer((_) async => createTestProfile());
          },
          build: createBloc,
          act: (bloc) => bloc.add(
            const ProfileSaved(
              pubkey: testPubkey,
              displayName: testDisplayName,
              about: testAbout,
              picture: testPicture,
              username: '',
            ),
          ),
          expect: () => [
            isA<ProfileEditorState>().having(
              (s) => s.status,
              'status',
              ProfileEditorStatus.loading,
            ),
            isA<ProfileEditorState>().having(
              (s) => s.status,
              'status',
              ProfileEditorStatus.success,
            ),
          ],
          verify: (_) {
            verify(
              () => mockProfileRepository.saveProfileEvent(
                displayName: testDisplayName,
                about: testAbout,
                picture: testPicture,
              ),
            ).called(1);
          },
        );
      });

      group('with username', () {
        blocTest<ProfileEditorBloc, ProfileEditorState>(
          'emits [loading, success] when profile and username claim succeed',
          setUp: () {
            when(
              () => mockProfileRepository.getCachedProfile(pubkey: testPubkey),
            ).thenAnswer((_) async => null);
            when(
              () => mockProfileRepository.saveProfileEvent(
                displayName: testDisplayName,
                about: testAbout,
                username: testUsername,
                picture: testPicture,
              ),
            ).thenAnswer((_) async => createTestProfile());
            when(
              () => mockProfileRepository.claimUsername(username: testUsername),
            ).thenAnswer((_) async => const UsernameClaimSuccess());
          },
          build: createBloc,
          act: (bloc) => bloc.add(
            const ProfileSaved(
              pubkey: testPubkey,
              displayName: testDisplayName,
              about: testAbout,
              picture: testPicture,
              username: testUsername,
            ),
          ),
          expect: () => [
            isA<ProfileEditorState>().having(
              (s) => s.status,
              'status',
              ProfileEditorStatus.loading,
            ),
            isA<ProfileEditorState>().having(
              (s) => s.status,
              'status',
              ProfileEditorStatus.success,
            ),
          ],
          verify: (_) {
            verify(
              () => mockProfileRepository.saveProfileEvent(
                displayName: testDisplayName,
                about: testAbout,
                username: testUsername,
                picture: testPicture,
              ),
            ).called(1);
            verify(
              () => mockProfileRepository.claimUsername(username: testUsername),
            ).called(1);
          },
        );
      });

      group('profile publish failure', () {
        blocTest<ProfileEditorBloc, ProfileEditorState>(
          'emits [loading, failure] with publishFailed error',
          setUp: () {
            when(
              () => mockProfileRepository.getCachedProfile(pubkey: testPubkey),
            ).thenAnswer((_) async => null);
            when(
              () => mockProfileRepository.saveProfileEvent(
                displayName: testDisplayName,
                about: testAbout,
                picture: testPicture,
              ),
            ).thenThrow(const ProfilePublishFailedException('Network error'));
          },
          build: createBloc,
          act: (bloc) => bloc.add(
            const ProfileSaved(
              pubkey: testPubkey,
              displayName: testDisplayName,
              about: testAbout,
              picture: testPicture,
            ),
          ),
          expect: () => [
            isA<ProfileEditorState>().having(
              (s) => s.status,
              'status',
              ProfileEditorStatus.loading,
            ),
            isA<ProfileEditorState>()
                .having((s) => s.status, 'status', ProfileEditorStatus.failure)
                .having(
                  (s) => s.error,
                  'error',
                  ProfileEditorError.publishFailed,
                ),
          ],
        );

        blocTest<ProfileEditorBloc, ProfileEditorState>(
          'does not attempt username claim when profile publish fails',
          setUp: () {
            when(
              () => mockProfileRepository.getCachedProfile(pubkey: testPubkey),
            ).thenAnswer((_) async => null);
            when(
              () => mockProfileRepository.saveProfileEvent(
                displayName: testDisplayName,
                about: testAbout,
                username: testUsername,
                picture: testPicture,
              ),
            ).thenThrow(const ProfilePublishFailedException('Network error'));
          },
          build: createBloc,
          act: (bloc) => bloc.add(
            const ProfileSaved(
              pubkey: testPubkey,
              displayName: testDisplayName,
              about: testAbout,
              picture: testPicture,
              username: testUsername,
            ),
          ),
          verify: (_) {
            verifyNever(
              () => mockProfileRepository.claimUsername(
                username: any(named: 'username'),
              ),
            );
          },
        );
      });

      group('username taken', () {
        blocTest<ProfileEditorBloc, ProfileEditorState>(
          'emits [loading, failure] with usernameTaken error',
          setUp: () {
            final existingProfile = createTestProfile(
              nip05: 'original@example.com',
            );
            when(
              () => mockProfileRepository.getCachedProfile(pubkey: testPubkey),
            ).thenAnswer((_) async => existingProfile);
            when(
              () => mockProfileRepository.saveProfileEvent(
                displayName: testDisplayName,
                about: testAbout,
                username: testUsername,
                picture: testPicture,
                currentProfile: existingProfile,
              ),
            ).thenAnswer((_) async => createTestProfile());
            when(
              () => mockProfileRepository.claimUsername(username: testUsername),
            ).thenAnswer((_) async => const UsernameClaimTaken());
            when(
              () => mockProfileRepository.saveProfileEvent(
                displayName: testDisplayName,
                about: testAbout,
                picture: testPicture,
                currentProfile: existingProfile,
              ),
            ).thenAnswer((_) async => createTestProfile());
          },
          build: createBloc,
          act: (bloc) => bloc.add(
            const ProfileSaved(
              pubkey: testPubkey,
              displayName: testDisplayName,
              about: testAbout,
              picture: testPicture,
              username: testUsername,
            ),
          ),
          expect: () => [
            isA<ProfileEditorState>().having(
              (s) => s.status,
              'status',
              ProfileEditorStatus.loading,
            ),
            isA<ProfileEditorState>()
                .having((s) => s.status, 'status', ProfileEditorStatus.failure)
                .having(
                  (s) => s.error,
                  'error',
                  ProfileEditorError.usernameTaken,
                ),
          ],
        );

        blocTest<ProfileEditorBloc, ProfileEditorState>(
          'rolls back profile preserving original nip05 via currentProfile',
          setUp: () {
            final existingProfile = createTestProfile(
              nip05: 'original@example.com',
            );
            when(
              () => mockProfileRepository.getCachedProfile(pubkey: testPubkey),
            ).thenAnswer((_) async => existingProfile);
            when(
              () => mockProfileRepository.saveProfileEvent(
                displayName: testDisplayName,
                about: testAbout,
                username: testUsername,
                picture: testPicture,
                currentProfile: existingProfile,
              ),
            ).thenAnswer((_) async => createTestProfile());
            when(
              () => mockProfileRepository.claimUsername(username: testUsername),
            ).thenAnswer((_) async => const UsernameClaimTaken());
            when(
              () => mockProfileRepository.saveProfileEvent(
                displayName: testDisplayName,
                about: testAbout,
                picture: testPicture,
                currentProfile: existingProfile,
              ),
            ).thenAnswer((_) async => createTestProfile());
          },
          build: createBloc,
          act: (bloc) => bloc.add(
            const ProfileSaved(
              pubkey: testPubkey,
              displayName: testDisplayName,
              about: testAbout,
              picture: testPicture,
              username: testUsername,
            ),
          ),
          verify: (_) {
            verifyInOrder([
              () => mockProfileRepository.saveProfileEvent(
                displayName: testDisplayName,
                about: testAbout,
                username: testUsername,
                picture: testPicture,
                currentProfile: any(named: 'currentProfile'),
              ),
              () => mockProfileRepository.saveProfileEvent(
                displayName: testDisplayName,
                about: testAbout,
                picture: testPicture,
                currentProfile: any(named: 'currentProfile'),
              ),
            ]);
          },
        );

        blocTest<ProfileEditorBloc, ProfileEditorState>(
          'rolls back with null currentProfile when no existing profile',
          setUp: () {
            when(
              () => mockProfileRepository.getCachedProfile(pubkey: testPubkey),
            ).thenAnswer((_) async => null);
            when(
              () => mockProfileRepository.saveProfileEvent(
                displayName: testDisplayName,
                about: testAbout,
                username: testUsername,
                picture: testPicture,
              ),
            ).thenAnswer((_) async => createTestProfile());
            when(
              () => mockProfileRepository.claimUsername(username: testUsername),
            ).thenAnswer((_) async => const UsernameClaimTaken());
            when(
              () => mockProfileRepository.saveProfileEvent(
                displayName: testDisplayName,
                about: testAbout,
                picture: testPicture,
              ),
            ).thenAnswer((_) async => createTestProfile());
          },
          build: createBloc,
          act: (bloc) => bloc.add(
            const ProfileSaved(
              pubkey: testPubkey,
              displayName: testDisplayName,
              about: testAbout,
              picture: testPicture,
              username: testUsername,
            ),
          ),
          verify: (_) {
            verifyInOrder([
              () => mockProfileRepository.saveProfileEvent(
                displayName: testDisplayName,
                about: testAbout,
                username: testUsername,
                picture: testPicture,
              ),
              () => mockProfileRepository.saveProfileEvent(
                displayName: testDisplayName,
                about: testAbout,
                picture: testPicture,
              ),
            ]);
          },
        );
      });

      group('username reserved', () {
        blocTest<ProfileEditorBloc, ProfileEditorState>(
          'emits [loading, failure] with usernameReserved error',
          setUp: () {
            final existingProfile = createTestProfile(
              nip05: 'original@example.com',
            );
            when(
              () => mockProfileRepository.getCachedProfile(pubkey: testPubkey),
            ).thenAnswer((_) async => existingProfile);
            when(
              () => mockProfileRepository.saveProfileEvent(
                displayName: testDisplayName,
                about: testAbout,
                username: testUsername,
                picture: testPicture,
                currentProfile: existingProfile,
              ),
            ).thenAnswer((_) async => createTestProfile());
            when(
              () => mockProfileRepository.claimUsername(username: testUsername),
            ).thenAnswer((_) async => const UsernameClaimReserved());
            when(
              () => mockProfileRepository.saveProfileEvent(
                displayName: testDisplayName,
                about: testAbout,
                picture: testPicture,
                currentProfile: existingProfile,
              ),
            ).thenAnswer((_) async => createTestProfile());
          },
          build: createBloc,
          act: (bloc) => bloc.add(
            const ProfileSaved(
              pubkey: testPubkey,
              displayName: testDisplayName,
              about: testAbout,
              picture: testPicture,
              username: testUsername,
            ),
          ),
          expect: () => [
            isA<ProfileEditorState>().having(
              (s) => s.status,
              'status',
              ProfileEditorStatus.loading,
            ),
            isA<ProfileEditorState>()
                .having((s) => s.status, 'status', ProfileEditorStatus.failure)
                .having(
                  (s) => s.error,
                  'error',
                  ProfileEditorError.usernameReserved,
                ),
          ],
        );

        blocTest<ProfileEditorBloc, ProfileEditorState>(
          'rolls back profile when username is reserved',
          setUp: () {
            final existingProfile = createTestProfile(
              nip05: 'original@example.com',
            );
            when(
              () => mockProfileRepository.getCachedProfile(pubkey: testPubkey),
            ).thenAnswer((_) async => existingProfile);
            when(
              () => mockProfileRepository.saveProfileEvent(
                displayName: testDisplayName,
                about: testAbout,
                username: testUsername,
                picture: testPicture,
                currentProfile: existingProfile,
              ),
            ).thenAnswer((_) async => createTestProfile());
            when(
              () => mockProfileRepository.claimUsername(username: testUsername),
            ).thenAnswer((_) async => const UsernameClaimReserved());
            when(
              () => mockProfileRepository.saveProfileEvent(
                displayName: testDisplayName,
                about: testAbout,
                picture: testPicture,
                currentProfile: existingProfile,
              ),
            ).thenAnswer((_) async => createTestProfile());
          },
          build: createBloc,
          act: (bloc) => bloc.add(
            const ProfileSaved(
              pubkey: testPubkey,
              displayName: testDisplayName,
              about: testAbout,
              picture: testPicture,
              username: testUsername,
            ),
          ),
          verify: (_) {
            verifyInOrder([
              () => mockProfileRepository.saveProfileEvent(
                displayName: testDisplayName,
                about: testAbout,
                username: testUsername,
                picture: testPicture,
                currentProfile: any(named: 'currentProfile'),
              ),
              () => mockProfileRepository.saveProfileEvent(
                displayName: testDisplayName,
                about: testAbout,
                picture: testPicture,
                currentProfile: any(named: 'currentProfile'),
              ),
            ]);
          },
        );
      });

      group('username claim error', () {
        blocTest<ProfileEditorBloc, ProfileEditorState>(
          'emits [loading, failure] with claimFailed error',
          setUp: () {
            final existingProfile = createTestProfile(
              nip05: 'original@example.com',
            );
            when(
              () => mockProfileRepository.getCachedProfile(pubkey: testPubkey),
            ).thenAnswer((_) async => existingProfile);
            when(
              () => mockProfileRepository.saveProfileEvent(
                displayName: testDisplayName,
                about: testAbout,
                username: testUsername,
                picture: testPicture,
                currentProfile: existingProfile,
              ),
            ).thenAnswer((_) async => createTestProfile());
            when(
              () => mockProfileRepository.claimUsername(username: testUsername),
            ).thenAnswer(
              (_) async => const UsernameClaimError('Server unavailable'),
            );
            when(
              () => mockProfileRepository.saveProfileEvent(
                displayName: testDisplayName,
                about: testAbout,
                picture: testPicture,
                currentProfile: existingProfile,
              ),
            ).thenAnswer((_) async => createTestProfile());
          },
          build: createBloc,
          act: (bloc) => bloc.add(
            const ProfileSaved(
              pubkey: testPubkey,
              displayName: testDisplayName,
              about: testAbout,
              picture: testPicture,
              username: testUsername,
            ),
          ),
          expect: () => [
            isA<ProfileEditorState>().having(
              (s) => s.status,
              'status',
              ProfileEditorStatus.loading,
            ),
            isA<ProfileEditorState>()
                .having((s) => s.status, 'status', ProfileEditorStatus.failure)
                .having(
                  (s) => s.error,
                  'error',
                  ProfileEditorError.claimFailed,
                ),
          ],
        );
      });

      group('rollback failure', () {
        blocTest<ProfileEditorBloc, ProfileEditorState>(
          'still returns correct error when rollback fails',
          setUp: () {
            final existingProfile = createTestProfile(
              nip05: 'original@example.com',
            );
            when(
              () => mockProfileRepository.getCachedProfile(pubkey: testPubkey),
            ).thenAnswer((_) async => existingProfile);
            when(
              () => mockProfileRepository.saveProfileEvent(
                displayName: testDisplayName,
                about: testAbout,
                username: testUsername,
                picture: testPicture,
                currentProfile: existingProfile,
              ),
            ).thenAnswer((_) async => createTestProfile());
            when(
              () => mockProfileRepository.claimUsername(username: testUsername),
            ).thenAnswer((_) async => const UsernameClaimTaken());
            when(
              () => mockProfileRepository.saveProfileEvent(
                displayName: testDisplayName,
                about: testAbout,
                picture: testPicture,
                currentProfile: existingProfile,
              ),
            ).thenThrow(const ProfilePublishFailedException('Rollback failed'));
          },
          build: createBloc,
          act: (bloc) => bloc.add(
            const ProfileSaved(
              pubkey: testPubkey,
              displayName: testDisplayName,
              about: testAbout,
              picture: testPicture,
              username: testUsername,
            ),
          ),
          expect: () => [
            isA<ProfileEditorState>().having(
              (s) => s.status,
              'status',
              ProfileEditorStatus.loading,
            ),
            isA<ProfileEditorState>()
                .having((s) => s.status, 'status', ProfileEditorStatus.failure)
                .having(
                  (s) => s.error,
                  'error',
                  ProfileEditorError.usernameTaken,
                ),
          ],
        );
      });
    });

    group('InitialUsernameSet', () {
      blocTest<ProfileEditorBloc, ProfileEditorState>(
        'stores initial username in state',
        build: createBloc,
        act: (bloc) => bloc.add(const InitialUsernameSet('alice')),
        expect: () => [
          isA<ProfileEditorState>().having(
            (s) => s.initialUsername,
            'initialUsername',
            'alice',
          ),
        ],
      );
    });

    group('UsernameChanged', () {
      // Debounce duration used in the BLoC (500ms) + buffer
      const debounceDuration = Duration(milliseconds: 600);

      blocTest<ProfileEditorBloc, ProfileEditorState>(
        'emits idle status when username is empty',
        build: createBloc,
        act: (bloc) => bloc.add(const UsernameChanged('')),
        wait: debounceDuration,
        expect: () => [
          isA<ProfileEditorState>()
              .having((s) => s.username, 'username', '')
              .having(
                (s) => s.usernameStatus,
                'usernameStatus',
                UsernameStatus.idle,
              ),
        ],
      );

      blocTest<ProfileEditorBloc, ProfileEditorState>(
        'emits error status for username too short',
        build: createBloc,
        act: (bloc) => bloc.add(const UsernameChanged('ab')),
        wait: debounceDuration,
        expect: () => [
          isA<ProfileEditorState>()
              .having((s) => s.username, 'username', 'ab')
              .having(
                (s) => s.usernameStatus,
                'usernameStatus',
                UsernameStatus.error,
              )
              .having(
                (s) => s.usernameError,
                'usernameError',
                equals(UsernameValidationError.invalidLength),
              ),
        ],
      );

      blocTest<ProfileEditorBloc, ProfileEditorState>(
        'emits error status for username too long',
        build: createBloc,
        act: (bloc) => bloc.add(const UsernameChanged('aaaaaaaaaaaaaaaaaaaaa')),
        wait: debounceDuration,
        expect: () => [
          isA<ProfileEditorState>()
              .having((s) => s.username, 'username', 'aaaaaaaaaaaaaaaaaaaaa')
              .having(
                (s) => s.usernameStatus,
                'usernameStatus',
                UsernameStatus.error,
              )
              .having(
                (s) => s.usernameError,
                'usernameError',
                equals(UsernameValidationError.invalidLength),
              ),
        ],
      );

      blocTest<ProfileEditorBloc, ProfileEditorState>(
        'emits error status for invalid characters',
        build: createBloc,
        act: (bloc) => bloc.add(const UsernameChanged('test@user')),
        wait: debounceDuration,
        expect: () => [
          isA<ProfileEditorState>()
              .having((s) => s.username, 'username', 'test@user')
              .having(
                (s) => s.usernameStatus,
                'usernameStatus',
                UsernameStatus.error,
              )
              .having(
                (s) => s.usernameError,
                'usernameError',
                equals(UsernameValidationError.invalidFormat),
              ),
        ],
      );

      blocTest<ProfileEditorBloc, ProfileEditorState>(
        'emits [checking, available] when username is available',
        setUp: () {
          when(
            () => mockProfileRepository.checkUsernameAvailability(
              username: testUsername,
            ),
          ).thenAnswer((_) async => const UsernameAvailable());
        },
        build: createBloc,
        act: (bloc) => bloc.add(const UsernameChanged(testUsername)),
        wait: debounceDuration,
        expect: () => [
          isA<ProfileEditorState>()
              .having((s) => s.username, 'username', testUsername)
              .having(
                (s) => s.usernameStatus,
                'usernameStatus',
                UsernameStatus.checking,
              ),
          isA<ProfileEditorState>()
              .having((s) => s.username, 'username', testUsername)
              .having(
                (s) => s.usernameStatus,
                'usernameStatus',
                UsernameStatus.available,
              ),
        ],
        verify: (_) {
          verify(
            () => mockProfileRepository.checkUsernameAvailability(
              username: testUsername,
            ),
          ).called(1);
        },
      );

      blocTest<ProfileEditorBloc, ProfileEditorState>(
        'emits [checking, taken] when username is taken',
        setUp: () {
          when(
            () => mockProfileRepository.checkUsernameAvailability(
              username: testUsername,
            ),
          ).thenAnswer((_) async => const UsernameTaken());
        },
        build: createBloc,
        act: (bloc) => bloc.add(const UsernameChanged(testUsername)),
        wait: debounceDuration,
        expect: () => [
          isA<ProfileEditorState>()
              .having((s) => s.username, 'username', testUsername)
              .having(
                (s) => s.usernameStatus,
                'usernameStatus',
                UsernameStatus.checking,
              ),
          isA<ProfileEditorState>()
              .having((s) => s.username, 'username', testUsername)
              .having(
                (s) => s.usernameStatus,
                'usernameStatus',
                UsernameStatus.taken,
              ),
        ],
      );

      blocTest<ProfileEditorBloc, ProfileEditorState>(
        'emits [checking, error] when check fails',
        setUp: () {
          when(
            () => mockProfileRepository.checkUsernameAvailability(
              username: testUsername,
            ),
          ).thenAnswer((_) async => const UsernameCheckError('Network error'));
        },
        build: createBloc,
        act: (bloc) => bloc.add(const UsernameChanged(testUsername)),
        wait: debounceDuration,
        expect: () => [
          isA<ProfileEditorState>()
              .having((s) => s.username, 'username', testUsername)
              .having(
                (s) => s.usernameStatus,
                'usernameStatus',
                UsernameStatus.checking,
              ),
          isA<ProfileEditorState>()
              .having((s) => s.username, 'username', testUsername)
              .having(
                (s) => s.usernameStatus,
                'usernameStatus',
                UsernameStatus.error,
              )
              .having(
                (s) => s.usernameError,
                'usernameError',
                equals(UsernameValidationError.networkError),
              ),
        ],
      );

      blocTest<ProfileEditorBloc, ProfileEditorState>(
        'debounces rapid username changes',
        setUp: () {
          when(
            () => mockProfileRepository.checkUsernameAvailability(
              username: any(named: 'username'),
            ),
          ).thenAnswer((_) async => const UsernameAvailable());
        },
        build: createBloc,
        act: (bloc) async {
          bloc.add(const UsernameChanged('test1'));
          await Future<void>.delayed(const Duration(milliseconds: 100));
          bloc.add(const UsernameChanged('test2'));
          await Future<void>.delayed(const Duration(milliseconds: 100));
          bloc.add(const UsernameChanged('test3'));
        },
        wait: debounceDuration,
        verify: (_) {
          // Should only call API once for the final username due to restartable transformer
          verify(
            () => mockProfileRepository.checkUsernameAvailability(
              username: 'test3',
            ),
          ).called(1);
          verifyNever(
            () => mockProfileRepository.checkUsernameAvailability(
              username: 'test1',
            ),
          );
          verifyNever(
            () => mockProfileRepository.checkUsernameAvailability(
              username: 'test2',
            ),
          );
        },
      );

      blocTest<ProfileEditorBloc, ProfileEditorState>(
        'skips API check when username matches initial username',
        build: createBloc,
        act: (bloc) async {
          bloc.add(const InitialUsernameSet(testUsername));
          await Future<void>.delayed(Duration.zero);
          bloc.add(const UsernameChanged(testUsername));
        },
        wait: debounceDuration,
        expect: () => [
          isA<ProfileEditorState>().having(
            (s) => s.initialUsername,
            'initialUsername',
            testUsername,
          ),
          isA<ProfileEditorState>()
              .having((s) => s.username, 'username', testUsername)
              .having(
                (s) => s.usernameStatus,
                'usernameStatus',
                UsernameStatus.idle,
              ),
        ],
        verify: (_) {
          verifyNever(
            () => mockProfileRepository.checkUsernameAvailability(
              username: any(named: 'username'),
            ),
          );
        },
      );

      blocTest<ProfileEditorBloc, ProfileEditorState>(
        'checks reserved cache before making API call',
        setUp: () {
          // First, trigger a ProfileSaved that returns UsernameClaimReserved
          final existingProfile = createTestProfile(
            nip05: 'original@example.com',
          );
          when(
            () => mockProfileRepository.getCachedProfile(pubkey: testPubkey),
          ).thenAnswer((_) async => existingProfile);
          when(
            () => mockProfileRepository.saveProfileEvent(
              displayName: testDisplayName,
              about: testAbout,
              username: testUsername,
              picture: testPicture,
              currentProfile: existingProfile,
            ),
          ).thenAnswer((_) async => createTestProfile());
          when(
            () => mockProfileRepository.claimUsername(username: testUsername),
          ).thenAnswer((_) async => const UsernameClaimReserved());
          when(
            () => mockProfileRepository.saveProfileEvent(
              displayName: testDisplayName,
              about: testAbout,
              picture: testPicture,
              currentProfile: existingProfile,
            ),
          ).thenAnswer((_) async => createTestProfile());
        },
        build: createBloc,
        act: (bloc) async {
          // First save profile with reserved username to populate cache
          bloc.add(
            const ProfileSaved(
              pubkey: testPubkey,
              displayName: testDisplayName,
              about: testAbout,
              picture: testPicture,
              username: testUsername,
            ),
          );
          await Future<void>.delayed(const Duration(milliseconds: 100));
          // Now check username again - should use cache
          bloc.add(const UsernameChanged(testUsername));
        },
        wait: debounceDuration,
        verify: (_) {
          // Should not call checkUsernameAvailability since it's in reserved cache
          verifyNever(
            () => mockProfileRepository.checkUsernameAvailability(
              username: testUsername,
            ),
          );
        },
        expect: () => containsAll([
          isA<ProfileEditorState>()
              .having((s) => s.username, 'username', testUsername)
              .having(
                (s) => s.usernameStatus,
                'usernameStatus',
                UsernameStatus.reserved,
              ),
        ]),
      );
    });

    group('Nip05ModeChanged', () {
      blocTest<ProfileEditorBloc, ProfileEditorState>(
        'switches to external mode and resets username status',
        build: createBloc,
        act: (bloc) => bloc.add(const Nip05ModeChanged(Nip05Mode.external_)),
        expect: () => [
          isA<ProfileEditorState>()
              .having((s) => s.nip05Mode, 'nip05Mode', Nip05Mode.external_)
              .having(
                (s) => s.usernameStatus,
                'usernameStatus',
                UsernameStatus.idle,
              ),
        ],
      );

      blocTest<ProfileEditorBloc, ProfileEditorState>(
        'switches to divine mode and clears external NIP-05 state',
        build: createBloc,
        seed: () => const ProfileEditorState(
          nip05Mode: Nip05Mode.external_,
          externalNip05: 'alice@example.com',
        ),
        act: (bloc) => bloc.add(const Nip05ModeChanged(Nip05Mode.divine)),
        expect: () => [
          isA<ProfileEditorState>()
              .having((s) => s.nip05Mode, 'nip05Mode', Nip05Mode.divine)
              .having((s) => s.externalNip05, 'externalNip05', ''),
        ],
      );
    });

    group('ExternalNip05Changed', () {
      blocTest<ProfileEditorBloc, ProfileEditorState>(
        'accepts valid external NIP-05 format',
        build: createBloc,
        act: (bloc) =>
            bloc.add(const ExternalNip05Changed('alice@example.com')),
        expect: () => [
          isA<ProfileEditorState>()
              .having(
                (s) => s.externalNip05,
                'externalNip05',
                'alice@example.com',
              )
              .having(
                (s) => s.externalNip05Error,
                'externalNip05Error',
                isNull,
              ),
        ],
      );

      blocTest<ProfileEditorBloc, ProfileEditorState>(
        'rejects invalid format without @ symbol',
        build: createBloc,
        act: (bloc) => bloc.add(const ExternalNip05Changed('invalidemail')),
        expect: () => [
          isA<ProfileEditorState>()
              .having((s) => s.externalNip05, 'externalNip05', 'invalidemail')
              .having(
                (s) => s.externalNip05Error,
                'externalNip05Error',
                ExternalNip05ValidationError.invalidFormat,
              ),
        ],
      );

      blocTest<ProfileEditorBloc, ProfileEditorState>(
        'clears error when input is empty',
        build: createBloc,
        seed: () => const ProfileEditorState(
          externalNip05: 'invalid',
          externalNip05Error: ExternalNip05ValidationError.invalidFormat,
        ),
        act: (bloc) => bloc.add(const ExternalNip05Changed('')),
        expect: () => [
          isA<ProfileEditorState>()
              .having((s) => s.externalNip05, 'externalNip05', '')
              .having(
                (s) => s.externalNip05Error,
                'externalNip05Error',
                isNull,
              ),
        ],
      );

      blocTest<ProfileEditorBloc, ProfileEditorState>(
        'normalizes to lowercase',
        build: createBloc,
        act: (bloc) =>
            bloc.add(const ExternalNip05Changed('Alice@Example.COM')),
        expect: () => [
          isA<ProfileEditorState>().having(
            (s) => s.externalNip05,
            'externalNip05',
            'alice@example.com',
          ),
        ],
      );

      blocTest<ProfileEditorBloc, ProfileEditorState>(
        'rejects divine.video domain',
        build: createBloc,
        act: (bloc) =>
            bloc.add(const ExternalNip05Changed('_@user.divine.video')),
        expect: () => [
          isA<ProfileEditorState>()
              .having(
                (s) => s.externalNip05,
                'externalNip05',
                '_@user.divine.video',
              )
              .having(
                (s) => s.externalNip05Error,
                'externalNip05Error',
                ExternalNip05ValidationError.divineDomain,
              ),
        ],
      );

      blocTest<ProfileEditorBloc, ProfileEditorState>(
        'rejects openvine.co domain',
        build: createBloc,
        act: (bloc) => bloc.add(const ExternalNip05Changed('user@openvine.co')),
        expect: () => [
          isA<ProfileEditorState>()
              .having(
                (s) => s.externalNip05,
                'externalNip05',
                'user@openvine.co',
              )
              .having(
                (s) => s.externalNip05Error,
                'externalNip05Error',
                ExternalNip05ValidationError.divineDomain,
              ),
        ],
      );
    });

    group('InitialExternalNip05Set', () {
      blocTest<ProfileEditorBloc, ProfileEditorState>(
        'stores initial external NIP-05 in state',
        build: createBloc,
        act: (bloc) =>
            bloc.add(const InitialExternalNip05Set('alice@example.com')),
        expect: () => [
          isA<ProfileEditorState>().having(
            (s) => s.initialExternalNip05,
            'initialExternalNip05',
            'alice@example.com',
          ),
        ],
      );
    });

    group('ProfileSaved with external NIP-05', () {
      blocTest<ProfileEditorBloc, ProfileEditorState>(
        'emits [loading, success] when saving with external NIP-05',
        setUp: () {
          when(
            () => mockProfileRepository.getCachedProfile(pubkey: testPubkey),
          ).thenAnswer((_) async => null);
          when(
            () => mockProfileRepository.saveProfileEvent(
              displayName: testDisplayName,
              about: testAbout,
              nip05: 'alice@example.com',
              picture: testPicture,
            ),
          ).thenAnswer((_) async => createTestProfile());
        },
        build: createBloc,
        seed: () => const ProfileEditorState(nip05Mode: Nip05Mode.external_),
        act: (bloc) => bloc.add(
          const ProfileSaved(
            pubkey: testPubkey,
            displayName: testDisplayName,
            about: testAbout,
            picture: testPicture,
            externalNip05: 'alice@example.com',
          ),
        ),
        expect: () => [
          isA<ProfileEditorState>().having(
            (s) => s.status,
            'status',
            ProfileEditorStatus.loading,
          ),
          isA<ProfileEditorState>().having(
            (s) => s.status,
            'status',
            ProfileEditorStatus.success,
          ),
        ],
        verify: (_) {
          verify(
            () => mockProfileRepository.saveProfileEvent(
              displayName: testDisplayName,
              about: testAbout,
              nip05: 'alice@example.com',
              picture: testPicture,
            ),
          ).called(1);
          verifyNever(
            () => mockProfileRepository.claimUsername(
              username: any(named: 'username'),
            ),
          );
        },
      );

      blocTest<ProfileEditorBloc, ProfileEditorState>(
        'drops username and skips claim when both username and '
        'externalNip05 are sent in external mode',
        setUp: () {
          when(
            () => mockProfileRepository.getCachedProfile(pubkey: testPubkey),
          ).thenAnswer((_) async => null);
          when(
            () => mockProfileRepository.saveProfileEvent(
              displayName: testDisplayName,
              about: testAbout,
              nip05: 'alice@example.com',
              picture: testPicture,
            ),
          ).thenAnswer((_) async => createTestProfile());
        },
        build: createBloc,
        seed: () => const ProfileEditorState(nip05Mode: Nip05Mode.external_),
        act: (bloc) => bloc.add(
          const ProfileSaved(
            pubkey: testPubkey,
            displayName: testDisplayName,
            about: testAbout,
            picture: testPicture,
            username: testUsername,
            externalNip05: 'alice@example.com',
          ),
        ),
        expect: () => [
          isA<ProfileEditorState>().having(
            (s) => s.status,
            'status',
            ProfileEditorStatus.loading,
          ),
          isA<ProfileEditorState>().having(
            (s) => s.status,
            'status',
            ProfileEditorStatus.success,
          ),
        ],
        verify: (_) {
          // Username should be dropped — saveProfileEvent called without it
          verify(
            () => mockProfileRepository.saveProfileEvent(
              displayName: testDisplayName,
              about: testAbout,
              nip05: 'alice@example.com',
              picture: testPicture,
            ),
          ).called(1);
          // No username claim should be attempted
          verifyNever(
            () => mockProfileRepository.claimUsername(
              username: any(named: 'username'),
            ),
          );
        },
      );
    });

    group('isUsernameSaveReady', () {
      test('returns true when username is empty', () {
        const state = ProfileEditorState();
        expect(state.isUsernameSaveReady, isTrue);
      });

      test('returns true when username is available', () {
        const state = ProfileEditorState(
          username: 'newuser',
          usernameStatus: UsernameStatus.available,
        );
        expect(state.isUsernameSaveReady, isTrue);
      });

      test('returns false when checking availability', () {
        const state = ProfileEditorState(
          username: 'newuser',
          usernameStatus: UsernameStatus.checking,
        );
        expect(state.isUsernameSaveReady, isFalse);
      });

      test('returns true when username matches initial (same case)', () {
        const state = ProfileEditorState(
          username: 'alice',
          initialUsername: 'alice',
        );
        expect(state.isUsernameSaveReady, isTrue);
      });

      test('returns true when username matches initial (different case)', () {
        const state = ProfileEditorState(
          username: 'Alice',
          initialUsername: 'alice',
        );
        expect(state.isUsernameSaveReady, isTrue);
      });

      test('returns false when username is taken', () {
        const state = ProfileEditorState(
          username: 'taken',
          usernameStatus: UsernameStatus.taken,
        );
        expect(state.isUsernameSaveReady, isFalse);
      });

      test('returns false when username has validation error', () {
        const state = ProfileEditorState(
          username: 'bad!',
          usernameStatus: UsernameStatus.error,
          usernameError: UsernameValidationError.invalidFormat,
        );
        expect(state.isUsernameSaveReady, isFalse);
      });

      test('returns false when no initial username and status is idle', () {
        const state = ProfileEditorState(
          username: 'someuser',
        );
        expect(state.isUsernameSaveReady, isFalse);
      });
    });

    group('isExternalNip05SaveReady', () {
      test('returns true when external NIP-05 is empty', () {
        const state = ProfileEditorState(nip05Mode: Nip05Mode.external_);
        expect(state.isExternalNip05SaveReady, isTrue);
      });

      test('returns true when external NIP-05 is valid', () {
        const state = ProfileEditorState(
          nip05Mode: Nip05Mode.external_,
          externalNip05: 'alice@example.com',
        );
        expect(state.isExternalNip05SaveReady, isTrue);
      });

      test('returns false when external NIP-05 has format error', () {
        const state = ProfileEditorState(
          nip05Mode: Nip05Mode.external_,
          externalNip05: 'invalid',
          externalNip05Error: ExternalNip05ValidationError.invalidFormat,
        );
        expect(state.isExternalNip05SaveReady, isFalse);
      });
    });

    group('isSaveReady', () {
      test('delegates to isUsernameSaveReady in divine mode', () {
        const state = ProfileEditorState(
          username: 'alice',
          usernameStatus: UsernameStatus.available,
        );
        expect(state.isSaveReady, isTrue);
      });

      test('delegates to isExternalNip05SaveReady in external mode', () {
        const state = ProfileEditorState(
          nip05Mode: Nip05Mode.external_,
          externalNip05: 'alice@example.com',
        );
        expect(state.isSaveReady, isTrue);
      });

      test('returns false in external mode with invalid NIP-05', () {
        const state = ProfileEditorState(
          nip05Mode: Nip05Mode.external_,
          externalNip05: 'invalid',
          externalNip05Error: ExternalNip05ValidationError.invalidFormat,
        );
        expect(state.isSaveReady, isFalse);
      });
    });
  });
}
