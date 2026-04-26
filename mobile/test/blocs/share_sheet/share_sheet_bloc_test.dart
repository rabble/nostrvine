// ABOUTME: Tests for ShareSheetBloc
// ABOUTME: Verifies contact loading, quick-send, send-with-message,
// ABOUTME: save, copy, and share-via action flows

import 'package:bloc_test/bloc_test.dart';
import 'package:file/file.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follow_repository/follow_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/share_sheet/share_sheet_bloc.dart';
import 'package:openvine/services/bookmark_service.dart';
import 'package:openvine/services/video_sharing_service.dart';
import 'package:profile_repository/profile_repository.dart';

class _MockVideoSharingService extends Mock implements VideoSharingService {}

class _MockProfileRepository extends Mock implements ProfileRepository {}

class _MockFollowRepository extends Mock implements FollowRepository {}

class _MockBookmarkService extends Mock implements BookmarkService {}

class _MockCacheManager extends Mock implements BaseCacheManager {}

class _MockFile extends Mock implements File {}

class _FakeVideoEvent extends Fake implements VideoEvent {}

/// A [VideoEvent] whose [toJson] always throws, used to test error paths.
class _ThrowingJsonVideoEvent extends Fake implements VideoEvent {
  @override
  String get id =>
      '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';

  @override
  String get pubkey =>
      'abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789';

  @override
  Map<String, dynamic> toJson() => throw const FormatException('bad json');
}

/// A [VideoEvent] with an invalid hex [id], causing nevent encoding to throw.
class _InvalidIdVideoEvent extends Fake implements VideoEvent {
  @override
  String get id => 'not-valid-hex';

  @override
  String get pubkey =>
      'abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789';
}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeVideoEvent());
  });

  group(ShareSheetBloc, () {
    late _MockVideoSharingService mockSharingService;
    late _MockProfileRepository mockProfileRepository;
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
      mockProfileRepository = _MockProfileRepository();
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
      Future<BookmarkService?>? bookmarkServiceFuture,
      String relayUrl = 'wss://relay.test.example',
      BaseCacheManager? cacheManager,
    }) => ShareSheetBloc(
      video: testVideo,
      relayUrl: relayUrl,
      videoSharingService: mockSharingService,
      profileRepository: mockProfileRepository,
      followRepository: followRepository ?? mockFollowRepository,
      bookmarkServiceFuture:
          bookmarkServiceFuture ?? Future.value(mockBookmarkService),
      cacheManager: cacheManager,
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
          when(
            () => mockProfileRepository.getCachedProfile(
              pubkey: any(named: 'pubkey'),
            ),
          ).thenAnswer((_) async => null);
          when(
            () => mockProfileRepository.fetchFreshProfile(
              pubkey: any(named: 'pubkey'),
            ),
          ).thenAnswer((_) async => null);
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
          when(
            () => mockProfileRepository.getCachedProfile(
              pubkey: any(named: 'pubkey'),
            ),
          ).thenAnswer((_) async => null);
          when(
            () => mockProfileRepository.fetchFreshProfile(
              pubkey: any(named: 'pubkey'),
            ),
          ).thenAnswer((_) async => null);
        },
        build: createBloc,
        act: (bloc) => bloc.add(const ShareSheetContactsLoadRequested()),
        expect: () => [
          const ShareSheetState(status: ShareSheetStatus.loading),
          isA<ShareSheetState>()
              .having((s) => s.status, 'status', ShareSheetStatus.ready)
              .having((s) => s.contacts.length, 'contacts.length', 1),
        ],
      );

      blocTest<ShareSheetBloc, ShareSheetState>(
        'fetches uncached profiles when getCachedProfile returns null',
        setUp: () {
          const cachedPubkey =
              'cccc456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
          const uncachedPubkey =
              'dddd456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';

          when(() => mockSharingService.recentlySharedWith).thenReturn([]);
          when(
            () => mockFollowRepository.followingPubkeys,
          ).thenReturn([cachedPubkey, uncachedPubkey]);
          when(
            () => mockProfileRepository.getCachedProfile(pubkey: cachedPubkey),
          ).thenAnswer(
            (_) async => UserProfile(
              pubkey: cachedPubkey,
              createdAt: DateTime.now(),
              eventId: 'event-$cachedPubkey',
              rawData: const {},
            ),
          );
          when(
            () =>
                mockProfileRepository.getCachedProfile(pubkey: uncachedPubkey),
          ).thenAnswer((_) async => null);
          when(
            () =>
                mockProfileRepository.fetchFreshProfile(pubkey: uncachedPubkey),
          ).thenAnswer((_) async => null);
        },
        build: createBloc,
        act: (bloc) => bloc.add(const ShareSheetContactsLoadRequested()),
        expect: () => [
          const ShareSheetState(status: ShareSheetStatus.loading),
          isA<ShareSheetState>()
              .having((s) => s.status, 'status', ShareSheetStatus.ready)
              .having((s) => s.contacts.length, 'contacts.length', 2),
        ],
        verify: (_) {
          verify(
            () => mockProfileRepository.fetchFreshProfile(
              pubkey:
                  'dddd456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
            ),
          ).called(1);
          verifyNever(
            () => mockProfileRepository.fetchFreshProfile(
              pubkey:
                  'cccc456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
            ),
          );
        },
      );
    });

    group('contact deduplication', () {
      const duplicatePubkey =
          'aaaa456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';

      blocTest<ShareSheetBloc, ShareSheetState>(
        'deduplicates contacts when pubkey appears in both recents and follows',
        setUp: () {
          when(() => mockSharingService.recentlySharedWith).thenReturn([
            const ShareableUser(
              pubkey: duplicatePubkey,
              displayName: 'Alice (recent)',
            ),
          ]);
          when(() => mockFollowRepository.followingPubkeys).thenReturn([
            duplicatePubkey,
            'bbbb456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
          ]);
          when(
            () => mockProfileRepository.getCachedProfile(
              pubkey: any(named: 'pubkey'),
            ),
          ).thenAnswer((_) async => null);
          when(
            () => mockProfileRepository.fetchFreshProfile(
              pubkey: any(named: 'pubkey'),
            ),
          ).thenAnswer((_) async => null);
        },
        build: createBloc,
        act: (bloc) => bloc.add(const ShareSheetContactsLoadRequested()),
        expect: () => [
          const ShareSheetState(status: ShareSheetStatus.loading),
          isA<ShareSheetState>()
              .having((s) => s.status, 'status', ShareSheetStatus.ready)
              .having((s) => s.contacts.length, 'contacts.length', 2)
              .having(
                (s) => s.contacts.first.displayName,
                'first is from recents',
                'Alice (recent)',
              )
              .having(
                (s) =>
                    s.contacts.where((c) => c.pubkey == duplicatePubkey).length,
                'no duplicate pubkey',
                1,
              ),
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
        'sends null personalMessage when message is whitespace only',
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
        act: (bloc) => bloc.add(const ShareSheetSendRequested(message: '   ')),
        verify: (_) {
          final captured = verify(
            () => mockSharingService.shareVideoWithUser(
              video: any(named: 'video'),
              recipientPubkey: captureAny(named: 'recipientPubkey'),
              personalMessage: captureAny(named: 'personalMessage'),
            ),
          ).captured;
          expect(captured[0], equals(testRecipient.pubkey));
          expect(captured[1], isNull, reason: 'whitespace trimmed to null');
        },
      );

      blocTest<ShareSheetBloc, ShareSheetState>(
        'emits failure when shareVideoWithUser throws an exception',
        setUp: () {
          when(
            () => mockSharingService.shareVideoWithUser(
              video: any(named: 'video'),
              recipientPubkey: any(named: 'recipientPubkey'),
              personalMessage: any(named: 'personalMessage'),
            ),
          ).thenThrow(Exception('Unexpected error'));
        },
        seed: () => const ShareSheetState(
          status: ShareSheetStatus.ready,
          selectedRecipient: testRecipient,
        ),
        build: createBloc,
        act: (bloc) => bloc.add(const ShareSheetSendRequested()),
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
        'emits $ShareSheetSaveResult with succeeded=true when bookmark succeeds',
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
            isA<ShareSheetSaveResult>().having(
              (r) => r.succeeded,
              'succeeded',
              isTrue,
            ),
          ),
        ],
      );

      blocTest<ShareSheetBloc, ShareSheetState>(
        'emits $ShareSheetSaveResult with succeeded=false when bookmark fails',
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
            isA<ShareSheetSaveResult>().having(
              (r) => r.succeeded,
              'succeeded',
              isFalse,
            ),
          ),
        ],
      );

      blocTest<ShareSheetBloc, ShareSheetState>(
        'emits $ShareSheetSaveResult with succeeded=false when bookmark throws',
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
            isA<ShareSheetSaveResult>().having(
              (r) => r.succeeded,
              'succeeded',
              isFalse,
            ),
          ),
        ],
      );

      blocTest<ShareSheetBloc, ShareSheetState>(
        'emits $ShareSheetSaveResult with succeeded=false when no bookmark service',
        build: () =>
            createBloc(bookmarkServiceFuture: Future<BookmarkService?>.value()),
        act: (bloc) => bloc.add(const ShareSheetSaveRequested()),
        expect: () => [
          isA<ShareSheetState>().having(
            (s) => s.actionResult,
            'actionResult',
            isA<ShareSheetSaveResult>().having(
              (r) => r.succeeded,
              'succeeded',
              isFalse,
            ),
          ),
        ],
      );

      blocTest<ShareSheetBloc, ShareSheetState>(
        'consecutive saves emit distinct states via identity equality',
        setUp: () {
          when(
            () => mockBookmarkService.addVideoToGlobalBookmarks(any()),
          ).thenAnswer((_) async => true);
        },
        build: createBloc,
        act: (bloc) async {
          bloc.add(const ShareSheetSaveRequested());
          await Future<void>.delayed(Duration.zero);
          bloc.add(const ShareSheetSaveRequested());
        },
        expect: () => [
          isA<ShareSheetState>().having(
            (s) => s.actionResult,
            'actionResult',
            isA<ShareSheetSaveResult>(),
          ),
          isA<ShareSheetState>().having(
            (s) => s.actionResult,
            'actionResult',
            isA<ShareSheetSaveResult>(),
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

      blocTest<ShareSheetBloc, ShareSheetState>(
        'emits $ShareSheetActionFailure when generateShareUrl throws',
        setUp: () {
          when(
            () => mockSharingService.generateShareUrl(any()),
          ).thenThrow(Exception('url error'));
        },
        build: createBloc,
        act: (bloc) => bloc.add(const ShareSheetCopyLinkRequested()),
        expect: () => [
          isA<ShareSheetState>().having(
            (s) => s.actionResult,
            'actionResult',
            isA<ShareSheetActionFailure>(),
          ),
        ],
      );
    });

    // -----------------------------------------------------------------------
    // Share via
    // -----------------------------------------------------------------------

    group('ShareSheetShareViaRequested', () {
      late _MockCacheManager mockCacheManager;

      setUp(() {
        mockCacheManager = _MockCacheManager();
      });

      blocTest<ShareSheetBloc, ShareSheetState>(
        'emits $ShareSheetShareViaTriggered with shareUrl and thumbnailPath',
        setUp: () {
          when(() => mockSharingService.generateShareData(any())).thenReturn((
            shareUrl: 'https://divine.video/video/test-id',
            title: 'Test Video',
            thumbnailUrl: 'https://example.com/thumb.jpg',
          ));
          final mockFile = _MockFile();
          when(() => mockFile.path).thenReturn('/tmp/cached_thumb');
          // Stub copy to return a file at the destination path.
          when(() => mockFile.copy(any())).thenAnswer((inv) async {
            final dest = inv.positionalArguments[0] as String;
            final copied = _MockFile();
            when(() => copied.path).thenReturn(dest);
            return copied;
          });
          when(
            () => mockCacheManager.getSingleFile(any()),
          ).thenAnswer((_) async => mockFile);
        },
        build: () => createBloc(cacheManager: mockCacheManager),
        act: (bloc) => bloc.add(const ShareSheetShareViaRequested()),
        expect: () => [
          isA<ShareSheetState>().having(
            (s) => s.actionResult,
            'actionResult',
            isA<ShareSheetShareViaTriggered>()
                .having(
                  (r) => r.shareUrl,
                  'shareUrl',
                  'https://divine.video/video/test-id',
                )
                .having(
                  (r) => r.thumbnailPath,
                  'thumbnailPath',
                  endsWith('divine_share_thumb.jpg'),
                )
                .having((r) => r.title, 'title', 'Test Video')
                .having((r) => r.subject, 'subject', 'Test Video'),
          ),
        ],
      );

      blocTest<ShareSheetBloc, ShareSheetState>(
        'emits with null thumbnailPath when thumbnail download fails',
        setUp: () {
          when(() => mockSharingService.generateShareData(any())).thenReturn((
            shareUrl: 'https://divine.video/video/test-id',
            title: 'Test Video',
            thumbnailUrl: 'https://example.com/thumb.jpg',
          ));
          when(
            () => mockCacheManager.getSingleFile(any()),
          ).thenThrow(Exception('network error'));
        },
        build: () => createBloc(cacheManager: mockCacheManager),
        act: (bloc) => bloc.add(const ShareSheetShareViaRequested()),
        expect: () => [
          isA<ShareSheetState>().having(
            (s) => s.actionResult,
            'actionResult',
            isA<ShareSheetShareViaTriggered>()
                .having(
                  (r) => r.shareUrl,
                  'shareUrl',
                  'https://divine.video/video/test-id',
                )
                .having((r) => r.thumbnailPath, 'thumbnailPath', isNull),
          ),
        ],
      );

      blocTest<ShareSheetBloc, ShareSheetState>(
        'emits with null thumbnailPath when no thumbnailUrl available',
        setUp: () {
          when(() => mockSharingService.generateShareData(any())).thenReturn((
            shareUrl: 'https://divine.video/video/test-id',
            title: null,
            thumbnailUrl: null,
          ));
        },
        build: () => createBloc(cacheManager: mockCacheManager),
        act: (bloc) => bloc.add(const ShareSheetShareViaRequested()),
        expect: () => [
          isA<ShareSheetState>().having(
            (s) => s.actionResult,
            'actionResult',
            isA<ShareSheetShareViaTriggered>()
                .having((r) => r.thumbnailPath, 'thumbnailPath', isNull)
                .having((r) => r.title, 'title', isNull),
          ),
        ],
      );

      blocTest<ShareSheetBloc, ShareSheetState>(
        'emits with null thumbnailPath when no cache manager provided',
        setUp: () {
          when(() => mockSharingService.generateShareData(any())).thenReturn((
            shareUrl: 'https://divine.video/video/test-id',
            title: 'Test Video',
            thumbnailUrl: 'https://example.com/thumb.jpg',
          ));
        },
        build: createBloc,
        act: (bloc) => bloc.add(const ShareSheetShareViaRequested()),
        expect: () => [
          isA<ShareSheetState>().having(
            (s) => s.actionResult,
            'actionResult',
            isA<ShareSheetShareViaTriggered>().having(
              (r) => r.thumbnailPath,
              'thumbnailPath',
              isNull,
            ),
          ),
        ],
      );

      blocTest<ShareSheetBloc, ShareSheetState>(
        'emits $ShareSheetActionFailure when generateShareData throws',
        setUp: () {
          when(
            () => mockSharingService.generateShareData(any()),
          ).thenThrow(Exception('share error'));
        },
        build: createBloc,
        act: (bloc) => bloc.add(const ShareSheetShareViaRequested()),
        expect: () => [
          isA<ShareSheetState>().having(
            (s) => s.actionResult,
            'actionResult',
            isA<ShareSheetActionFailure>(),
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

      blocTest<ShareSheetBloc, ShareSheetState>(
        'emits $ShareSheetActionFailure when toJson throws',
        build: () => ShareSheetBloc(
          video: _ThrowingJsonVideoEvent(),
          relayUrl: 'wss://relay.test.example',
          videoSharingService: mockSharingService,
          profileRepository: mockProfileRepository,
          followRepository: mockFollowRepository,
        ),
        act: (bloc) => bloc.add(const ShareSheetCopyEventJsonRequested()),
        expect: () => [
          isA<ShareSheetState>().having(
            (s) => s.actionResult,
            'actionResult',
            isA<ShareSheetActionFailure>(),
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

      blocTest<ShareSheetBloc, ShareSheetState>(
        'emits $ShareSheetActionFailure when encoding throws',
        build: () => ShareSheetBloc(
          video: _InvalidIdVideoEvent(),
          relayUrl: 'wss://relay.test.example',
          videoSharingService: mockSharingService,
          profileRepository: mockProfileRepository,
          followRepository: mockFollowRepository,
        ),
        act: (bloc) => bloc.add(const ShareSheetCopyEventIdRequested()),
        expect: () => [
          isA<ShareSheetState>().having(
            (s) => s.actionResult,
            'actionResult',
            isA<ShareSheetActionFailure>(),
          ),
        ],
      );
    });
  });
}
