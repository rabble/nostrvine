// ABOUTME: Unit tests for ProfileEditorBloc
// ABOUTME: Tests profile publishing and username claiming with rollback on failure

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/profile_editor/profile_editor_bloc.dart';
import 'package:openvine/models/user_profile.dart' as app_models;
import 'package:openvine/repositories/username_repository.dart';
import 'package:openvine/services/user_profile_service.dart';
import 'package:profile_repository/profile_repository.dart';

class _MockUsernameRepository extends Mock implements UsernameRepository {}

class _MockProfileRepository extends Mock implements ProfileRepository {}

class _MockUserProfileService extends Mock implements UserProfileService {}

void main() {
  group('ProfileEditorBloc', () {
    late _MockUsernameRepository mockUsernameRepository;
    late _MockProfileRepository mockProfileRepository;
    late _MockUserProfileService mockUserProfileService;

    // Test data constants - using full 64-character hex pubkey as required
    const testPubkey =
        'a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2';
    const testDisplayName = 'Test User';
    const testAbout = 'Test bio';
    const testUsername = 'testuser';
    const testPicture = 'https://example.com/avatar.png';
    const testNip05 = '$testUsername@divine.video';
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
      mockUsernameRepository = _MockUsernameRepository();
      mockProfileRepository = _MockProfileRepository();
      mockUserProfileService = _MockUserProfileService();

      when(
        () => mockUserProfileService.updateCachedProfile(any()),
      ).thenAnswer((_) async {});
    });

    ProfileEditorBloc createBloc() => ProfileEditorBloc(
      profileRepository: mockProfileRepository,
      usernameRepository: mockUsernameRepository,
      userProfileService: mockUserProfileService,
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
              () => mockUsernameRepository.register(
                username: any(named: 'username'),
                pubkey: any(named: 'pubkey'),
              ),
            );
          },
        );

        blocTest<ProfileEditorBloc, ProfileEditorState>(
          'publishes profile with existing profile data',
          setUp: () {
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
              () => mockUsernameRepository.register(
                username: testUsername,
                pubkey: testPubkey,
              ),
            ).called(1);
          },
        );
      });

      group('profile publish failure', () {
        blocTest<ProfileEditorBloc, ProfileEditorState>(
          'emits [loading, failure] with publishFailed error',
          setUp: () {
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
              () => mockUsernameRepository.register(
                username: any(named: 'username'),
                pubkey: any(named: 'pubkey'),
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
          'emits [loading, failure] with publishFailed error',
          setUp: () {
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
                  ProfileEditorError.publishFailed,
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
  });
}
