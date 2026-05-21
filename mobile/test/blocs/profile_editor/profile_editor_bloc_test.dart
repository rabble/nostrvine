// ABOUTME: Unit tests for ProfileEditorBloc
// ABOUTME: Asserts claim-before-publish ordering — kind 0 must never be
// ABOUTME: broadcast unless the username claim succeeded first. Also
// ABOUTME: covers the staged-avatar contract: upload stages, save persists,
// ABOUTME: failure preserves the prior preview, no publish on upload alone.

import 'dart:io';
import 'dart:typed_data';

import 'package:bloc_test/bloc_test.dart';
import 'package:blossom_upload_service/blossom_upload_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/profile_editor/profile_editor_bloc.dart';
import 'package:openvine/observability/reportable_error.dart';
import 'package:openvine/services/mention_resolution_service.dart';
import 'package:openvine/utils/nostr_key_utils.dart';
import 'package:profile_repository/profile_repository.dart';

class _MockProfileRepository extends Mock implements ProfileRepository {}

class _MockBlossomUploadService extends Mock implements BlossomUploadService {}

class _MockMentionResolutionService extends Mock
    implements MentionResolutionService {}

class _FakeFile extends Fake implements File {}

void main() {
  group('ProfileEditorBloc', () {
    late _MockProfileRepository mockProfileRepository;

    // Test data constants - using full 64-character hex pubkey as required
    const testPubkey =
        'a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2';
    const testDisplayName = 'Test User';
    const testAbout = 'Test bio';
    const testUsername = 'testuser';
    const testPicture = 'https://example.com/avatar.png';
    const alicePubkey =
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

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

    late _MockBlossomUploadService mockBlossomUploadService;
    late _MockMentionResolutionService mockMentionResolutionService;

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
      registerFallbackValue(_FakeFile());
      registerFallbackValue(Uint8List(0));
    });

    setUp(() {
      mockProfileRepository = _MockProfileRepository();
      mockBlossomUploadService = _MockBlossomUploadService();
      mockMentionResolutionService = _MockMentionResolutionService();
      when(
        () => mockProfileRepository.cacheProfile(any()),
      ).thenAnswer((_) async {});
    });

    ProfileEditorBloc createBloc({
      bool hasExistingProfile = true,
      MentionResolutionService? mentionResolutionService,
    }) => ProfileEditorBloc(
      profileRepository: mockProfileRepository,
      blossomUploadService: mockBlossomUploadService,
      hasExistingProfile: hasExistingProfile,
      mentionResolutionService: mentionResolutionService,
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
                clearNip05: any(named: 'clearNip05'),
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
                clearNip05: any(named: 'clearNip05'),
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
                clearNip05: any(named: 'clearNip05'),
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
                clearNip05: any(named: 'clearNip05'),
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
                clearNip05: any(named: 'clearNip05'),
              ),
            ).called(1);
          },
        );

        blocTest<ProfileEditorBloc, ProfileEditorState>(
          'passes clearNip05: false when no username and initialUsername is null '
          '(profile not loaded — must not destroy an unloaded NIP-05)',
          setUp: () {
            when(
              () => mockProfileRepository.getCachedProfile(pubkey: testPubkey),
            ).thenAnswer((_) async => null);
            when(
              () => mockProfileRepository.saveProfileEvent(
                displayName: testDisplayName,
                about: testAbout,
                picture: testPicture,
                clearNip05: any(named: 'clearNip05'),
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
          verify: (_) {
            verify(
              () => mockProfileRepository.saveProfileEvent(
                displayName: testDisplayName,
                about: testAbout,
                picture: testPicture,
                clearNip05: any(named: 'clearNip05', that: isFalse),
              ),
            ).called(1);
          },
        );

        blocTest<ProfileEditorBloc, ProfileEditorState>(
          'passes clearNip05: true when user explicitly removes a known username',
          setUp: () {
            when(
              () => mockProfileRepository.getCachedProfile(pubkey: testPubkey),
            ).thenAnswer((_) async => null);
            when(
              () => mockProfileRepository.saveProfileEvent(
                displayName: testDisplayName,
                about: testAbout,
                picture: testPicture,
                clearNip05: true,
              ),
            ).thenAnswer((_) async => createTestProfile());
          },
          build: createBloc,
          // Dispatch InitialUsernameSet first so the bloc knows the user had
          // 'testuser' — then saving with no username is an explicit removal.
          act: (bloc) async {
            bloc.add(const InitialUsernameSet(testUsername));
            await Future<void>.delayed(Duration.zero);
            bloc.add(
              const ProfileSaved(
                pubkey: testPubkey,
                displayName: testDisplayName,
                about: testAbout,
                picture: testPicture,
              ),
            );
          },
          verify: (_) {
            verify(
              () => mockProfileRepository.saveProfileEvent(
                displayName: testDisplayName,
                about: testAbout,
                picture: testPicture,
                clearNip05: true,
              ),
            ).called(1);
          },
        );

        blocTest<ProfileEditorBloc, ProfileEditorState>(
          'canonicalizes exact bio mentions before publishing profile metadata',
          setUp: () {
            final aliceNpub = NostrKeyUtils.encodePubKey(alicePubkey);
            when(
              () => mockProfileRepository.searchUsersLocally(
                query: 'alice',
                limit: any(named: 'limit'),
              ),
            ).thenAnswer(
              (_) async => [
                UserProfile(
                  pubkey: alicePubkey,
                  name: 'alice',
                  rawData: const {},
                  createdAt: DateTime.utc(2026),
                  eventId: 'event-$alicePubkey',
                ),
              ],
            );
            when(
              () => mockProfileRepository.getCachedProfile(pubkey: testPubkey),
            ).thenAnswer((_) async => null);
            when(
              () => mockProfileRepository.saveProfileEvent(
                displayName: testDisplayName,
                about: 'hi nostr:$aliceNpub',
                picture: testPicture,
                clearNip05: any(named: 'clearNip05'),
              ),
            ).thenAnswer((_) async => createTestProfile());
          },
          build: () => createBloc(
            mentionResolutionService: MentionResolutionService(
              profileRepository: mockProfileRepository,
            ),
          ),
          act: (bloc) => bloc.add(
            const ProfileSaved(
              pubkey: testPubkey,
              displayName: testDisplayName,
              about: 'hi @alice',
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
            final aliceNpub = NostrKeyUtils.encodePubKey(alicePubkey);
            verify(
              () => mockProfileRepository.saveProfileEvent(
                displayName: testDisplayName,
                about: 'hi nostr:$aliceNpub',
                picture: testPicture,
                clearNip05: any(named: 'clearNip05'),
              ),
            ).called(1);
          },
        );

        blocTest<ProfileEditorBloc, ProfileEditorState>(
          'preserves unresolved bio text when mention resolution fails',
          setUp: () {
            when(
              () => mockProfileRepository.searchUsersLocally(
                query: 'alice',
                limit: any(named: 'limit'),
              ),
            ).thenThrow(Exception('lookup unavailable'));
            when(
              () => mockProfileRepository.getCachedProfile(pubkey: testPubkey),
            ).thenAnswer((_) async => null);
            when(
              () => mockProfileRepository.saveProfileEvent(
                displayName: testDisplayName,
                about: 'hi @alice',
                picture: testPicture,
                clearNip05: any(named: 'clearNip05'),
              ),
            ).thenAnswer((_) async => createTestProfile());
          },
          build: () => createBloc(
            mentionResolutionService: MentionResolutionService(
              profileRepository: mockProfileRepository,
            ),
          ),
          act: (bloc) => bloc.add(
            const ProfileSaved(
              pubkey: testPubkey,
              displayName: testDisplayName,
              about: 'hi @alice',
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
                about: 'hi @alice',
                picture: testPicture,
                clearNip05: any(named: 'clearNip05'),
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
            // Claim must run before publish so kind 0 is only broadcast
            // after the registry confirms the name belongs to this pubkey.
            verifyInOrder([
              () => mockProfileRepository.claimUsername(username: testUsername),
              () => mockProfileRepository.saveProfileEvent(
                displayName: testDisplayName,
                about: testAbout,
                username: testUsername,
                picture: testPicture,
              ),
            ]);
          },
        );

        blocTest<ProfileEditorBloc, ProfileEditorState>(
          'publishes without claiming when username matches initialUsername',
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
          },
          seed: () => const ProfileEditorState(
            initialUsername: testUsername,
          ),
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
            verifyNever(
              () => mockProfileRepository.claimUsername(
                username: any(named: 'username'),
              ),
            );
            verify(
              () => mockProfileRepository.saveProfileEvent(
                displayName: testDisplayName,
                about: testAbout,
                username: testUsername,
                picture: testPicture,
              ),
            ).called(1);
          },
        );

        blocTest<ProfileEditorBloc, ProfileEditorState>(
          'supports admin-assigned username for current user through '
          'availability check then save/claim success',
          setUp: () {
            when(
              () => mockProfileRepository.checkUsernameAvailability(
                username: testUsername,
                currentUserPubkey: testPubkey,
              ),
            ).thenAnswer((_) async => const UsernameAvailable());
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
          build: () => ProfileEditorBloc(
            profileRepository: mockProfileRepository,
            blossomUploadService: mockBlossomUploadService,
            hasExistingProfile: true,
            currentUserPubkey: testPubkey,
          ),
          act: (bloc) async {
            bloc.add(const UsernameChanged(testUsername));
            await Future<void>.delayed(const Duration(milliseconds: 700));
            bloc.add(
              const ProfileSaved(
                pubkey: testPubkey,
                displayName: testDisplayName,
                about: testAbout,
                picture: testPicture,
                username: testUsername,
              ),
            );
          },
          wait: const Duration(milliseconds: 700),
          expect: () => [
            isA<ProfileEditorState>().having(
              (s) => s.usernameStatus,
              'usernameStatus',
              UsernameStatus.checking,
            ),
            isA<ProfileEditorState>().having(
              (s) => s.usernameStatus,
              'usernameStatus',
              UsernameStatus.available,
            ),
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
              () => mockProfileRepository.checkUsernameAvailability(
                username: testUsername,
                currentUserPubkey: testPubkey,
              ),
            ).called(1);
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
                clearNip05: any(named: 'clearNip05'),
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
          'still emits publishFailed when claim succeeds but publish fails',
          setUp: () {
            when(
              () => mockProfileRepository.getCachedProfile(pubkey: testPubkey),
            ).thenAnswer((_) async => null);
            when(
              () => mockProfileRepository.claimUsername(username: testUsername),
            ).thenAnswer((_) async => const UsernameClaimSuccess());
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
          verify: (_) {
            // Claim happens first; saveProfileEvent is then attempted and
            // throws. There is no rollback publish.
            verifyInOrder([
              () => mockProfileRepository.claimUsername(username: testUsername),
              () => mockProfileRepository.saveProfileEvent(
                displayName: testDisplayName,
                about: testAbout,
                username: testUsername,
                picture: testPicture,
              ),
            ]);
          },
        );
      });

      group('no relays connected', () {
        blocTest<ProfileEditorBloc, ProfileEditorState>(
          'emits [loading, failure] with noRelaysConnected error',
          setUp: () {
            when(
              () => mockProfileRepository.getCachedProfile(pubkey: testPubkey),
            ).thenAnswer((_) async => null);
            when(
              () => mockProfileRepository.saveProfileEvent(
                displayName: testDisplayName,
                about: testAbout,
                picture: testPicture,
                clearNip05: any(named: 'clearNip05'),
              ),
            ).thenThrow(const NoRelaysConnectedException('No relays'));
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
                  ProfileEditorError.noRelaysConnected,
                ),
          ],
          errors: () => [isA<NoRelaysConnectedException>()],
        );

        blocTest<ProfileEditorBloc, ProfileEditorState>(
          'still emits noRelaysConnected when claim succeeded but publish '
          'cannot reach any relay',
          setUp: () {
            when(
              () => mockProfileRepository.getCachedProfile(pubkey: testPubkey),
            ).thenAnswer((_) async => null);
            when(
              () => mockProfileRepository.claimUsername(username: testUsername),
            ).thenAnswer((_) async => const UsernameClaimSuccess());
            when(
              () => mockProfileRepository.saveProfileEvent(
                displayName: testDisplayName,
                about: testAbout,
                username: testUsername,
                picture: testPicture,
              ),
            ).thenThrow(const NoRelaysConnectedException('No relays'));
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
                  ProfileEditorError.noRelaysConnected,
                ),
          ],
          errors: () => [isA<NoRelaysConnectedException>()],
        );
      });

      // Regression: kind 0 metadata is gossiped to relays and effectively
      // immutable once broadcast. If we publish before confirming the username
      // claim, a single name-server hiccup leaves the user advertising a
      // _@<name>.divine.video identifier with no registry record. These tests
      // assert that saveProfileEvent is never called when the claim fails.
      group('claim failure does not broadcast kind 0', () {
        for (final scenario in [
          (
            label: 'username taken',
            result: const UsernameClaimTaken(),
            expectedError: ProfileEditorError.usernameTaken,
            expectedUsernameStatus: UsernameStatus.taken,
          ),
          (
            label: 'username reserved',
            result: const UsernameClaimReserved(),
            expectedError: ProfileEditorError.usernameReserved,
            expectedUsernameStatus: UsernameStatus.reserved,
          ),
          (
            label: 'name server error',
            result: const UsernameClaimError('Server unavailable'),
            expectedError: ProfileEditorError.claimFailed,
            expectedUsernameStatus: null,
          ),
        ]) {
          blocTest<ProfileEditorBloc, ProfileEditorState>(
            'emits failure and never calls saveProfileEvent on '
            '${scenario.label}',
            setUp: () {
              final existingProfile = createTestProfile(
                nip05: 'original@example.com',
              );
              when(
                () =>
                    mockProfileRepository.getCachedProfile(pubkey: testPubkey),
              ).thenAnswer((_) async => existingProfile);
              when(
                () =>
                    mockProfileRepository.claimUsername(username: testUsername),
              ).thenAnswer((_) async => scenario.result);
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
                  .having(
                    (s) => s.status,
                    'status',
                    ProfileEditorStatus.failure,
                  )
                  .having((s) => s.error, 'error', scenario.expectedError)
                  .having(
                    (s) => s.usernameStatus,
                    'usernameStatus',
                    scenario.expectedUsernameStatus ?? UsernameStatus.idle,
                  ),
            ],
            verify: (_) {
              verify(
                () =>
                    mockProfileRepository.claimUsername(username: testUsername),
              ).called(1);
              verifyNever(
                () => mockProfileRepository.saveProfileEvent(
                  displayName: any(named: 'displayName'),
                  about: any(named: 'about'),
                  username: any(named: 'username'),
                  nip05: any(named: 'nip05'),
                  clearNip05: any(named: 'clearNip05'),
                  picture: any(named: 'picture'),
                  banner: any(named: 'banner'),
                  currentProfile: any(named: 'currentProfile'),
                ),
              );
              verifyNever(() => mockProfileRepository.cacheProfile(any()));
            },
          );
        }

        blocTest<ProfileEditorBloc, ProfileEditorState>(
          'records reserved username in state for re-check support',
          setUp: () {
            when(
              () => mockProfileRepository.getCachedProfile(pubkey: testPubkey),
            ).thenAnswer((_) async => null);
            when(
              () => mockProfileRepository.claimUsername(username: testUsername),
            ).thenAnswer((_) async => const UsernameClaimReserved());
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
                  (s) => s.reservedUsernames,
                  'reservedUsernames',
                  contains(testUsername),
                ),
          ],
        );
      });
    });

    // Defensive try/catch on the 5 handlers + narrowed publish branch +
    // mention-resolution wrap. Per .claude/rules/error_handling.md, only
    // `Error` subclasses (StateError, TypeError, RangeError) escape the
    // repository's `on Exception` filters; these tests pin that the bloc
    // now wraps them as `Reportable<T>` and still emits a sensible
    // status-enum failure value.
    group('handler-level invariant Reportable wraps', () {
      blocTest<ProfileEditorBloc, ProfileEditorState>(
        'wraps unexpected claimUsername Error in _onProfileSaved as '
        'Reportable and emits failure(publishFailed)',
        setUp: () {
          when(
            () => mockProfileRepository.getCachedProfile(pubkey: testPubkey),
          ).thenAnswer((_) async => null);
          when(
            () => mockProfileRepository.claimUsername(username: testUsername),
          ).thenThrow(StateError('claim invariant'));
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
        errors: () => [
          isA<Reportable<Object>>().having(
            (r) => r.unwrap(),
            'unwrap',
            isA<StateError>(),
          ),
        ],
        verify: (_) {
          // Claim threw — never reach the publish step.
          verifyNever(
            () => mockProfileRepository.saveProfileEvent(
              displayName: any(named: 'displayName'),
              about: any(named: 'about'),
              username: any(named: 'username'),
              clearNip05: any(named: 'clearNip05'),
              picture: any(named: 'picture'),
              banner: any(named: 'banner'),
              currentProfile: any(named: 'currentProfile'),
            ),
          );
        },
      );

      blocTest<ProfileEditorBloc, ProfileEditorState>(
        'wraps unexpected saveProfileEvent Error in narrowed publish catch '
        'as Reportable and emits failure(publishFailed)',
        setUp: () {
          when(
            () => mockProfileRepository.getCachedProfile(pubkey: testPubkey),
          ).thenAnswer((_) async => null);
          when(
            () => mockProfileRepository.saveProfileEvent(
              displayName: testDisplayName,
              about: testAbout,
              picture: testPicture,
              clearNip05: any(named: 'clearNip05'),
            ),
          ).thenThrow(StateError('publish invariant'));
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
        errors: () => [
          isA<Reportable<Object>>().having(
            (r) => r.unwrap(),
            'unwrap',
            isA<StateError>(),
          ),
        ],
      );

      blocTest<ProfileEditorBloc, ProfileEditorState>(
        'wraps unexpected Error in _onProfileNip05Saved as Reportable and '
        'emits failure(publishFailed)',
        setUp: () {
          when(
            () => mockProfileRepository.getCachedProfile(pubkey: testPubkey),
          ).thenAnswer((_) async => null);
          when(
            () => mockProfileRepository.saveProfileEvent(
              displayName: testDisplayName,
              about: testAbout,
              picture: testPicture,
              banner: any(named: 'banner'),
              clearNip05: any(named: 'clearNip05'),
            ),
          ).thenThrow(StateError('nip05 save invariant'));
        },
        build: createBloc,
        act: (bloc) => bloc.add(
          ProfileNip05Saved(
            currentProfile: UserProfile(
              pubkey: testPubkey,
              displayName: testDisplayName,
              about: testAbout,
              picture: testPicture,
              rawData: const {},
              createdAt: DateTime.now(),
              eventId:
                  'nip05evt567890123456789012345678901234567890123456789012345678',
            ),
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
        errors: () => [
          isA<Reportable<Object>>().having(
            (r) => r.unwrap(),
            'unwrap',
            isA<StateError>(),
          ),
        ],
      );

      blocTest<ProfileEditorBloc, ProfileEditorState>(
        'wraps unexpected Error in _onProfileSaveConfirmed as Reportable '
        'and emits failure(publishFailed)',
        setUp: () {
          when(
            () => mockProfileRepository.getCachedProfile(pubkey: testPubkey),
          ).thenAnswer((_) async => null);
          when(
            () => mockProfileRepository.saveProfileEvent(
              displayName: testDisplayName,
              clearNip05: any(named: 'clearNip05'),
            ),
          ).thenThrow(StateError('confirmed save invariant'));
        },
        build: () => createBloc(hasExistingProfile: false),
        seed: () => const ProfileEditorState(
          status: ProfileEditorStatus.confirmationRequired,
          pendingEvent: ProfileSaved(
            pubkey: testPubkey,
            displayName: testDisplayName,
          ),
        ),
        act: (bloc) => bloc.add(const ProfileSaveConfirmed()),
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
        errors: () => [
          isA<Reportable<Object>>().having(
            (r) => r.unwrap(),
            'unwrap',
            isA<StateError>(),
          ),
        ],
      );

      blocTest<ProfileEditorBloc, ProfileEditorState>(
        'wraps unexpected checkUsernameAvailability Error in '
        '_onUsernameChanged as Reportable and emits error(networkError)',
        setUp: () {
          when(
            () => mockProfileRepository.checkUsernameAvailability(
              username: testUsername,
              currentUserPubkey: any(named: 'currentUserPubkey'),
            ),
          ).thenThrow(StateError('availability check invariant'));
        },
        build: createBloc,
        act: (bloc) async {
          bloc.add(const UsernameChanged(testUsername));
          // Wait out the 500ms debounce + buffer
          await Future<void>.delayed(const Duration(milliseconds: 600));
        },
        wait: const Duration(milliseconds: 700),
        expect: () => [
          isA<ProfileEditorState>().having(
            (s) => s.usernameStatus,
            'usernameStatus',
            UsernameStatus.checking,
          ),
          isA<ProfileEditorState>()
              .having(
                (s) => s.usernameStatus,
                'usernameStatus',
                UsernameStatus.error,
              )
              .having(
                (s) => s.usernameError,
                'usernameError',
                UsernameValidationError.networkError,
              ),
        ],
        errors: () => [
          isA<Reportable<Object>>().having(
            (r) => r.unwrap(),
            'unwrap',
            isA<StateError>(),
          ),
        ],
      );

      blocTest<ProfileEditorBloc, ProfileEditorState>(
        'wraps unexpected checkUsernameAvailability Error in '
        '_onUsernameRechecked as Reportable and re-reserves the name',
        build: createBloc,
        seed: () => const ProfileEditorState(
          username: testUsername,
          usernameStatus: UsernameStatus.reserved,
          reservedUsernames: {testUsername},
        ),
        setUp: () {
          when(
            () => mockProfileRepository.checkUsernameAvailability(
              username: testUsername,
              currentUserPubkey: any(named: 'currentUserPubkey'),
            ),
          ).thenThrow(StateError('recheck invariant'));
        },
        act: (bloc) => bloc.add(const UsernameRechecked()),
        expect: () => [
          isA<ProfileEditorState>()
              .having(
                (s) => s.usernameStatus,
                'usernameStatus',
                UsernameStatus.checking,
              )
              .having(
                (s) => s.reservedUsernames,
                'reservedUsernames',
                isEmpty,
              ),
          isA<ProfileEditorState>()
              .having(
                (s) => s.usernameStatus,
                'usernameStatus',
                UsernameStatus.reserved,
              )
              .having(
                (s) => s.reservedUsernames,
                'reservedUsernames',
                contains(testUsername),
              ),
        ],
        errors: () => [
          isA<Reportable<Object>>().having(
            (r) => r.unwrap(),
            'unwrap',
            isA<StateError>(),
          ),
        ],
      );

      blocTest<ProfileEditorBloc, ProfileEditorState>(
        'wraps unexpected MentionResolutionService Error as Reportable '
        'but continues the save with the raw bio text',
        setUp: () {
          when(
            () => mockProfileRepository.getCachedProfile(pubkey: testPubkey),
          ).thenAnswer((_) async => null);
          when(
            () => mockProfileRepository.saveProfileEvent(
              displayName: testDisplayName,
              about: 'hi @alice',
              picture: testPicture,
              clearNip05: any(named: 'clearNip05'),
            ),
          ).thenAnswer((_) async => createTestProfile());
          when(
            () => mockMentionResolutionService.resolveTextMentions(
              rawText: any(named: 'rawText'),
              currentUserPubkey: any(named: 'currentUserPubkey'),
            ),
          ).thenThrow(StateError('mention service invariant'));
        },
        build: () => createBloc(
          mentionResolutionService: mockMentionResolutionService,
        ),
        act: (bloc) => bloc.add(
          const ProfileSaved(
            pubkey: testPubkey,
            displayName: testDisplayName,
            about: 'hi @alice',
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
        errors: () => [
          isA<Reportable<Object>>().having(
            (r) => r.unwrap(),
            'unwrap',
            isA<StateError>(),
          ),
        ],
        verify: (_) {
          // Save still happens with the raw (unresolved) bio.
          verify(
            () => mockProfileRepository.saveProfileEvent(
              displayName: testDisplayName,
              about: 'hi @alice',
              picture: testPicture,
              clearNip05: any(named: 'clearNip05'),
            ),
          ).called(1);
        },
      );
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
        act: (bloc) => bloc.add(
          UsernameChanged(
            List.filled(kDivineUsernameMaxLength + 1, 'a').join(),
          ),
        ),
        wait: debounceDuration,
        expect: () => [
          isA<ProfileEditorState>()
              .having(
                (s) => s.username,
                'username',
                List.filled(kDivineUsernameMaxLength + 1, 'a').join(),
              )
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
                UsernameStatus.invalidFormat,
              )
              .having(
                (s) => s.usernameError,
                'usernameError',
                equals(UsernameValidationError.invalidFormat),
              )
              .having(
                (s) => s.usernameFormatMessage,
                'usernameFormatMessage',
                'Only letters, numbers, and hyphens are allowed '
                    '(your username becomes username.divine.video)',
              ),
        ],
      );

      blocTest<ProfileEditorBloc, ProfileEditorState>(
        'rejects username with a dot before API (DNS label policy)',
        build: createBloc,
        act: (bloc) => bloc.add(const UsernameChanged('mr.')),
        wait: debounceDuration,
        expect: () => [
          isA<ProfileEditorState>()
              .having((s) => s.username, 'username', 'mr.')
              .having(
                (s) => s.usernameStatus,
                'usernameStatus',
                UsernameStatus.invalidFormat,
              )
              .having(
                (s) => s.usernameError,
                'usernameError',
                equals(UsernameValidationError.invalidFormat),
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
        'rejects username with underscore before API (DNS label policy)',
        build: createBloc,
        act: (bloc) => bloc.add(const UsernameChanged('my_name')),
        wait: debounceDuration,
        expect: () => [
          isA<ProfileEditorState>()
              .having((s) => s.username, 'username', 'my_name')
              .having(
                (s) => s.usernameStatus,
                'usernameStatus',
                UsernameStatus.invalidFormat,
              )
              .having(
                (s) => s.usernameError,
                'usernameError',
                equals(UsernameValidationError.invalidFormat),
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
        'emits [checking, reserved] when username is reserved',
        setUp: () {
          when(
            () => mockProfileRepository.checkUsernameAvailability(
              username: testUsername,
            ),
          ).thenAnswer((_) async => const UsernameReserved());
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
                UsernameStatus.reserved,
              )
              .having(
                (s) => s.reservedUsernames,
                'reservedUsernames',
                contains(testUsername),
              ),
        ],
      );

      blocTest<ProfileEditorBloc, ProfileEditorState>(
        'emits [checking, burned] when username is burned',
        setUp: () {
          when(
            () => mockProfileRepository.checkUsernameAvailability(
              username: testUsername,
            ),
          ).thenAnswer((_) async => const UsernameBurned());
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
                UsernameStatus.burned,
              ),
        ],
      );

      blocTest<ProfileEditorBloc, ProfileEditorState>(
        'emits [checking, available] when username is admin-assigned to '
        'current user',
        setUp: () {
          when(
            () => mockProfileRepository.checkUsernameAvailability(
              username: testUsername,
              currentUserPubkey: testPubkey,
            ),
          ).thenAnswer((_) async => const UsernameAvailable());
        },
        build: () => ProfileEditorBloc(
          profileRepository: mockProfileRepository,
          blossomUploadService: mockBlossomUploadService,
          hasExistingProfile: true,
          currentUserPubkey: testPubkey,
        ),
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
              currentUserPubkey: testPubkey,
            ),
          ).called(1);
        },
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

    group('UsernameRechecked', () {
      blocTest<ProfileEditorBloc, ProfileEditorState>(
        'emits available when nameserver releases reserved username',
        build: createBloc,
        seed: () => const ProfileEditorState(
          username: testUsername,
          usernameStatus: UsernameStatus.reserved,
          reservedUsernames: {testUsername},
        ),
        setUp: () {
          when(
            () => mockProfileRepository.checkUsernameAvailability(
              username: testUsername,
              currentUserPubkey: any(named: 'currentUserPubkey'),
            ),
          ).thenAnswer((_) async => const UsernameAvailable());
        },
        act: (bloc) => bloc.add(const UsernameRechecked()),
        expect: () => [
          isA<ProfileEditorState>()
              .having(
                (s) => s.usernameStatus,
                'usernameStatus',
                UsernameStatus.checking,
              )
              .having((s) => s.reservedUsernames, 'reservedUsernames', isEmpty),
          isA<ProfileEditorState>().having(
            (s) => s.usernameStatus,
            'usernameStatus',
            UsernameStatus.available,
          ),
        ],
      );

      blocTest<ProfileEditorBloc, ProfileEditorState>(
        'emits taken when username is now taken by someone else',
        build: createBloc,
        seed: () => const ProfileEditorState(
          username: testUsername,
          usernameStatus: UsernameStatus.reserved,
          reservedUsernames: {testUsername},
        ),
        setUp: () {
          when(
            () => mockProfileRepository.checkUsernameAvailability(
              username: testUsername,
              currentUserPubkey: any(named: 'currentUserPubkey'),
            ),
          ).thenAnswer((_) async => const UsernameTaken());
        },
        act: (bloc) => bloc.add(const UsernameRechecked()),
        expect: () => [
          isA<ProfileEditorState>().having(
            (s) => s.usernameStatus,
            'usernameStatus',
            UsernameStatus.checking,
          ),
          isA<ProfileEditorState>().having(
            (s) => s.usernameStatus,
            'usernameStatus',
            UsernameStatus.taken,
          ),
        ],
      );

      blocTest<ProfileEditorBloc, ProfileEditorState>(
        'restores reserved status on network error',
        build: createBloc,
        seed: () => const ProfileEditorState(
          username: testUsername,
          usernameStatus: UsernameStatus.reserved,
          reservedUsernames: {testUsername},
        ),
        setUp: () {
          when(
            () => mockProfileRepository.checkUsernameAvailability(
              username: testUsername,
              currentUserPubkey: any(named: 'currentUserPubkey'),
            ),
          ).thenAnswer((_) async => const UsernameCheckError('Network error'));
        },
        act: (bloc) => bloc.add(const UsernameRechecked()),
        expect: () => [
          isA<ProfileEditorState>()
              .having(
                (s) => s.usernameStatus,
                'usernameStatus',
                UsernameStatus.checking,
              )
              .having((s) => s.reservedUsernames, 'reservedUsernames', isEmpty),
          isA<ProfileEditorState>()
              .having(
                (s) => s.usernameStatus,
                'usernameStatus',
                UsernameStatus.reserved,
              )
              .having(
                (s) => s.reservedUsernames,
                'reservedUsernames',
                contains(testUsername),
              ),
        ],
      );

      blocTest<ProfileEditorBloc, ProfileEditorState>(
        'does nothing when username is empty',
        build: createBloc,
        seed: () =>
            const ProfileEditorState(usernameStatus: UsernameStatus.reserved),
        act: (bloc) => bloc.add(const UsernameRechecked()),
        expect: () => <ProfileEditorState>[],
        verify: (_) {
          verifyNever(
            () => mockProfileRepository.checkUsernameAvailability(
              username: any(named: 'username'),
            ),
          );
        },
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
        const state = ProfileEditorState(username: 'someuser');
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

      test('returns false while an avatar upload is in flight', () {
        // Reviewer #3916 bullet: Save must be unavailable during upload so
        // the publish path can't race the staged URL.
        const state = ProfileEditorState(
          username: 'alice',
          usernameStatus: UsernameStatus.available,
          pendingAvatarStatus: PendingAvatarStatus.uploading,
        );
        expect(state.isSaveReady, isFalse);
      });

      test(
        'returns true once the upload settles to staged (otherwise valid)',
        () {
          // Sanity check the gate is purely the uploading status, not
          // "any non-idle pendingAvatarStatus".
          const state = ProfileEditorState(
            username: 'alice',
            usernameStatus: UsernameStatus.available,
            pendingAvatarStatus: PendingAvatarStatus.staged,
            pendingPictureUrl: 'https://media.divine.video/staged-hash',
          );
          expect(state.isSaveReady, isTrue);
        },
      );
    });

    // Reviewer-mandated coverage for option C from PR #3916: avatar uploads
    // stage in bloc state, save is the only publish point, failures preserve
    // the prior preview, no kind-0 churn from upload alone.
    group('profile picture staging', () {
      const testStagedUrl = 'https://media.divine.video/staged-hash';
      const testPersistedUrl = 'https://media.divine.video/persisted-hash';
      final testBytes = Uint8List.fromList([0xFF, 0xD8, 0xFF]);

      blocTest<ProfileEditorBloc, ProfileEditorState>(
        'ProfilePictureUploadRequested with bytes stages on success',
        setUp: () {
          when(
            () => mockBlossomUploadService.uploadImageBytes(
              bytes: any(named: 'bytes'),
              filename: any(named: 'filename'),
              nostrPubkey: any(named: 'nostrPubkey'),
              mimeType: any(named: 'mimeType'),
            ),
          ).thenAnswer(
            (_) async => const BlossomUploadResult(
              success: true,
              url: testStagedUrl,
              fallbackUrl: testStagedUrl,
            ),
          );
        },
        build: createBloc,
        act: (bloc) => bloc.add(
          ProfilePictureUploadRequested(
            pubkey: testPubkey,
            bytes: testBytes,
            filename: 'avatar.jpg',
          ),
        ),
        expect: () => [
          isA<ProfileEditorState>().having(
            (s) => s.pendingAvatarStatus,
            'pendingAvatarStatus',
            PendingAvatarStatus.uploading,
          ),
          isA<ProfileEditorState>()
              .having(
                (s) => s.pendingAvatarStatus,
                'pendingAvatarStatus',
                PendingAvatarStatus.staged,
              )
              .having(
                (s) => s.pendingPictureUrl,
                'pendingPictureUrl',
                testStagedUrl,
              ),
        ],
        verify: (_) {
          verify(
            () => mockBlossomUploadService.uploadImageBytes(
              bytes: testBytes,
              filename: 'avatar.jpg',
              nostrPubkey: testPubkey,
            ),
          ).called(1);
          verifyNever(
            () => mockBlossomUploadService.uploadImage(
              imageFile: any(named: 'imageFile'),
              nostrPubkey: any(named: 'nostrPubkey'),
            ),
          );
        },
      );

      blocTest<ProfileEditorBloc, ProfileEditorState>(
        'ProfilePictureUploadRequested with file stages on success',
        setUp: () {
          when(
            () => mockBlossomUploadService.uploadImage(
              imageFile: any(named: 'imageFile'),
              nostrPubkey: any(named: 'nostrPubkey'),
              mimeType: any(named: 'mimeType'),
            ),
          ).thenAnswer(
            (_) async => const BlossomUploadResult(
              success: true,
              url: testStagedUrl,
              fallbackUrl: testStagedUrl,
            ),
          );
        },
        build: createBloc,
        act: (bloc) => bloc.add(
          ProfilePictureUploadRequested(pubkey: testPubkey, file: _FakeFile()),
        ),
        expect: () => [
          isA<ProfileEditorState>().having(
            (s) => s.pendingAvatarStatus,
            'pendingAvatarStatus',
            PendingAvatarStatus.uploading,
          ),
          isA<ProfileEditorState>()
              .having(
                (s) => s.pendingAvatarStatus,
                'pendingAvatarStatus',
                PendingAvatarStatus.staged,
              )
              .having(
                (s) => s.pendingPictureUrl,
                'pendingPictureUrl',
                testStagedUrl,
              ),
        ],
        verify: (_) {
          verify(
            () => mockBlossomUploadService.uploadImage(
              imageFile: any(named: 'imageFile'),
              nostrPubkey: testPubkey,
            ),
          ).called(1);
        },
      );

      blocTest<ProfileEditorBloc, ProfileEditorState>(
        'upload failure leaves pendingPictureUrl untouched and emits failed',
        setUp: () {
          when(
            () => mockBlossomUploadService.uploadImageBytes(
              bytes: any(named: 'bytes'),
              filename: any(named: 'filename'),
              nostrPubkey: any(named: 'nostrPubkey'),
              mimeType: any(named: 'mimeType'),
            ),
          ).thenAnswer(
            (_) async => const BlossomUploadResult(
              success: false,
              errorMessage: 'Server error (503): unavailable',
              failureReason: BlossomUploadFailureReason.server,
            ),
          );
        },
        build: createBloc,
        seed: () => const ProfileEditorState(
          pendingAvatarStatus: PendingAvatarStatus.staged,
          pendingPictureUrl: testStagedUrl,
        ),
        act: (bloc) => bloc.add(
          ProfilePictureUploadRequested(pubkey: testPubkey, bytes: testBytes),
        ),
        expect: () => [
          // Optimistic transition to uploading retains the prior staged URL
          // (so the avatar widget can show the previously-staged image while
          // the next attempt is in flight).
          isA<ProfileEditorState>()
              .having(
                (s) => s.pendingAvatarStatus,
                'pendingAvatarStatus',
                PendingAvatarStatus.uploading,
              )
              .having(
                (s) => s.pendingPictureUrl,
                'pendingPictureUrl',
                testStagedUrl,
              ),
          // Failure preserves the prior URL — no fake-success preview — and
          // classifies the error so the UI can show the right localized
          // snackbar (server error, in this case).
          isA<ProfileEditorState>()
              .having(
                (s) => s.pendingAvatarStatus,
                'pendingAvatarStatus',
                PendingAvatarStatus.failed,
              )
              .having(
                (s) => s.pendingPictureUrl,
                'pendingPictureUrl',
                testStagedUrl,
              )
              .having(
                (s) => s.avatarUploadError,
                'avatarUploadError',
                AvatarUploadError.server,
              ),
        ],
        errors: () => [isA<Exception>()],
      );

      blocTest<ProfileEditorBloc, ProfileEditorState>(
        'maps network failureReason to AvatarUploadError.network',
        setUp: () {
          when(
            () => mockBlossomUploadService.uploadImageBytes(
              bytes: any(named: 'bytes'),
              filename: any(named: 'filename'),
              nostrPubkey: any(named: 'nostrPubkey'),
              mimeType: any(named: 'mimeType'),
            ),
          ).thenAnswer(
            (_) async => const BlossomUploadResult(
              success: false,
              errorMessage: 'Connection timeout',
              failureReason: BlossomUploadFailureReason.network,
            ),
          );
        },
        build: createBloc,
        act: (bloc) => bloc.add(
          ProfilePictureUploadRequested(pubkey: testPubkey, bytes: testBytes),
        ),
        skip: 1, // skip the "uploading" emission, only assert final state
        expect: () => [
          isA<ProfileEditorState>().having(
            (s) => s.avatarUploadError,
            'avatarUploadError',
            AvatarUploadError.network,
          ),
        ],
        errors: () => [isA<Exception>()],
      );

      blocTest<ProfileEditorBloc, ProfileEditorState>(
        'maps auth failureReason to AvatarUploadError.auth',
        setUp: () {
          when(
            () => mockBlossomUploadService.uploadImageBytes(
              bytes: any(named: 'bytes'),
              filename: any(named: 'filename'),
              nostrPubkey: any(named: 'nostrPubkey'),
              mimeType: any(named: 'mimeType'),
            ),
          ).thenAnswer(
            (_) async => const BlossomUploadResult(
              success: false,
              errorMessage: 'Upload rejected: 401 Unauthorized',
              failureReason: BlossomUploadFailureReason.auth,
            ),
          );
        },
        build: createBloc,
        act: (bloc) => bloc.add(
          ProfilePictureUploadRequested(pubkey: testPubkey, bytes: testBytes),
        ),
        skip: 1,
        expect: () => [
          isA<ProfileEditorState>().having(
            (s) => s.avatarUploadError,
            'avatarUploadError',
            AvatarUploadError.auth,
          ),
        ],
        errors: () => [isA<Exception>()],
      );

      blocTest<ProfileEditorBloc, ProfileEditorState>(
        'maps fileTooLarge failureReason to AvatarUploadError.fileTooLarge',
        setUp: () {
          when(
            () => mockBlossomUploadService.uploadImageBytes(
              bytes: any(named: 'bytes'),
              filename: any(named: 'filename'),
              nostrPubkey: any(named: 'nostrPubkey'),
              mimeType: any(named: 'mimeType'),
            ),
          ).thenAnswer(
            (_) async => const BlossomUploadResult(
              success: false,
              errorMessage: 'Payload too large (413)',
              failureReason: BlossomUploadFailureReason.fileTooLarge,
            ),
          );
        },
        build: createBloc,
        act: (bloc) => bloc.add(
          ProfilePictureUploadRequested(pubkey: testPubkey, bytes: testBytes),
        ),
        skip: 1,
        expect: () => [
          isA<ProfileEditorState>().having(
            (s) => s.avatarUploadError,
            'avatarUploadError',
            AvatarUploadError.fileTooLarge,
          ),
        ],
        errors: () => [isA<Exception>()],
      );

      blocTest<ProfileEditorBloc, ProfileEditorState>(
        'maps unknown failureReason to AvatarUploadError.generic',
        setUp: () {
          when(
            () => mockBlossomUploadService.uploadImageBytes(
              bytes: any(named: 'bytes'),
              filename: any(named: 'filename'),
              nostrPubkey: any(named: 'nostrPubkey'),
              mimeType: any(named: 'mimeType'),
            ),
          ).thenAnswer(
            (_) async => const BlossomUploadResult(
              success: false,
              errorMessage: 'something weird happened',
              failureReason: BlossomUploadFailureReason.unknown,
            ),
          );
        },
        build: createBloc,
        act: (bloc) => bloc.add(
          ProfilePictureUploadRequested(pubkey: testPubkey, bytes: testBytes),
        ),
        skip: 1,
        expect: () => [
          isA<ProfileEditorState>().having(
            (s) => s.avatarUploadError,
            'avatarUploadError',
            AvatarUploadError.generic,
          ),
        ],
        errors: () => [isA<Exception>()],
      );

      blocTest<ProfileEditorBloc, ProfileEditorState>(
        'unexpected thrown upload exception falls back to generic',
        setUp: () {
          when(
            () => mockBlossomUploadService.uploadImageBytes(
              bytes: any(named: 'bytes'),
              filename: any(named: 'filename'),
              nostrPubkey: any(named: 'nostrPubkey'),
              mimeType: any(named: 'mimeType'),
            ),
          ).thenThrow(Exception('socket exploded'));
        },
        build: createBloc,
        act: (bloc) => bloc.add(
          ProfilePictureUploadRequested(pubkey: testPubkey, bytes: testBytes),
        ),
        skip: 1,
        expect: () => [
          isA<ProfileEditorState>()
              .having(
                (s) => s.pendingAvatarStatus,
                'pendingAvatarStatus',
                PendingAvatarStatus.failed,
              )
              .having(
                (s) => s.avatarUploadError,
                'avatarUploadError',
                AvatarUploadError.generic,
              ),
        ],
        errors: () => [isA<Exception>()],
      );

      blocTest<ProfileEditorBloc, ProfileEditorState>(
        'ProfilePictureUploadCleared resets pending to idle',
        build: createBloc,
        seed: () => const ProfileEditorState(
          pendingAvatarStatus: PendingAvatarStatus.staged,
          pendingPictureUrl: testStagedUrl,
        ),
        act: (bloc) => bloc.add(const ProfilePictureUploadCleared()),
        expect: () => [
          isA<ProfileEditorState>()
              .having(
                (s) => s.pendingAvatarStatus,
                'pendingAvatarStatus',
                PendingAvatarStatus.idle,
              )
              .having((s) => s.pendingPictureUrl, 'pendingPictureUrl', isNull),
        ],
      );

      blocTest<ProfileEditorBloc, ProfileEditorState>(
        'ProfilePictureUrlSet stages without an upload call',
        build: createBloc,
        act: (bloc) =>
            bloc.add(const ProfilePictureUrlSet('  $testStagedUrl  ')),
        expect: () => [
          isA<ProfileEditorState>()
              .having(
                (s) => s.pendingAvatarStatus,
                'pendingAvatarStatus',
                PendingAvatarStatus.staged,
              )
              .having(
                (s) => s.pendingPictureUrl,
                'pendingPictureUrl',
                testStagedUrl,
              ),
        ],
        verify: (_) {
          verifyNever(
            () => mockBlossomUploadService.uploadImage(
              imageFile: any(named: 'imageFile'),
              nostrPubkey: any(named: 'nostrPubkey'),
            ),
          );
          verifyNever(
            () => mockBlossomUploadService.uploadImageBytes(
              bytes: any(named: 'bytes'),
              nostrPubkey: any(named: 'nostrPubkey'),
            ),
          );
        },
      );

      blocTest<ProfileEditorBloc, ProfileEditorState>(
        'ProfileSaved publishes staged picture from state',
        setUp: () {
          when(
            () => mockProfileRepository.getCachedProfile(
              pubkey: any(named: 'pubkey'),
            ),
          ).thenAnswer((_) async => null);
          when(
            () => mockProfileRepository.saveProfileEvent(
              displayName: any(named: 'displayName'),
              about: any(named: 'about'),
              username: any(named: 'username'),
              nip05: any(named: 'nip05'),
              clearNip05: any(named: 'clearNip05'),
              picture: any(named: 'picture'),
              banner: any(named: 'banner'),
              currentProfile: any(named: 'currentProfile'),
            ),
          ).thenAnswer((_) async => createTestProfile());
        },
        build: createBloc,
        seed: () => const ProfileEditorState(
          pendingAvatarStatus: PendingAvatarStatus.staged,
          pendingPictureUrl: testStagedUrl,
          persistedPictureUrl: testPersistedUrl,
        ),
        act: (bloc) => bloc.add(
          const ProfileSaved(
            pubkey: testPubkey,
            displayName: testDisplayName,
            about: testAbout,
          ),
        ),
        verify: (_) {
          verify(
            () => mockProfileRepository.saveProfileEvent(
              displayName: testDisplayName,
              about: testAbout,
              picture: testStagedUrl,
            ),
          ).called(1);
        },
      );

      blocTest<ProfileEditorBloc, ProfileEditorState>(
        'ProfileSaved with no staged change publishes the persisted picture',
        setUp: () {
          when(
            () => mockProfileRepository.getCachedProfile(
              pubkey: any(named: 'pubkey'),
            ),
          ).thenAnswer((_) async => null);
          when(
            () => mockProfileRepository.saveProfileEvent(
              displayName: any(named: 'displayName'),
              about: any(named: 'about'),
              username: any(named: 'username'),
              nip05: any(named: 'nip05'),
              clearNip05: any(named: 'clearNip05'),
              picture: any(named: 'picture'),
              banner: any(named: 'banner'),
              currentProfile: any(named: 'currentProfile'),
            ),
          ).thenAnswer((_) async => createTestProfile());
        },
        build: createBloc,
        seed: () =>
            const ProfileEditorState(persistedPictureUrl: testPersistedUrl),
        act: (bloc) => bloc.add(
          const ProfileSaved(
            pubkey: testPubkey,
            displayName: testDisplayName,
            about: testAbout,
          ),
        ),
        verify: (_) {
          // Picture argument falls back to persisted URL — Save with no edits
          // must not silently blank an existing avatar.
          verify(
            () => mockProfileRepository.saveProfileEvent(
              displayName: any(named: 'displayName'),
              about: any(named: 'about'),
              username: any(named: 'username'),
              nip05: any(named: 'nip05'),
              clearNip05: any(named: 'clearNip05'),
              picture: testPersistedUrl,
              banner: any(named: 'banner'),
              currentProfile: any(named: 'currentProfile'),
            ),
          ).called(1);
        },
      );

      blocTest<ProfileEditorBloc, ProfileEditorState>(
        'upload success alone does not publish kind 0',
        setUp: () {
          when(
            () => mockBlossomUploadService.uploadImageBytes(
              bytes: any(named: 'bytes'),
              filename: any(named: 'filename'),
              nostrPubkey: any(named: 'nostrPubkey'),
              mimeType: any(named: 'mimeType'),
            ),
          ).thenAnswer(
            (_) async => const BlossomUploadResult(
              success: true,
              url: testStagedUrl,
              fallbackUrl: testStagedUrl,
            ),
          );
        },
        build: createBloc,
        act: (bloc) => bloc.add(
          ProfilePictureUploadRequested(pubkey: testPubkey, bytes: testBytes),
        ),
        verify: (_) {
          // The load-bearing invariant from reviewer bullet 6: upload alone
          // must not call into the profile-publish path.
          verifyNever(
            () => mockProfileRepository.saveProfileEvent(
              displayName: any(named: 'displayName'),
              about: any(named: 'about'),
              username: any(named: 'username'),
              nip05: any(named: 'nip05'),
              clearNip05: any(named: 'clearNip05'),
              picture: any(named: 'picture'),
              banner: any(named: 'banner'),
              currentProfile: any(named: 'currentProfile'),
            ),
          );
          verifyNever(
            () => mockProfileRepository.claimUsername(
              username: any(named: 'username'),
            ),
          );
        },
      );

      blocTest<ProfileEditorBloc, ProfileEditorState>(
        'ProfileSaved while uploading is dropped — no publish, no claim',
        // Pins the bloc-side guard from reviewer #3916 follow-up: even if the
        // UI gate (`isSaveReady`) is bypassed, the bloc must not call into
        // saveProfileEvent / claimUsername with a stale `persistedPictureUrl`
        // while the staged URL is still in flight.
        build: createBloc,
        seed: () => const ProfileEditorState(
          pendingAvatarStatus: PendingAvatarStatus.uploading,
          persistedPictureUrl: testPersistedUrl,
        ),
        act: (bloc) => bloc.add(
          const ProfileSaved(
            pubkey: testPubkey,
            displayName: testDisplayName,
            about: testAbout,
          ),
        ),
        expect: () => const <ProfileEditorState>[],
        verify: (_) {
          verifyNever(
            () => mockProfileRepository.saveProfileEvent(
              displayName: any(named: 'displayName'),
              about: any(named: 'about'),
              username: any(named: 'username'),
              nip05: any(named: 'nip05'),
              clearNip05: any(named: 'clearNip05'),
              picture: any(named: 'picture'),
              banner: any(named: 'banner'),
              currentProfile: any(named: 'currentProfile'),
            ),
          );
          verifyNever(
            () => mockProfileRepository.claimUsername(
              username: any(named: 'username'),
            ),
          );
          verifyNever(
            () => mockProfileRepository.getCachedProfile(
              pubkey: any(named: 'pubkey'),
            ),
          );
        },
      );

      blocTest<ProfileEditorBloc, ProfileEditorState>(
        'ProfileNip05Saved while avatar upload is in flight is dropped',
        build: createBloc,
        seed: () => const ProfileEditorState(
          pendingAvatarStatus: PendingAvatarStatus.uploading,
          persistedPictureUrl: testPersistedUrl,
        ),
        act: (bloc) => bloc.add(
          ProfileNip05Saved(
            currentProfile: UserProfile(
              pubkey: testPubkey,
              displayName: testDisplayName,
              about: testAbout,
              picture: testPicture,
              rawData: const {},
              createdAt: DateTime.now(),
              eventId:
                  'nip05evt-uploading-1234567890123456789012345678901234567890',
            ),
          ),
        ),
        expect: () => const <ProfileEditorState>[],
        verify: (_) {
          verifyNever(
            () => mockProfileRepository.saveProfileEvent(
              displayName: any(named: 'displayName'),
              about: any(named: 'about'),
              username: any(named: 'username'),
              nip05: any(named: 'nip05'),
              clearNip05: any(named: 'clearNip05'),
              picture: any(named: 'picture'),
              banner: any(named: 'banner'),
              currentProfile: any(named: 'currentProfile'),
            ),
          );
          verifyNever(
            () => mockProfileRepository.claimUsername(
              username: any(named: 'username'),
            ),
          );
          verifyNever(
            () => mockProfileRepository.getCachedProfile(
              pubkey: any(named: 'pubkey'),
            ),
          );
        },
      );

      blocTest<ProfileEditorBloc, ProfileEditorState>(
        'ProfileSaveConfirmed while banner upload is in flight is dropped',
        build: () => createBloc(hasExistingProfile: false),
        seed: () => const ProfileEditorState(
          status: ProfileEditorStatus.confirmationRequired,
          pendingEvent: ProfileSaved(
            pubkey: testPubkey,
            displayName: testDisplayName,
            about: testAbout,
          ),
          pendingBannerStatus: PendingBannerStatus.uploading,
        ),
        act: (bloc) => bloc.add(const ProfileSaveConfirmed()),
        expect: () => const <ProfileEditorState>[],
        verify: (_) {
          verifyNever(
            () => mockProfileRepository.saveProfileEvent(
              displayName: any(named: 'displayName'),
              about: any(named: 'about'),
              username: any(named: 'username'),
              nip05: any(named: 'nip05'),
              clearNip05: any(named: 'clearNip05'),
              picture: any(named: 'picture'),
              banner: any(named: 'banner'),
              currentProfile: any(named: 'currentProfile'),
            ),
          );
          verifyNever(
            () => mockProfileRepository.claimUsername(
              username: any(named: 'username'),
            ),
          );
          verifyNever(
            () => mockProfileRepository.getCachedProfile(
              pubkey: any(named: 'pubkey'),
            ),
          );
        },
      );

      blocTest<ProfileEditorBloc, ProfileEditorState>(
        'ProfilePictureUrlSet while uploading is ignored',
        build: createBloc,
        seed: () => const ProfileEditorState(
          pendingAvatarStatus: PendingAvatarStatus.uploading,
          persistedPictureUrl: testPersistedUrl,
        ),
        act: (bloc) => bloc.add(const ProfilePictureUrlSet(testStagedUrl)),
        expect: () => const <ProfileEditorState>[],
      );
    });

    group('verifier launch flow', () {
      blocTest<ProfileEditorBloc, ProfileEditorState>(
        'flips verifierStatus to launchRequested on VerifierLaunchRequested',
        build: () => ProfileEditorBloc(
          profileRepository: mockProfileRepository,
          blossomUploadService: mockBlossomUploadService,
          hasExistingProfile: true,
          currentUserPubkey: testPubkey,
        ),
        act: (bloc) => bloc.add(const VerifierLaunchRequested()),
        expect: () => [
          isA<ProfileEditorState>().having(
            (s) => s.verifierStatus,
            'verifierStatus',
            VerifierStatus.launchRequested,
          ),
        ],
      );

      blocTest<ProfileEditorBloc, ProfileEditorState>(
        'flips verifierStatus to dismissed on VerifierWebViewDismissed',
        build: () => ProfileEditorBloc(
          profileRepository: mockProfileRepository,
          blossomUploadService: mockBlossomUploadService,
          hasExistingProfile: true,
          currentUserPubkey: testPubkey,
        ),
        seed: () => const ProfileEditorState(
          verifierStatus: VerifierStatus.launchRequested,
        ),
        act: (bloc) => bloc.add(const VerifierWebViewDismissed()),
        expect: () => [
          isA<ProfileEditorState>().having(
            (s) => s.verifierStatus,
            'verifierStatus',
            VerifierStatus.dismissed,
          ),
        ],
      );
    });
  });
}
