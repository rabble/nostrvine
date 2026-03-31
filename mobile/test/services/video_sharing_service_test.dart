// ABOUTME: Tests for VideoSharingService social features integration
// ABOUTME: Covers NIP-17 share path, NIP-04 fallback, getShareableUsers,
// ABOUTME: searchUsersToShareWith, shareVideoWithUser, and sharing utilities.

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:openvine/repositories/dm_repository.dart';
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
        (_) async => Event(_testPubkey, 4, <List<String>>[], 'test'),
      );
      when(
        () => mockProfileRepository.fetchFreshProfile(
          pubkey: _recipientPubkey,
        ),
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
        id: 'video1',
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
        (_) async => Event(_testPubkey, 4, <List<String>>[], 'test'),
      );
      when(
        () => mockProfileRepository.fetchFreshProfile(
          pubkey: any(named: 'pubkey'),
        ),
      ).thenAnswer((_) async => null);

      final now = DateTime.now();
      final testVideo = VideoEvent(
        id: 'video1',
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
          id: 'video1',
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
          id: 'video1',
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
      ).thenAnswer((_) async => signedEvent);
      when(
        () => mockProfileRepository.fetchFreshProfile(
          pubkey: any(named: 'pubkey'),
        ),
      ).thenAnswer((_) async => null);

      final now = DateTime.now();
      final result = await service.shareVideoWithUser(
        video: VideoEvent(
          id: 'video1',
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
      ).thenAnswer((_) async => null);

      final now = DateTime.now();
      final result = await service.shareVideoWithUser(
        video: VideoEvent(
          id: 'video1',
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
        () => mockDmRepository.sendMessage(
          recipientPubkey: any(named: 'recipientPubkey'),
          content: any(named: 'content'),
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
          id: 'video1',
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

      // Verify NIP-17 was used, NOT NIP-04
      verify(
        () => mockDmRepository.sendMessage(
          recipientPubkey: _recipientPubkey,
          content: any(named: 'content'),
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

    test('returns failure when NIP-17 send fails', () async {
      when(() => mockAuthService.isAuthenticated).thenReturn(true);
      when(
        () => mockDmRepository.sendMessage(
          recipientPubkey: any(named: 'recipientPubkey'),
          content: any(named: 'content'),
        ),
      ).thenAnswer(
        (_) async => NIP17SendResult.failure('Relay rejected'),
      );

      final now = DateTime.now();
      final result = await nip17Service.shareVideoWithUser(
        video: VideoEvent(
          id: 'video1',
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
        () => mockDmRepository.sendMessage(
          recipientPubkey: any(named: 'recipientPubkey'),
          content: any(named: 'content'),
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
          id: 'video1',
          pubkey: _testPubkey,
          createdAt: now.millisecondsSinceEpoch ~/ 1000,
          timestamp: now,
          content: 'Test',
        ),
        recipientPubkey: _recipientPubkey,
        personalMessage: 'Check this out!',
      );

      final captured = verify(
        () => mockDmRepository.sendMessage(
          recipientPubkey: any(named: 'recipientPubkey'),
          content: captureAny(named: 'content'),
        ),
      ).captured;

      expect(captured.first as String, contains('Check this out!'));
    });

    test('share message contains quoted title and share URL', () async {
      when(() => mockAuthService.isAuthenticated).thenReturn(true);
      when(
        () => mockDmRepository.sendMessage(
          recipientPubkey: any(named: 'recipientPubkey'),
          content: any(named: 'content'),
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
          id: 'video1',
          pubkey: _testPubkey,
          createdAt: now.millisecondsSinceEpoch ~/ 1000,
          timestamp: now,
          content: 'Test',
          title: 'Indigenous cultures',
        ),
        recipientPubkey: _recipientPubkey,
      );

      final captured = verify(
        () => mockDmRepository.sendMessage(
          recipientPubkey: any(named: 'recipientPubkey'),
          content: captureAny(named: 'content'),
        ),
      ).captured;

      final message = captured.first as String;
      expect(message, contains('"Indigenous cultures"'));
      expect(message, contains('divine.video/video/'));
    });

    test('share message without title contains only share URL', () async {
      when(() => mockAuthService.isAuthenticated).thenReturn(true);
      when(
        () => mockDmRepository.sendMessage(
          recipientPubkey: any(named: 'recipientPubkey'),
          content: any(named: 'content'),
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
          id: 'video1',
          pubkey: _testPubkey,
          createdAt: now.millisecondsSinceEpoch ~/ 1000,
          timestamp: now,
          content: 'Test',
        ),
        recipientPubkey: _recipientPubkey,
      );

      final captured = verify(
        () => mockDmRepository.sendMessage(
          recipientPubkey: any(named: 'recipientPubkey'),
          content: captureAny(named: 'content'),
        ),
      ).captured;

      final message = captured.first as String;
      expect(message, contains('divine.video/video/'));
      expect(message, isNot(contains('"')));
    });

    test('computes correct conversationId', () async {
      when(() => mockAuthService.isAuthenticated).thenReturn(true);
      when(
        () => mockDmRepository.sendMessage(
          recipientPubkey: any(named: 'recipientPubkey'),
          content: any(named: 'content'),
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
          id: 'video1',
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
        () => mockDmRepository.sendMessage(
          recipientPubkey: any(named: 'recipientPubkey'),
          content: any(named: 'content'),
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
          id: 'video1',
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
    test('generateShareUrl uses stableId', () {
      final now = DateTime.now();
      final video = VideoEvent(
        id: 'video1',
        pubkey: _testPubkey,
        createdAt: now.millisecondsSinceEpoch ~/ 1000,
        timestamp: now,
        content: 'Test',
        vineId: 'my-vine-id',
      );

      final url = service.generateShareUrl(video);

      // stableId returns vineId when set, otherwise falls back to id
      expect(url, equals('https://divine.video/video/my-vine-id'));
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
        (_) async => Event(_testPubkey, 4, <List<String>>[], 'test'),
      );
      when(
        () => mockProfileRepository.fetchFreshProfile(
          pubkey: any(named: 'pubkey'),
        ),
      ).thenAnswer((_) async => null);

      final now = DateTime.now();
      await service.shareVideoWithUser(
        video: VideoEvent(
          id: 'video1',
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
        (_) async => Event(_testPubkey, 4, <List<String>>[], 'test'),
      );
      when(
        () => mockProfileRepository.fetchFreshProfile(
          pubkey: any(named: 'pubkey'),
        ),
      ).thenAnswer((_) async => null);

      final now = DateTime.now();
      await service.shareVideoWithUser(
        video: VideoEvent(
          id: 'video1',
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
