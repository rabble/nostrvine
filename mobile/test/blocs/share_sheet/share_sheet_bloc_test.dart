// ABOUTME: Tests for ShareSheetBloc
// ABOUTME: Verifies contact loading, quick-send, send-with-message,
// ABOUTME: save, copy, and share-via action flows

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/share_sheet/share_sheet_bloc.dart';
import 'package:openvine/repositories/follow_repository.dart';
import 'package:openvine/services/bookmark_service.dart';
import 'package:openvine/services/user_profile_service.dart';
import 'package:openvine/services/video_sharing_service.dart';

class _MockVideoSharingService extends Mock implements VideoSharingService {}

class _MockUserProfileService extends Mock implements UserProfileService {}

class _MockFollowRepository extends Mock implements FollowRepository {}

class _MockBookmarkService extends Mock implements BookmarkService {}

class _FakeVideoEvent extends Fake implements VideoEvent {}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeVideoEvent());
  });

  group(ShareSheetBloc, () {
    late _MockVideoSharingService mockSharingService;
    late _MockUserProfileService mockProfileService;
    late _MockFollowRepository mockFollowRepository;
    late _MockBookmarkService mockBookmarkService;
    late VideoEvent testVideo;

    const testRecipient = ShareableUser(
      pubkey:
          'aaaa456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
      displayName: 'Alice',
      picture: 'https://example.com/alice.png',
    );

    setUp(() {
      mockSharingService = _MockVideoSharingService();
      mockProfileService = _MockUserProfileService();
      mockFollowRepository = _MockFollowRepository();
      mockBookmarkService = _MockBookmarkService();

      testVideo = VideoEvent(
        id: '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
        pubkey:
            'abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789',
        createdAt: 1757385263,
        content: 'Test video',
        timestamp: DateTime.fromMillisecondsSinceEpoch(1757385263 * 1000),
        videoUrl: 'https://example.com/video.mp4',
        title: 'Test Video',
      );

      // Default stubs
      when(() => mockSharingService.recentlySharedWith).thenReturn([]);
      when(() => mockFollowRepository.followingPubkeys).thenReturn([]);
    });

    ShareSheetBloc createBloc({
      FollowRepository? followRepository,
      BookmarkService? bookmarkService,
    }) => ShareSheetBloc(
      video: testVideo,
      videoSharingService: mockSharingService,
      userProfileService: mockProfileService,
      followRepository: followRepository ?? mockFollowRepository,
      bookmarkService: bookmarkService ?? mockBookmarkService,
    );

    test('initial state is correct', () {
      final bloc = createBloc();
      expect(bloc.state.status, equals(ShareSheetStatus.initial));
      expect(bloc.state.contacts, isEmpty);
      expect(bloc.state.selectedRecipient, isNull);
      expect(bloc.state.sentPubkeys, isEmpty);
      expect(bloc.state.isSending, isFalse);
      expect(bloc.state.actionResult, isNull);
      bloc.close();
    });

    // -----------------------------------------------------------------------
    // Contact loading
    // -----------------------------------------------------------------------

    group('ShareSheetContactsLoadRequested', () {
      blocTest<ShareSheetBloc, ShareSheetState>(
        'emits [loading, ready] with empty contacts when no follows or recents',
        build: createBloc,
        act: (bloc) => bloc.add(const ShareSheetContactsLoadRequested()),
        expect: () => [
          const ShareSheetState(status: ShareSheetStatus.loading),
          const ShareSheetState(status: ShareSheetStatus.ready),
        ],
      );

      blocTest<ShareSheetBloc, ShareSheetState>(
        'emits contacts from recent users and follow list',
        setUp: () {
          when(
            () => mockSharingService.recentlySharedWith,
          ).thenReturn([testRecipient]);
          when(() => mockFollowRepository.followingPubkeys).thenReturn([
            'bbbb456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
          ]);
          when(() => mockProfileService.hasProfile(any())).thenReturn(true);
          when(
            () => mockProfileService.getCachedProfile(any()),
          ).thenReturn(null);
        },
        build: createBloc,
        act: (bloc) => bloc.add(const ShareSheetContactsLoadRequested()),
        expect: () => [
          const ShareSheetState(status: ShareSheetStatus.loading),
          isA<ShareSheetState>()
              .having((s) => s.status, 'status', ShareSheetStatus.ready)
              .having((s) => s.contacts.length, 'contacts.length', 2)
              .having(
                (s) => s.contacts.first.pubkey,
                'first contact pubkey',
                testRecipient.pubkey,
              ),
        ],
      );

      blocTest<ShareSheetBloc, ShareSheetState>(
        'emits ready with empty contacts on error',
        setUp: () {
          when(
            () => mockSharingService.recentlySharedWith,
          ).thenThrow(Exception('network failure'));
        },
        build: createBloc,
        act: (bloc) => bloc.add(const ShareSheetContactsLoadRequested()),
        expect: () => [
          const ShareSheetState(status: ShareSheetStatus.loading),
          const ShareSheetState(status: ShareSheetStatus.ready),
        ],
      );

      blocTest<ShareSheetBloc, ShareSheetState>(
        'loads without follow repository when null',
        setUp: () {
          when(
            () => mockSharingService.recentlySharedWith,
          ).thenReturn([testRecipient]);
          when(() => mockProfileService.hasProfile(any())).thenReturn(true);
        },
        build: () => createBloc(),
        act: (bloc) => bloc.add(const ShareSheetContactsLoadRequested()),
        expect: () => [
          const ShareSheetState(status: ShareSheetStatus.loading),
          isA<ShareSheetState>()
              .having((s) => s.status, 'status', ShareSheetStatus.ready)
              .having((s) => s.contacts.length, 'contacts.length', 1),
        ],
      );
    });

    // -----------------------------------------------------------------------
    // Recipient selection
    // -----------------------------------------------------------------------

    group('ShareSheetRecipientSelected', () {
      blocTest<ShareSheetBloc, ShareSheetState>(
        'sets selected recipient and adds to front of contacts',
        seed: () => const ShareSheetState(status: ShareSheetStatus.ready),
        build: createBloc,
        act: (bloc) =>
            bloc.add(const ShareSheetRecipientSelected(testRecipient)),
        expect: () => [
          isA<ShareSheetState>()
              .having(
                (s) => s.selectedRecipient?.pubkey,
                'selected pubkey',
                testRecipient.pubkey,
              )
              .having(
                (s) => s.contacts.first.pubkey,
                'first contact',
                testRecipient.pubkey,
              ),
        ],
      );
    });

    group('ShareSheetRecipientCleared', () {
      blocTest<ShareSheetBloc, ShareSheetState>(
        'clears selected recipient',
        seed: () => const ShareSheetState(
          status: ShareSheetStatus.ready,
          selectedRecipient: testRecipient,
        ),
        build: createBloc,
        act: (bloc) => bloc.add(const ShareSheetRecipientCleared()),
        expect: () => [
          isA<ShareSheetState>().having(
            (s) => s.selectedRecipient,
            'selectedRecipient',
            isNull,
          ),
        ],
      );
    });

    // -----------------------------------------------------------------------
    // Quick-send
    // -----------------------------------------------------------------------

    group('ShareSheetQuickSendRequested', () {
      blocTest<ShareSheetBloc, ShareSheetState>(
        'emits [sending, success] and marks pubkey as sent on success',
        setUp: () {
          when(
            () => mockSharingService.shareVideoWithUser(
              video: any(named: 'video'),
              recipientPubkey: any(named: 'recipientPubkey'),
            ),
          ).thenAnswer((_) async => ShareResult.createSuccess('msg-event-id'));
        },
        seed: () => const ShareSheetState(status: ShareSheetStatus.ready),
        build: createBloc,
        act: (bloc) =>
            bloc.add(const ShareSheetQuickSendRequested(testRecipient)),
        expect: () => [
          isA<ShareSheetState>()
              .having((s) => s.isSending, 'isSending', isTrue)
              .having((s) => s.selectedRecipient, 'selectedRecipient', isNull),
          isA<ShareSheetState>()
              .having((s) => s.isSending, 'isSending', isFalse)
              .having(
                (s) => s.sentPubkeys.contains(testRecipient.pubkey),
                'sentPubkeys contains recipient',
                isTrue,
              )
              .having(
                (s) => s.actionResult,
                'actionResult',
                isA<ShareSheetSendSuccess>()
                    .having((r) => r.recipientName, 'name', 'Alice')
                    .having((r) => r.shouldDismiss, 'shouldDismiss', isFalse),
              ),
        ],
      );

      blocTest<ShareSheetBloc, ShareSheetState>(
        'emits failure when share returns error',
        setUp: () {
          when(
            () => mockSharingService.shareVideoWithUser(
              video: any(named: 'video'),
              recipientPubkey: any(named: 'recipientPubkey'),
            ),
          ).thenAnswer((_) async => ShareResult.failure('Relay offline'));
        },
        seed: () => const ShareSheetState(status: ShareSheetStatus.ready),
        build: createBloc,
        act: (bloc) =>
            bloc.add(const ShareSheetQuickSendRequested(testRecipient)),
        expect: () => [
          isA<ShareSheetState>().having(
            (s) => s.isSending,
            'isSending',
            isTrue,
          ),
          isA<ShareSheetState>()
              .having((s) => s.isSending, 'isSending', isFalse)
              .having(
                (s) => s.actionResult,
                'actionResult',
                isA<ShareSheetSendFailure>(),
              ),
        ],
      );

      blocTest<ShareSheetBloc, ShareSheetState>(
        'ignores event when already sending',
        seed: () => const ShareSheetState(
          status: ShareSheetStatus.ready,
          isSending: true,
        ),
        build: createBloc,
        act: (bloc) =>
            bloc.add(const ShareSheetQuickSendRequested(testRecipient)),
        expect: () => <ShareSheetState>[],
      );

      blocTest<ShareSheetBloc, ShareSheetState>(
        'ignores event when pubkey already sent',
        seed: () => ShareSheetState(
          status: ShareSheetStatus.ready,
          sentPubkeys: {testRecipient.pubkey},
        ),
        build: createBloc,
        act: (bloc) =>
            bloc.add(const ShareSheetQuickSendRequested(testRecipient)),
        expect: () => <ShareSheetState>[],
      );
    });

    // -----------------------------------------------------------------------
    // Send with message
    // -----------------------------------------------------------------------

    group('ShareSheetSendRequested', () {
      blocTest<ShareSheetBloc, ShareSheetState>(
        'emits success with shouldDismiss true when send succeeds',
        setUp: () {
          when(
            () => mockSharingService.shareVideoWithUser(
              video: any(named: 'video'),
              recipientPubkey: any(named: 'recipientPubkey'),
              personalMessage: any(named: 'personalMessage'),
            ),
          ).thenAnswer((_) async => ShareResult.createSuccess('msg-event-id'));
        },
        seed: () => const ShareSheetState(
          status: ShareSheetStatus.ready,
          selectedRecipient: testRecipient,
        ),
        build: createBloc,
        act: (bloc) =>
            bloc.add(const ShareSheetSendRequested(message: 'Check this out!')),
        expect: () => [
          isA<ShareSheetState>().having(
            (s) => s.isSending,
            'isSending',
            isTrue,
          ),
          isA<ShareSheetState>()
              .having((s) => s.isSending, 'isSending', isFalse)
              .having(
                (s) => s.actionResult,
                'actionResult',
                isA<ShareSheetSendSuccess>().having(
                  (r) => r.shouldDismiss,
                  'shouldDismiss',
                  isTrue,
                ),
              ),
        ],
      );

      blocTest<ShareSheetBloc, ShareSheetState>(
        'does nothing when no recipient selected',
        seed: () => const ShareSheetState(status: ShareSheetStatus.ready),
        build: createBloc,
        act: (bloc) => bloc.add(const ShareSheetSendRequested()),
        expect: () => <ShareSheetState>[],
      );

      blocTest<ShareSheetBloc, ShareSheetState>(
        'does nothing when already sending',
        seed: () => const ShareSheetState(
          status: ShareSheetStatus.ready,
          selectedRecipient: testRecipient,
          isSending: true,
        ),
        build: createBloc,
        act: (bloc) => bloc.add(const ShareSheetSendRequested()),
        expect: () => <ShareSheetState>[],
      );
    });

    // -----------------------------------------------------------------------
    // Save to bookmarks
    // -----------------------------------------------------------------------

    group('ShareSheetSaveRequested', () {
      blocTest<ShareSheetBloc, ShareSheetState>(
        'emits $ShareSheetSaveSuccess when bookmark succeeds',
        setUp: () {
          when(
            () => mockBookmarkService.addVideoToGlobalBookmarks(any()),
          ).thenAnswer((_) async => true);
        },
        build: createBloc,
        act: (bloc) => bloc.add(const ShareSheetSaveRequested()),
        expect: () => [
          isA<ShareSheetState>().having(
            (s) => s.actionResult,
            'actionResult',
            isA<ShareSheetSaveSuccess>(),
          ),
        ],
      );

      blocTest<ShareSheetBloc, ShareSheetState>(
        'emits $ShareSheetSaveFailure when bookmark fails',
        setUp: () {
          when(
            () => mockBookmarkService.addVideoToGlobalBookmarks(any()),
          ).thenAnswer((_) async => false);
        },
        build: createBloc,
        act: (bloc) => bloc.add(const ShareSheetSaveRequested()),
        expect: () => [
          isA<ShareSheetState>().having(
            (s) => s.actionResult,
            'actionResult',
            isA<ShareSheetSaveFailure>(),
          ),
        ],
      );

      blocTest<ShareSheetBloc, ShareSheetState>(
        'emits $ShareSheetSaveFailure when bookmark throws',
        setUp: () {
          when(
            () => mockBookmarkService.addVideoToGlobalBookmarks(any()),
          ).thenThrow(Exception('offline'));
        },
        build: createBloc,
        act: (bloc) => bloc.add(const ShareSheetSaveRequested()),
        expect: () => [
          isA<ShareSheetState>().having(
            (s) => s.actionResult,
            'actionResult',
            isA<ShareSheetSaveFailure>(),
          ),
        ],
      );

      blocTest<ShareSheetBloc, ShareSheetState>(
        'emits $ShareSheetSaveFailure when no bookmark service',
        build: () => createBloc(),
        act: (bloc) => bloc.add(const ShareSheetSaveRequested()),
        expect: () => [
          isA<ShareSheetState>().having(
            (s) => s.actionResult,
            'actionResult',
            isA<ShareSheetSaveFailure>(),
          ),
        ],
      );
    });

    // -----------------------------------------------------------------------
    // Copy link
    // -----------------------------------------------------------------------

    group('ShareSheetCopyLinkRequested', () {
      blocTest<ShareSheetBloc, ShareSheetState>(
        'emits $ShareSheetCopiedToClipboard with generated URL',
        setUp: () {
          when(
            () => mockSharingService.generateShareUrl(any()),
          ).thenReturn('https://divine.video/video/test-id');
        },
        build: createBloc,
        act: (bloc) => bloc.add(const ShareSheetCopyLinkRequested()),
        expect: () => [
          isA<ShareSheetState>().having(
            (s) => s.actionResult,
            'actionResult',
            isA<ShareSheetCopiedToClipboard>()
                .having(
                  (r) => r.text,
                  'text',
                  'https://divine.video/video/test-id',
                )
                .having(
                  (r) => r.label,
                  'label',
                  'Link to post copied to clipboard',
                ),
          ),
        ],
      );
    });

    // -----------------------------------------------------------------------
    // Share via
    // -----------------------------------------------------------------------

    group('ShareSheetShareViaRequested', () {
      blocTest<ShareSheetBloc, ShareSheetState>(
        'emits $ShareSheetShareViaTriggered with share text',
        setUp: () {
          when(
            () => mockSharingService.generateShareText(any()),
          ).thenReturn('https://divine.video/video/test-id');
        },
        build: createBloc,
        act: (bloc) => bloc.add(const ShareSheetShareViaRequested()),
        expect: () => [
          isA<ShareSheetState>().having(
            (s) => s.actionResult,
            'actionResult',
            isA<ShareSheetShareViaTriggered>().having(
              (r) => r.shareText,
              'shareText',
              'https://divine.video/video/test-id',
            ),
          ),
        ],
      );
    });

    // -----------------------------------------------------------------------
    // Copy event JSON
    // -----------------------------------------------------------------------

    group('ShareSheetCopyEventJsonRequested', () {
      blocTest<ShareSheetBloc, ShareSheetState>(
        'emits $ShareSheetCopiedToClipboard with formatted JSON',
        build: createBloc,
        act: (bloc) => bloc.add(const ShareSheetCopyEventJsonRequested()),
        expect: () => [
          isA<ShareSheetState>().having(
            (s) => s.actionResult,
            'actionResult',
            isA<ShareSheetCopiedToClipboard>()
                .having(
                  (r) => r.label,
                  'label',
                  'Nostr event JSON copied to clipboard',
                )
                .having(
                  (r) => r.text.contains('"id"'),
                  'text contains id field',
                  isTrue,
                ),
          ),
        ],
      );
    });

    // -----------------------------------------------------------------------
    // Copy event ID
    // -----------------------------------------------------------------------

    group('ShareSheetCopyEventIdRequested', () {
      blocTest<ShareSheetBloc, ShareSheetState>(
        'emits $ShareSheetCopiedToClipboard with nevent-encoded ID',
        build: createBloc,
        act: (bloc) => bloc.add(const ShareSheetCopyEventIdRequested()),
        expect: () => [
          isA<ShareSheetState>().having(
            (s) => s.actionResult,
            'actionResult',
            isA<ShareSheetCopiedToClipboard>()
                .having(
                  (r) => r.label,
                  'label',
                  'Nostr event ID copied to clipboard',
                )
                .having(
                  (r) => r.text.startsWith('nevent'),
                  'text starts with nevent',
                  isTrue,
                ),
          ),
        ],
      );
    });
  });
}
