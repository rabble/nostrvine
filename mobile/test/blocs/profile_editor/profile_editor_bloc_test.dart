// ABOUTME: Unit tests for ProfileEditorBloc
// ABOUTME: Tests profile publishing and username claiming with rollback on failure

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/profile_editor/profile_editor_bloc.dart';
import 'package:openvine/models/user_profile.dart' as app_models;
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
    const testNip05 = '_@$testUsername.divine.video';
    const testOriginalNip05 = 'original@example.com';

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
                nip05: null,
                picture: testPicture,
                currentProfile: null,
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
                nip05: null,
                picture: testPicture,
                currentProfile: null,
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
            final existingProfile = createTestProfile(nip05: testOriginalNip05);
            when(
              () => mockProfileRepository.getCachedProfile(pubkey: testPubkey),
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
          'publishes profile with null nip05 when username is empty string',
          setUp: () {
            when(
              () => mockProfileRepository.getCachedProfile(pubkey: testPubkey),
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
                nip05: null,
                picture: testPicture,
                currentProfile: null,
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
                nip05: testNip05,
                picture: testPicture,
                currentProfile: null,
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
                nip05: testNip05,
                picture: testPicture,
                currentProfile: null,
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
                nip05: null,
                picture: testPicture,
                currentProfile: null,
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
                nip05: testNip05,
                picture: testPicture,
                currentProfile: null,
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
            final existingProfile = createTestProfile(nip05: testOriginalNip05);
            when(
              () => mockProfileRepository.getCachedProfile(pubkey: testPubkey),
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
              () => mockProfileRepository.claimUsername(username: testUsername),
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
          'rolls back profile with original nip05',
          setUp: () {
            final existingProfile = createTestProfile(nip05: testOriginalNip05);
            when(
              () => mockProfileRepository.getCachedProfile(pubkey: testPubkey),
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
              () => mockProfileRepository.claimUsername(username: testUsername),
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
                nip05: testNip05,
                picture: testPicture,
                currentProfile: any(named: 'currentProfile'),
              ),
              () => mockProfileRepository.saveProfileEvent(
                displayName: testDisplayName,
                about: testAbout,
                nip05: testOriginalNip05,
                picture: testPicture,
                currentProfile: any(named: 'currentProfile'),
              ),
            ]);
          },
        );

        blocTest<ProfileEditorBloc, ProfileEditorState>(
          'rolls back to null nip05 when no existing profile',
          setUp: () {
            when(
              () => mockProfileRepository.getCachedProfile(pubkey: testPubkey),
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
              () => mockProfileRepository.claimUsername(username: testUsername),
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
          },
        );
      });

      group('username reserved', () {
        blocTest<ProfileEditorBloc, ProfileEditorState>(
          'emits [loading, failure] with usernameReserved error',
          setUp: () {
            final existingProfile = createTestProfile(nip05: testOriginalNip05);
            when(
              () => mockProfileRepository.getCachedProfile(pubkey: testPubkey),
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
              () => mockProfileRepository.claimUsername(username: testUsername),
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
            final existingProfile = createTestProfile(nip05: testOriginalNip05);
            when(
              () => mockProfileRepository.getCachedProfile(pubkey: testPubkey),
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
              () => mockProfileRepository.claimUsername(username: testUsername),
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
                nip05: testNip05,
                picture: testPicture,
                currentProfile: any(named: 'currentProfile'),
              ),
              () => mockProfileRepository.saveProfileEvent(
                displayName: testDisplayName,
                about: testAbout,
                nip05: testOriginalNip05,
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
            final existingProfile = createTestProfile(nip05: testOriginalNip05);
            when(
              () => mockProfileRepository.getCachedProfile(pubkey: testPubkey),
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
              () => mockProfileRepository.claimUsername(username: testUsername),
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
            final existingProfile = createTestProfile(nip05: testOriginalNip05);
            when(
              () => mockProfileRepository.getCachedProfile(pubkey: testPubkey),
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
              () => mockProfileRepository.claimUsername(username: testUsername),
            ).thenAnswer((_) async => const UsernameClaimTaken());
            when(
              () => mockProfileRepository.saveProfileEvent(
                displayName: testDisplayName,
                about: testAbout,
                nip05: testOriginalNip05,
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
        'checks reserved cache before making API call',
        setUp: () {
          // First, trigger a ProfileSaved that returns UsernameClaimReserved
          final existingProfile = createTestProfile(nip05: testOriginalNip05);
          when(
            () => mockProfileRepository.getCachedProfile(pubkey: testPubkey),
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
            () => mockProfileRepository.claimUsername(username: testUsername),
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
  });
}
