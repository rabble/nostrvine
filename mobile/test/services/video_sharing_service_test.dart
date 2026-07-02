// ABOUTME: Tests for VideoSharingService social features integration
// ABOUTME: Covers NIP-17 share path, NIP-04 fallback, getShareableUsers,
// ABOUTME: searchUsersToShareWith, shareVideoWithUser, and sharing utilities.

import 'dart:async';

import 'package:dm_repository/dm_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:openvine/services/auth_service.dart' hide UserProfile;
import 'package:openvine/services/video_sharing_service.dart';
import 'package:profile_repository/profile_repository.dart';

class _MockNostrClient extends Mock implements NostrClient {}

class _MockAuthService extends Mock implements AuthService {}

class _MockProfileRepository extends Mock implements ProfileRepository {}

class _MockDmRepository extends Mock implements DmRepository {}

const _testPubkey =
    'a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2';

const _recipientPubkey =
    'b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2c3';

const _testVideoId =
    'a695f6b60119d9521934a691347d9f78e8770b56da16bb255ee77ac112b4c1f6';

void main() {
  late VideoSharingService service;
  late _MockNostrClient mockNostrService;
  late _MockAuthService mockAuthService;
  late _MockProfileRepository mockProfileRepository;

  setUpAll(() {
    registerFallbackValue(Event(_testPubkey, 4, <List<String>>[], ''));
  });

  setUp(() {
    mockNostrService = _MockNostrClient();
    mockAuthService = _MockAuthService();
    mockProfileRepository = _MockProfileRepository();

    // Default: no DmRepository (NIP-04 fallback path)
    service = VideoSharingService(
      nostrService: mockNostrService,
      authService: mockAuthService,
      profileRepository: mockProfileRepository,
    );
  });

  group('getShareableUsers', () {
    test('returns empty list when no recent shares exist', () async {
      final result = await service.getShareableUsers();

      expect(result, isEmpty);
    });

    test('returns recently shared users after sharing', () async {
      // Arrange - set up successful share
      when(() => mockAuthService.isAuthenticated).thenReturn(true);
      when(
        () => mockAuthService.createAndSignEvent(
          kind: any(named: 'kind'),
          content: any(named: 'content'),
          tags: any(named: 'tags'),
        ),
      ).thenAnswer(
        (_) async => Event(_testPubkey, 4, <List<String>>[], 'test'),
      );
      when(() => mockNostrService.publishEvent(any())).thenAnswer(
        (_) async => PublishSuccess(
          event: Event(_testPubkey, 4, <List<String>>[], 'test'),
        ),
      );
      when(
        () => mockProfileRepository.fetchFreshProfile(pubkey: _recipientPubkey),
      ).thenAnswer(
        (_) async => UserProfile(
          pubkey: _recipientPubkey,
          rawData: const {},
          createdAt: DateTime.now(),
          eventId: 'event1',
          displayName: 'Alice',
          picture: 'https://example.com/alice.jpg',
        ),
      );

      final now = DateTime.now();
      final testVideo = VideoEvent(
        id: _testVideoId,
        pubkey: _testPubkey,
        createdAt: now.millisecondsSinceEpoch ~/ 1000,
        timestamp: now,
        content: 'Test video',
      );

      // Act - share a video, which populates recently shared list
      await service.shareVideoWithUser(
        video: testVideo,
        recipientPubkey: _recipientPubkey,
      );
      // The recents update is now fire-and-forget (see #5391); drain the
      // event loop so the background insert completes before asserting.
      await Future<void>.delayed(Duration.zero);

      final result = await service.getShareableUsers();

      // Assert
      expect(result, hasLength(1));
      expect(result[0].pubkey, _recipientPubkey);
      expect(result[0].displayName, 'Alice');
      expect(result[0].picture, 'https://example.com/alice.jpg');
    });

    test('respects limit parameter', () async {
      // Arrange - share with multiple users
      when(() => mockAuthService.isAuthenticated).thenReturn(true);
      when(
        () => mockAuthService.createAndSignEvent(
          kind: any(named: 'kind'),
          content: any(named: 'content'),
          tags: any(named: 'tags'),
        ),
      ).thenAnswer(
        (_) async => Event(_testPubkey, 4, <List<String>>[], 'test'),
      );
      when(() => mockNostrService.publishEvent(any())).thenAnswer(
        (_) async => PublishSuccess(
          event: Event(_testPubkey, 4, <List<String>>[], 'test'),
        ),
      );
      when(
        () => mockProfileRepository.fetchFreshProfile(
          pubkey: any(named: 'pubkey'),
        ),
      ).thenAnswer((_) async => null);

      final now = DateTime.now();
      final testVideo = VideoEvent(
        id: _testVideoId,
        pubkey: _testPubkey,
        createdAt: now.millisecondsSinceEpoch ~/ 1000,
        timestamp: now,
        content: 'Test video',
      );

      // Share with 6 users to exceed the limit of 5 recent
      for (var i = 0; i < 6; i++) {
        final hexI = i.toRadixString(16).padLeft(64, '0');
        await service.shareVideoWithUser(
          video: testVideo,
          recipientPubkey: hexI,
        );
      }

      // The recents update is now fire-and-forget (see #5391); drain the
      // event loop so all background inserts complete before asserting.
      await Future<void>.delayed(Duration.zero);

      // Act - request with limit 3
      final result = await service.getShareableUsers(limit: 3);

      // Assert - getShareableUsers takes up to 5 recent, then limits
      expect(result.length, 3);
    });
  });

  group('searchUsersToShareWith', () {
    test('returns empty list for empty query', () async {
      final result = await service.searchUsersToShareWith('');

      expect(result, isEmpty);
    });

    test('returns user by hex pubkey lookup', () async {
      final hexPubkey = 'a' * 64;
      final profile = UserProfile(
        pubkey: hexPubkey,
        rawData: const {},
        createdAt: DateTime.now(),
        eventId: 'event1',
        displayName: 'Charlie',
        picture: 'https://example.com/charlie.jpg',
      );

      when(
        () => mockProfileRepository.fetchFreshProfile(pubkey: hexPubkey),
      ).thenAnswer((_) async => profile);

      final result = await service.searchUsersToShareWith(hexPubkey);

      expect(result, hasLength(1));
      expect(result[0].pubkey, hexPubkey);
      expect(result[0].displayName, 'Charlie');
      expect(result[0].picture, 'https://example.com/charlie.jpg');
      verify(
        () => mockProfileRepository.fetchFreshProfile(pubkey: hexPubkey),
      ).called(1);
    });

    test(
      'returns user with null profile data for unknown hex pubkey',
      () async {
        final hexPubkey = 'b' * 64;

        when(
          () => mockProfileRepository.fetchFreshProfile(pubkey: hexPubkey),
        ).thenAnswer((_) async => null);

        final result = await service.searchUsersToShareWith(hexPubkey);

        // Implementation always returns a ShareableUser for hex pubkeys,
        // even when profile is null
        expect(result, hasLength(1));
        expect(result[0].pubkey, hexPubkey);
        expect(result[0].displayName, isNull);
      },
    );

    test('returns empty list for non-hex text queries', () async {
      // Name-based search is not yet implemented
      final result = await service.searchUsersToShareWith('alice');

      expect(result, isEmpty);
    });

    test('returns empty list for short hex-like queries', () async {
      // Must be exactly 64 chars to be treated as a pubkey
      final result = await service.searchUsersToShareWith('abcdef');

      expect(result, isEmpty);
    });
  });

  group('shareVideoWithUser', () {
    test('returns failure when user is not authenticated', () async {
      when(() => mockAuthService.isAuthenticated).thenReturn(false);

      final now = DateTime.now();
      final result = await service.shareVideoWithUser(
        video: VideoEvent(
          id: _testVideoId,
          pubkey: _testPubkey,
          createdAt: now.millisecondsSinceEpoch ~/ 1000,
          timestamp: now,
          content: 'Test',
        ),
        recipientPubkey: _recipientPubkey,
      );

      expect(result.success, isFalse);
      expect(result.error, contains('not authenticated'));
    });

    test('returns failure when event creation fails', () async {
      when(() => mockAuthService.isAuthenticated).thenReturn(true);
      when(
        () => mockAuthService.createAndSignEvent(
          kind: any(named: 'kind'),
          content: any(named: 'content'),
          tags: any(named: 'tags'),
        ),
      ).thenAnswer((_) async => null);

      final now = DateTime.now();
      final result = await service.shareVideoWithUser(
        video: VideoEvent(
          id: _testVideoId,
          pubkey: _testPubkey,
          createdAt: now.millisecondsSinceEpoch ~/ 1000,
          timestamp: now,
          content: 'Test',
        ),
        recipientPubkey: _recipientPubkey,
      );

      expect(result.success, isFalse);
      expect(result.error, contains('Failed to create'));
    });

    test('returns success on successful publish', () async {
      when(() => mockAuthService.isAuthenticated).thenReturn(true);
      final signedEvent = Event(_testPubkey, 4, <List<String>>[], 'test');
      signedEvent.id = 'signed_event_id';

      when(
        () => mockAuthService.createAndSignEvent(
          kind: any(named: 'kind'),
          content: any(named: 'content'),
          tags: any(named: 'tags'),
        ),
      ).thenAnswer((_) async => signedEvent);
      when(
        () => mockNostrService.publishEvent(any()),
      ).thenAnswer((_) async => PublishSuccess(event: signedEvent));
      when(
        () => mockProfileRepository.fetchFreshProfile(
          pubkey: any(named: 'pubkey'),
        ),
      ).thenAnswer((_) async => null);

      final now = DateTime.now();
      final result = await service.shareVideoWithUser(
        video: VideoEvent(
          id: _testVideoId,
          pubkey: _testPubkey,
          createdAt: now.millisecondsSinceEpoch ~/ 1000,
          timestamp: now,
          content: 'Test',
        ),
        recipientPubkey: _recipientPubkey,
      );

      expect(result.success, isTrue);
      expect(result.messageEventId, equals('signed_event_id'));
    });

    test('returns failure when publish fails', () async {
      when(() => mockAuthService.isAuthenticated).thenReturn(true);
      when(
        () => mockAuthService.createAndSignEvent(
          kind: any(named: 'kind'),
          content: any(named: 'content'),
          tags: any(named: 'tags'),
        ),
      ).thenAnswer(
        (_) async => Event(_testPubkey, 4, <List<String>>[], 'test'),
      );
      when(
        () => mockNostrService.publishEvent(any()),
      ).thenAnswer((_) async => const PublishFailed());

      final now = DateTime.now();
      final result = await service.shareVideoWithUser(
        video: VideoEvent(
          id: _testVideoId,
          pubkey: _testPubkey,
          createdAt: now.millisecondsSinceEpoch ~/ 1000,
          timestamp: now,
          content: 'Test',
        ),
        recipientPubkey: _recipientPubkey,
      );

      expect(result.success, isFalse);
      expect(result.error, contains('Failed to publish'));
    });
  });

  group('shareVideoWithUser (NIP-17 path)', () {
    late _MockDmRepository mockDmRepository;
    late VideoSharingService nip17Service;

    setUp(() {
      mockDmRepository = _MockDmRepository();
      when(() => mockDmRepository.userPubkey).thenReturn(_testPubkey);

      nip17Service = VideoSharingService(
        nostrService: mockNostrService,
        authService: mockAuthService,
        profileRepository: mockProfileRepository,
        dmRepository: mockDmRepository,
      );
    });

    test('uses NIP-17 when DmRepository is available', () async {
      when(() => mockAuthService.isAuthenticated).thenReturn(true);
      when(
        () => mockDmRepository.sendSharedVideo(
          recipientPubkey: any(named: 'recipientPubkey'),
          baseContent: any(named: 'baseContent'),
          videoKind: any(named: 'videoKind'),
          videoAuthorPubkey: any(named: 'videoAuthorPubkey'),
          videoDTag: any(named: 'videoDTag'),
          videoEventId: any(named: 'videoEventId'),
          relayHint: any(named: 'relayHint'),
          skipNip04Fallback: any(named: 'skipNip04Fallback'),
        ),
      ).thenAnswer(
        (_) async => NIP17SendResult.success(
          rumorEventId: 'nip17-rumor-id',
          messageEventId: 'nip17-msg-id',
          recipientPubkey: _recipientPubkey,
        ),
      );
      when(
        () => mockProfileRepository.fetchFreshProfile(
          pubkey: any(named: 'pubkey'),
        ),
      ).thenAnswer((_) async => null);

      final now = DateTime.now();
      final result = await nip17Service.shareVideoWithUser(
        video: VideoEvent(
          id: _testVideoId,
          pubkey: _testPubkey,
          createdAt: now.millisecondsSinceEpoch ~/ 1000,
          timestamp: now,
          content: 'Test',
        ),
        recipientPubkey: _recipientPubkey,
      );

      expect(result.success, isTrue);
      expect(result.messageEventId, equals('nip17-msg-id'));
      expect(result.conversationId, isNotNull);

      // Verify NIP-17 was used, NOT NIP-04, and that the plaintext kind-4
      // fallback is suppressed for shares (no sender↔recipient metadata leak).
      verify(
        () => mockDmRepository.sendSharedVideo(
          recipientPubkey: _recipientPubkey,
          baseContent: any(named: 'baseContent'),
          videoKind: any(named: 'videoKind'),
          videoAuthorPubkey: any(named: 'videoAuthorPubkey'),
          videoDTag: any(named: 'videoDTag'),
          videoEventId: any(named: 'videoEventId'),
          relayHint: any(named: 'relayHint'),
          skipNip04Fallback: true,
        ),
      ).called(1);
      verifyNever(
        () => mockAuthService.createAndSignEvent(
          kind: any(named: 'kind'),
          content: any(named: 'content'),
          tags: any(named: 'tags'),
        ),
      );
    });

    test(
      'shareVideoWithMultipleUsers: one recipient failing does not abort the '
      'rest, and each outcome is reported',
      () async {
        when(() => mockAuthService.isAuthenticated).thenReturn(true);
        when(
          () => mockProfileRepository.fetchFreshProfile(
            pubkey: any(named: 'pubkey'),
          ),
        ).thenAnswer((_) async => null);

        final goodA = 'a' * 64;
        final bad = 'b' * 64;
        final goodC = 'c' * 64;

        when(
          () => mockDmRepository.sendSharedVideo(
            recipientPubkey: any(named: 'recipientPubkey'),
            baseContent: any(named: 'baseContent'),
            videoKind: any(named: 'videoKind'),
            videoAuthorPubkey: any(named: 'videoAuthorPubkey'),
            videoDTag: any(named: 'videoDTag'),
            videoEventId: any(named: 'videoEventId'),
            relayHint: any(named: 'relayHint'),
            skipNip04Fallback: any(named: 'skipNip04Fallback'),
          ),
        ).thenAnswer((invocation) async {
          final pubkey = invocation.namedArguments[#recipientPubkey] as String;
          if (pubkey == bad) throw StateError('boom');
          return NIP17SendResult.success(
            rumorEventId: 'rumor-$pubkey',
            messageEventId: 'msg-$pubkey',
            recipientPubkey: pubkey,
          );
        });

        final now = DateTime.now();
        final results = await nip17Service.shareVideoWithMultipleUsers(
          video: VideoEvent(
            id: _testVideoId,
            pubkey: _testPubkey,
            createdAt: now.millisecondsSinceEpoch ~/ 1000,
            timestamp: now,
            content: 'Test',
          ),
          recipientPubkeys: [goodA, bad, goodC],
        );

        // The middle recipient threw, but the loop still attempted all three
        // and reports a per-recipient result for each.
        expect(results.keys, containsAll(<String>[goodA, bad, goodC]));
        expect(results[goodA]!.success, isTrue);
        expect(results[bad]!.success, isFalse);
        expect(results[goodC]!.success, isTrue);
        verify(
          () => mockDmRepository.sendSharedVideo(
            recipientPubkey: goodC,
            baseContent: any(named: 'baseContent'),
            videoKind: any(named: 'videoKind'),
            videoAuthorPubkey: any(named: 'videoAuthorPubkey'),
            videoDTag: any(named: 'videoDTag'),
            videoEventId: any(named: 'videoEventId'),
            relayHint: any(named: 'relayHint'),
            skipNip04Fallback: any(named: 'skipNip04Fallback'),
          ),
        ).called(1);
      },
    );

    test(
      'returns success without waiting on the recents profile fetch (#5391)',
      () async {
        when(() => mockAuthService.isAuthenticated).thenReturn(true);
        when(
          () => mockDmRepository.sendSharedVideo(
            recipientPubkey: any(named: 'recipientPubkey'),
            baseContent: any(named: 'baseContent'),
            videoKind: any(named: 'videoKind'),
            videoAuthorPubkey: any(named: 'videoAuthorPubkey'),
            videoDTag: any(named: 'videoDTag'),
            videoEventId: any(named: 'videoEventId'),
            relayHint: any(named: 'relayHint'),
            skipNip04Fallback: any(named: 'skipNip04Fallback'),
          ),
        ).thenAnswer(
          (_) async => NIP17SendResult.success(
            rumorEventId: 'nip17-rumor-id',
            messageEventId: 'nip17-msg-id',
            recipientPubkey: _recipientPubkey,
          ),
        );
        // The post-send recents refresh must be fire-and-forget: a hung
        // profile fetch must NOT delay the success result (the toast).
        final neverCompletes = Completer<UserProfile?>();
        when(
          () => mockProfileRepository.fetchFreshProfile(
            pubkey: any(named: 'pubkey'),
          ),
        ).thenAnswer((_) => neverCompletes.future);

        final now = DateTime.now();
        final result = await nip17Service
            .shareVideoWithUser(
              video: VideoEvent(
                id: _testVideoId,
                pubkey: _testPubkey,
                createdAt: now.millisecondsSinceEpoch ~/ 1000,
                timestamp: now,
                content: 'Test',
              ),
              recipientPubkey: _recipientPubkey,
            )
            .timeout(const Duration(seconds: 2));

        expect(result.success, isTrue);
        expect(result.messageEventId, equals('nip17-msg-id'));
      },
    );

    test('returns failure when NIP-17 send fails', () async {
      when(() => mockAuthService.isAuthenticated).thenReturn(true);
      when(
        () => mockDmRepository.sendSharedVideo(
          recipientPubkey: any(named: 'recipientPubkey'),
          baseContent: any(named: 'baseContent'),
          videoKind: any(named: 'videoKind'),
          videoAuthorPubkey: any(named: 'videoAuthorPubkey'),
          videoDTag: any(named: 'videoDTag'),
          videoEventId: any(named: 'videoEventId'),
          relayHint: any(named: 'relayHint'),
          skipNip04Fallback: any(named: 'skipNip04Fallback'),
        ),
      ).thenAnswer(
        (_) async => const NIP17SendResult.failure('Relay rejected'),
      );

      final now = DateTime.now();
      final result = await nip17Service.shareVideoWithUser(
        video: VideoEvent(
          id: _testVideoId,
          pubkey: _testPubkey,
          createdAt: now.millisecondsSinceEpoch ~/ 1000,
          timestamp: now,
          content: 'Test',
        ),
        recipientPubkey: _recipientPubkey,
      );

      expect(result.success, isFalse);
      expect(result.error, contains('Relay rejected'));
    });

    test('includes personal message in content', () async {
      when(() => mockAuthService.isAuthenticated).thenReturn(true);
      when(
        () => mockDmRepository.sendSharedVideo(
          recipientPubkey: any(named: 'recipientPubkey'),
          baseContent: any(named: 'baseContent'),
          videoKind: any(named: 'videoKind'),
          videoAuthorPubkey: any(named: 'videoAuthorPubkey'),
          videoDTag: any(named: 'videoDTag'),
          videoEventId: any(named: 'videoEventId'),
          relayHint: any(named: 'relayHint'),
          skipNip04Fallback: any(named: 'skipNip04Fallback'),
        ),
      ).thenAnswer(
        (_) async => NIP17SendResult.success(
          rumorEventId: 'nip17-rumor-id',
          messageEventId: 'nip17-msg-id',
          recipientPubkey: _recipientPubkey,
        ),
      );
      when(
        () => mockProfileRepository.fetchFreshProfile(
          pubkey: any(named: 'pubkey'),
        ),
      ).thenAnswer((_) async => null);

      final now = DateTime.now();
      await nip17Service.shareVideoWithUser(
        video: VideoEvent(
          id: _testVideoId,
          pubkey: _testPubkey,
          createdAt: now.millisecondsSinceEpoch ~/ 1000,
          timestamp: now,
          content: 'Test',
        ),
        recipientPubkey: _recipientPubkey,
        personalMessage: 'Check this out!',
      );

      final captured = verify(
        () => mockDmRepository.sendSharedVideo(
          recipientPubkey: any(named: 'recipientPubkey'),
          baseContent: captureAny(named: 'baseContent'),
          videoKind: any(named: 'videoKind'),
          videoAuthorPubkey: any(named: 'videoAuthorPubkey'),
          videoDTag: any(named: 'videoDTag'),
          videoEventId: any(named: 'videoEventId'),
          relayHint: any(named: 'relayHint'),
          skipNip04Fallback: any(named: 'skipNip04Fallback'),
        ),
      ).captured;

      expect(captured.first as String, contains('Check this out!'));
    });

    test('share message contains quoted title and share URL', () async {
      when(() => mockAuthService.isAuthenticated).thenReturn(true);
      when(
        () => mockDmRepository.sendSharedVideo(
          recipientPubkey: any(named: 'recipientPubkey'),
          baseContent: any(named: 'baseContent'),
          videoKind: any(named: 'videoKind'),
          videoAuthorPubkey: any(named: 'videoAuthorPubkey'),
          videoDTag: any(named: 'videoDTag'),
          videoEventId: any(named: 'videoEventId'),
          relayHint: any(named: 'relayHint'),
          skipNip04Fallback: any(named: 'skipNip04Fallback'),
        ),
      ).thenAnswer(
        (_) async => NIP17SendResult.success(
          rumorEventId: 'nip17-rumor-id',
          messageEventId: 'nip17-msg-id',
          recipientPubkey: _recipientPubkey,
        ),
      );
      when(
        () => mockProfileRepository.fetchFreshProfile(
          pubkey: any(named: 'pubkey'),
        ),
      ).thenAnswer((_) async => null);

      final now = DateTime.now();
      await nip17Service.shareVideoWithUser(
        video: VideoEvent(
          id: _testVideoId,
          pubkey: _testPubkey,
          createdAt: now.millisecondsSinceEpoch ~/ 1000,
          timestamp: now,
          content: 'Test',
          title: 'Indigenous cultures',
          vineId: 'indigenous-cultures',
          rawTags: const {'d': 'indigenous-cultures'},
        ),
        recipientPubkey: _recipientPubkey,
      );

      final captured = verify(
        () => mockDmRepository.sendSharedVideo(
          recipientPubkey: any(named: 'recipientPubkey'),
          baseContent: captureAny(named: 'baseContent'),
          videoKind: any(named: 'videoKind'),
          videoAuthorPubkey: any(named: 'videoAuthorPubkey'),
          videoDTag: any(named: 'videoDTag'),
          videoEventId: any(named: 'videoEventId'),
          relayHint: any(named: 'relayHint'),
          skipNip04Fallback: any(named: 'skipNip04Fallback'),
        ),
      ).captured;

      final message = captured.first as String;
      expect(message, contains('"Indigenous cultures"'));
      expect(message, contains('divine.video/video/'));
    });

    test('share message without title contains only share URL', () async {
      when(() => mockAuthService.isAuthenticated).thenReturn(true);
      when(
        () => mockDmRepository.sendSharedVideo(
          recipientPubkey: any(named: 'recipientPubkey'),
          baseContent: any(named: 'baseContent'),
          videoKind: any(named: 'videoKind'),
          videoAuthorPubkey: any(named: 'videoAuthorPubkey'),
          videoDTag: any(named: 'videoDTag'),
          videoEventId: any(named: 'videoEventId'),
          relayHint: any(named: 'relayHint'),
          skipNip04Fallback: any(named: 'skipNip04Fallback'),
        ),
      ).thenAnswer(
        (_) async => NIP17SendResult.success(
          rumorEventId: 'nip17-rumor-id',
          messageEventId: 'nip17-msg-id',
          recipientPubkey: _recipientPubkey,
        ),
      );
      when(
        () => mockProfileRepository.fetchFreshProfile(
          pubkey: any(named: 'pubkey'),
        ),
      ).thenAnswer((_) async => null);

      final now = DateTime.now();
      await nip17Service.shareVideoWithUser(
        video: VideoEvent(
          id: _testVideoId,
          pubkey: _testPubkey,
          createdAt: now.millisecondsSinceEpoch ~/ 1000,
          timestamp: now,
          content: 'Test',
          vineId: 'shareable-video',
          rawTags: const {'d': 'shareable-video'},
        ),
        recipientPubkey: _recipientPubkey,
      );

      final captured = verify(
        () => mockDmRepository.sendSharedVideo(
          recipientPubkey: any(named: 'recipientPubkey'),
          baseContent: captureAny(named: 'baseContent'),
          videoKind: any(named: 'videoKind'),
          videoAuthorPubkey: any(named: 'videoAuthorPubkey'),
          videoDTag: any(named: 'videoDTag'),
          videoEventId: any(named: 'videoEventId'),
          relayHint: any(named: 'relayHint'),
          skipNip04Fallback: any(named: 'skipNip04Fallback'),
        ),
      ).captured;

      final message = captured.first as String;
      expect(message, contains('divine.video/video/'));
      expect(message, isNot(contains('"')));
    });

    test('computes correct conversationId', () async {
      when(() => mockAuthService.isAuthenticated).thenReturn(true);
      when(
        () => mockDmRepository.sendSharedVideo(
          recipientPubkey: any(named: 'recipientPubkey'),
          baseContent: any(named: 'baseContent'),
          videoKind: any(named: 'videoKind'),
          videoAuthorPubkey: any(named: 'videoAuthorPubkey'),
          videoDTag: any(named: 'videoDTag'),
          videoEventId: any(named: 'videoEventId'),
          relayHint: any(named: 'relayHint'),
          skipNip04Fallback: any(named: 'skipNip04Fallback'),
        ),
      ).thenAnswer(
        (_) async => NIP17SendResult.success(
          rumorEventId: 'nip17-rumor-id',
          messageEventId: 'nip17-msg-id',
          recipientPubkey: _recipientPubkey,
        ),
      );
      when(
        () => mockProfileRepository.fetchFreshProfile(
          pubkey: any(named: 'pubkey'),
        ),
      ).thenAnswer((_) async => null);

      final now = DateTime.now();
      final result = await nip17Service.shareVideoWithUser(
        video: VideoEvent(
          id: _testVideoId,
          pubkey: _testPubkey,
          createdAt: now.millisecondsSinceEpoch ~/ 1000,
          timestamp: now,
          content: 'Test',
        ),
        recipientPubkey: _recipientPubkey,
      );

      // Verify conversation ID matches DmRepository computation
      final participants = [_testPubkey, _recipientPubkey]..sort();
      final expectedId = DmRepository.computeConversationId(participants);
      expect(result.conversationId, equals(expectedId));
    });

    test('updates sharing history on NIP-17 success', () async {
      when(() => mockAuthService.isAuthenticated).thenReturn(true);
      when(
        () => mockDmRepository.sendSharedVideo(
          recipientPubkey: any(named: 'recipientPubkey'),
          baseContent: any(named: 'baseContent'),
          videoKind: any(named: 'videoKind'),
          videoAuthorPubkey: any(named: 'videoAuthorPubkey'),
          videoDTag: any(named: 'videoDTag'),
          videoEventId: any(named: 'videoEventId'),
          relayHint: any(named: 'relayHint'),
          skipNip04Fallback: any(named: 'skipNip04Fallback'),
        ),
      ).thenAnswer(
        (_) async => NIP17SendResult.success(
          rumorEventId: 'nip17-rumor-id',
          messageEventId: 'nip17-msg-id',
          recipientPubkey: _recipientPubkey,
        ),
      );
      when(
        () => mockProfileRepository.fetchFreshProfile(
          pubkey: any(named: 'pubkey'),
        ),
      ).thenAnswer((_) async => null);

      final now = DateTime.now();
      await nip17Service.shareVideoWithUser(
        video: VideoEvent(
          id: _testVideoId,
          pubkey: _testPubkey,
          createdAt: now.millisecondsSinceEpoch ~/ 1000,
          timestamp: now,
          content: 'Test',
        ),
        recipientPubkey: _recipientPubkey,
      );

      expect(nip17Service.hasSharedWithRecently(_recipientPubkey), isTrue);
    });
  });

  group('sharing utilities', () {
    test('generateShareUrl uses stableId when video has a d tag', () {
      final now = DateTime.now();
      final video = VideoEvent(
        id: _testVideoId,
        pubkey: _testPubkey,
        createdAt: now.millisecondsSinceEpoch ~/ 1000,
        timestamp: now,
        content: 'Test',
        vineId: 'my-vine-id',
        rawTags: const {'d': 'my-vine-id'},
      );

      final url = service.generateShareUrl(video);

      expect(url, equals('https://divine.video/video/my-vine-id'));
    });

    test('generateShareUrl falls back to event id when d tag is missing', () {
      final now = DateTime.now();
      const eventId =
          'a695f6b60119d9521934a691347d9f78e8770b56da16bb255ee77ac112b4c1f6';
      final video = VideoEvent(
        id: eventId,
        pubkey: _testPubkey,
        createdAt: now.millisecondsSinceEpoch ~/ 1000,
        timestamp: now,
        content: 'Test',
        vineId: eventId,
      );

      final url = service.generateShareUrl(video);

      // Always emits an https URL — never a nostr: URI. The route
      // handler accepts raw event IDs as well as d-tags / NIP-19 refs.
      expect(url, equals('https://divine.video/video/$eventId'));
    });

    test('hasSharedWithRecently returns false for unknown user', () {
      expect(service.hasSharedWithRecently('unknown'), isFalse);
    });

    test('hasSharedWithRecently returns true after sharing', () async {
      // Arrange
      when(() => mockAuthService.isAuthenticated).thenReturn(true);
      when(
        () => mockAuthService.createAndSignEvent(
          kind: any(named: 'kind'),
          content: any(named: 'content'),
          tags: any(named: 'tags'),
        ),
      ).thenAnswer(
        (_) async => Event(_testPubkey, 4, <List<String>>[], 'test'),
      );
      when(() => mockNostrService.publishEvent(any())).thenAnswer(
        (_) async => PublishSuccess(
          event: Event(_testPubkey, 4, <List<String>>[], 'test'),
        ),
      );
      when(
        () => mockProfileRepository.fetchFreshProfile(
          pubkey: any(named: 'pubkey'),
        ),
      ).thenAnswer((_) async => null);

      final now = DateTime.now();
      await service.shareVideoWithUser(
        video: VideoEvent(
          id: _testVideoId,
          pubkey: _testPubkey,
          createdAt: now.millisecondsSinceEpoch ~/ 1000,
          timestamp: now,
          content: 'Test',
        ),
        recipientPubkey: _recipientPubkey,
      );

      expect(service.hasSharedWithRecently(_recipientPubkey), isTrue);
    });

    test('clearSharingHistory removes all data', () async {
      // Arrange - populate some history
      when(() => mockAuthService.isAuthenticated).thenReturn(true);
      when(
        () => mockAuthService.createAndSignEvent(
          kind: any(named: 'kind'),
          content: any(named: 'content'),
          tags: any(named: 'tags'),
        ),
      ).thenAnswer(
        (_) async => Event(_testPubkey, 4, <List<String>>[], 'test'),
      );
      when(() => mockNostrService.publishEvent(any())).thenAnswer(
        (_) async => PublishSuccess(
          event: Event(_testPubkey, 4, <List<String>>[], 'test'),
        ),
      );
      when(
        () => mockProfileRepository.fetchFreshProfile(
          pubkey: any(named: 'pubkey'),
        ),
      ).thenAnswer((_) async => null);

      final now = DateTime.now();
      await service.shareVideoWithUser(
        video: VideoEvent(
          id: _testVideoId,
          pubkey: _testPubkey,
          createdAt: now.millisecondsSinceEpoch ~/ 1000,
          timestamp: now,
          content: 'Test',
        ),
        recipientPubkey: _recipientPubkey,
      );

      // Act
      service.clearSharingHistory();

      // Assert
      expect(service.recentlySharedWith, isEmpty);
      expect(service.hasSharedWithRecently(_recipientPubkey), isFalse);

      final shareableUsers = await service.getShareableUsers();
      expect(shareableUsers, isEmpty);
    });
  });
}
