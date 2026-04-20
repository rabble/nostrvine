// ABOUTME: Tests for VideoSharingService NIP-17 share flow
// ABOUTME: Covers shareVideoWithUser, getShareableUsers,
// ABOUTME: searchUsersToShareWith, and sharing utilities.

import 'package:dm_repository/dm_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/services/auth_service.dart' hide UserProfile;
import 'package:openvine/services/video_sharing_service.dart';
import 'package:profile_repository/profile_repository.dart';

class _MockAuthService extends Mock implements AuthService {}

class _MockProfileRepository extends Mock implements ProfileRepository {}

class _MockDmRepository extends Mock implements DmRepository {}

const _testPubkey =
    'a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2';

const _recipientPubkey =
    'b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2c3';

NIP17SendResult _successResult() => NIP17SendResult.success(
  rumorEventId: 'nip17-rumor-id',
  messageEventId: 'nip17-msg-id',
  recipientPubkey: _recipientPubkey,
);

VideoEvent _video({String? title}) {
  final now = DateTime.now();
  return VideoEvent(
    id: 'video1',
    pubkey: _testPubkey,
    createdAt: now.millisecondsSinceEpoch ~/ 1000,
    timestamp: now,
    content: 'Test video',
    title: title,
  );
}

void main() {
  late VideoSharingService service;
  late _MockAuthService mockAuthService;
  late _MockProfileRepository mockProfileRepository;
  late _MockDmRepository mockDmRepository;

  setUp(() {
    mockAuthService = _MockAuthService();
    mockProfileRepository = _MockProfileRepository();
    mockDmRepository = _MockDmRepository();

    when(() => mockDmRepository.userPubkey).thenReturn(_testPubkey);

    service = VideoSharingService(
      authService: mockAuthService,
      profileRepository: mockProfileRepository,
      dmRepository: mockDmRepository,
    );
  });

  group('getShareableUsers', () {
    test('returns empty list when no recent shares exist', () async {
      final result = await service.getShareableUsers();

      expect(result, isEmpty);
    });

    test('returns recently shared users after sharing', () async {
      when(() => mockAuthService.isAuthenticated).thenReturn(true);
      when(
        () => mockDmRepository.sendMessage(
          recipientPubkey: any(named: 'recipientPubkey'),
          content: any(named: 'content'),
        ),
      ).thenAnswer((_) async => _successResult());
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

      await service.shareVideoWithUser(
        video: _video(),
        recipientPubkey: _recipientPubkey,
      );

      final result = await service.getShareableUsers();

      expect(result, hasLength(1));
      expect(result[0].pubkey, _recipientPubkey);
      expect(result[0].displayName, 'Alice');
      expect(result[0].picture, 'https://example.com/alice.jpg');
    });

    test('respects limit parameter', () async {
      when(() => mockAuthService.isAuthenticated).thenReturn(true);
      when(
        () => mockDmRepository.sendMessage(
          recipientPubkey: any(named: 'recipientPubkey'),
          content: any(named: 'content'),
        ),
      ).thenAnswer((_) async => _successResult());
      when(
        () => mockProfileRepository.fetchFreshProfile(
          pubkey: any(named: 'pubkey'),
        ),
      ).thenAnswer((_) async => null);

      for (var i = 0; i < 6; i++) {
        final hexI = i.toRadixString(16).padLeft(64, '0');
        await service.shareVideoWithUser(
          video: _video(),
          recipientPubkey: hexI,
        );
      }

      final result = await service.getShareableUsers(limit: 3);

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

        expect(result, hasLength(1));
        expect(result[0].pubkey, hexPubkey);
        expect(result[0].displayName, isNull);
      },
    );

    test('returns empty list for non-hex text queries', () async {
      final result = await service.searchUsersToShareWith('alice');

      expect(result, isEmpty);
    });

    test('returns empty list for short hex-like queries', () async {
      final result = await service.searchUsersToShareWith('abcdef');

      expect(result, isEmpty);
    });
  });

  group('shareVideoWithUser', () {
    test('returns failure when user is not authenticated', () async {
      when(() => mockAuthService.isAuthenticated).thenReturn(false);

      final result = await service.shareVideoWithUser(
        video: _video(),
        recipientPubkey: _recipientPubkey,
      );

      expect(result.success, isFalse);
      expect(result.error, contains('not authenticated'));
    });

    test('uses NIP-17 via DmRepository.sendMessage', () async {
      when(() => mockAuthService.isAuthenticated).thenReturn(true);
      when(
        () => mockDmRepository.sendMessage(
          recipientPubkey: any(named: 'recipientPubkey'),
          content: any(named: 'content'),
        ),
      ).thenAnswer((_) async => _successResult());
      when(
        () => mockProfileRepository.fetchFreshProfile(
          pubkey: any(named: 'pubkey'),
        ),
      ).thenAnswer((_) async => null);

      final result = await service.shareVideoWithUser(
        video: _video(),
        recipientPubkey: _recipientPubkey,
      );

      expect(result.success, isTrue);
      expect(result.messageEventId, equals('nip17-msg-id'));
      expect(result.conversationId, isNotNull);

      verify(
        () => mockDmRepository.sendMessage(
          recipientPubkey: _recipientPubkey,
          content: any(named: 'content'),
        ),
      ).called(1);
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

      final result = await service.shareVideoWithUser(
        video: _video(),
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
      ).thenAnswer((_) async => _successResult());
      when(
        () => mockProfileRepository.fetchFreshProfile(
          pubkey: any(named: 'pubkey'),
        ),
      ).thenAnswer((_) async => null);

      await service.shareVideoWithUser(
        video: _video(),
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
      ).thenAnswer((_) async => _successResult());
      when(
        () => mockProfileRepository.fetchFreshProfile(
          pubkey: any(named: 'pubkey'),
        ),
      ).thenAnswer((_) async => null);

      await service.shareVideoWithUser(
        video: _video(title: 'Indigenous cultures'),
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
      ).thenAnswer((_) async => _successResult());
      when(
        () => mockProfileRepository.fetchFreshProfile(
          pubkey: any(named: 'pubkey'),
        ),
      ).thenAnswer((_) async => null);

      await service.shareVideoWithUser(
        video: _video(),
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
      ).thenAnswer((_) async => _successResult());
      when(
        () => mockProfileRepository.fetchFreshProfile(
          pubkey: any(named: 'pubkey'),
        ),
      ).thenAnswer((_) async => null);

      final result = await service.shareVideoWithUser(
        video: _video(),
        recipientPubkey: _recipientPubkey,
      );

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
      ).thenAnswer((_) async => _successResult());
      when(
        () => mockProfileRepository.fetchFreshProfile(
          pubkey: any(named: 'pubkey'),
        ),
      ).thenAnswer((_) async => null);

      await service.shareVideoWithUser(
        video: _video(),
        recipientPubkey: _recipientPubkey,
      );

      expect(service.hasSharedWithRecently(_recipientPubkey), isTrue);
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

      expect(url, equals('https://divine.video/video/my-vine-id'));
    });

    test('hasSharedWithRecently returns false for unknown user', () {
      expect(service.hasSharedWithRecently('unknown'), isFalse);
    });

    test('hasSharedWithRecently returns true after sharing', () async {
      when(() => mockAuthService.isAuthenticated).thenReturn(true);
      when(
        () => mockDmRepository.sendMessage(
          recipientPubkey: any(named: 'recipientPubkey'),
          content: any(named: 'content'),
        ),
      ).thenAnswer((_) async => _successResult());
      when(
        () => mockProfileRepository.fetchFreshProfile(
          pubkey: any(named: 'pubkey'),
        ),
      ).thenAnswer((_) async => null);

      await service.shareVideoWithUser(
        video: _video(),
        recipientPubkey: _recipientPubkey,
      );

      expect(service.hasSharedWithRecently(_recipientPubkey), isTrue);
    });

    test('clearSharingHistory removes all data', () async {
      when(() => mockAuthService.isAuthenticated).thenReturn(true);
      when(
        () => mockDmRepository.sendMessage(
          recipientPubkey: any(named: 'recipientPubkey'),
          content: any(named: 'content'),
        ),
      ).thenAnswer((_) async => _successResult());
      when(
        () => mockProfileRepository.fetchFreshProfile(
          pubkey: any(named: 'pubkey'),
        ),
      ).thenAnswer((_) async => null);

      await service.shareVideoWithUser(
        video: _video(),
        recipientPubkey: _recipientPubkey,
      );

      service.clearSharingHistory();

      expect(service.recentlySharedWith, isEmpty);
      expect(service.hasSharedWithRecently(_recipientPubkey), isFalse);

      final shareableUsers = await service.getShareableUsers();
      expect(shareableUsers, isEmpty);
    });
  });
}
