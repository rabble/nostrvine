// ABOUTME: Unit tests for FollowRepository
// ABOUTME: Tests follow/unfollow operations, caching, and network sync

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:openvine/repositories/follow_repository.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/nostr_service_interface.dart';
import 'package:openvine/services/personal_event_cache_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

@GenerateMocks([INostrService, AuthService, PersonalEventCacheService])
import 'follow_repository_test.mocks.dart';

void main() {
  group('FollowRepository', () {
    late FollowRepository repository;
    late MockINostrService mockNostrService;
    late MockAuthService mockAuthService;
    late MockPersonalEventCacheService mockPersonalEventCache;

    // Valid 64-character hex pubkeys for testing
    const testCurrentUserPubkey =
        'a1b2c3d4e5f6789012345678901234567890abcdef123456789012345678901234';
    const testTargetPubkey =
        'b2c3d4e5f6789012345678901234567890abcdef123456789012345678901234a1';
    const testTargetPubkey2 =
        'c3d4e5f6789012345678901234567890abcdef123456789012345678901234ab12';

    setUp(() async {
      SharedPreferences.setMockInitialValues({});

      mockNostrService = MockINostrService();
      mockAuthService = MockAuthService();
      mockPersonalEventCache = MockPersonalEventCacheService();

      // Default auth setup
      when(mockAuthService.isAuthenticated).thenReturn(true);
      when(
        mockAuthService.currentPublicKeyHex,
      ).thenReturn(testCurrentUserPubkey);

      // Default nostr service setup - return empty stream
      when(
        mockNostrService.subscribeToEvents(
          filters: anyNamed('filters'),
          bypassLimits: anyNamed('bypassLimits'),
          onEose: anyNamed('onEose'),
        ),
      ).thenAnswer((_) => const Stream<Event>.empty());

      // Default personal event cache setup
      when(mockPersonalEventCache.isInitialized).thenReturn(false);

      repository = FollowRepository(
        nostrService: mockNostrService,
        authService: mockAuthService,
        personalEventCache: mockPersonalEventCache,
      );
    });

    tearDown(() {
      repository.dispose();
    });

    group('initialization', () {
      test('initializes with empty following list', () async {
        await repository.initialize();

        expect(repository.isInitialized, isTrue);
        expect(repository.followingCount, 0);
        expect(repository.followingPubkeys, isEmpty);
      });

      test('loads following list from local storage', () async {
        // Pre-populate SharedPreferences with cached data
        SharedPreferences.setMockInitialValues({
          'following_list_$testCurrentUserPubkey':
              '["$testTargetPubkey", "$testTargetPubkey2"]',
        });

        // Recreate repository to pick up the cached data
        repository = FollowRepository(
          nostrService: mockNostrService,
          authService: mockAuthService,
          personalEventCache: mockPersonalEventCache,
        );

        await repository.initialize();

        expect(repository.followingCount, 2);
        expect(repository.isFollowing(testTargetPubkey), isTrue);
        expect(repository.isFollowing(testTargetPubkey2), isTrue);
      });

      test('does not reinitialize if already initialized', () async {
        await repository.initialize();
        expect(repository.isInitialized, isTrue);

        // Second call should return immediately
        await repository.initialize();
        expect(repository.isInitialized, isTrue);

        // Verify subscribeToEvents was only called once during first init
        verify(
          mockNostrService.subscribeToEvents(
            filters: anyNamed('filters'),
            bypassLimits: anyNamed('bypassLimits'),
            onEose: anyNamed('onEose'),
          ),
        ).called(1);
      });
    });

    group('isFollowing', () {
      test('returns false for unfollowed user', () async {
        await repository.initialize();

        expect(repository.isFollowing(testTargetPubkey), isFalse);
      });

      test('returns true for followed user', () async {
        SharedPreferences.setMockInitialValues({
          'following_list_$testCurrentUserPubkey': '["$testTargetPubkey"]',
        });

        await repository.initialize();

        expect(repository.isFollowing(testTargetPubkey), isTrue);
      });
    });

    group('follow', () {
      test('throws when not authenticated', () async {
        when(mockAuthService.isAuthenticated).thenReturn(false);

        await repository.initialize();

        expect(
          () => repository.follow(testTargetPubkey),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('not authenticated'),
            ),
          ),
        );
      });

      test('does nothing when already following', () async {
        SharedPreferences.setMockInitialValues({
          'following_list_$testCurrentUserPubkey': '["$testTargetPubkey"]',
        });

        await repository.initialize();

        expect(repository.isFollowing(testTargetPubkey), isTrue);
        expect(repository.followingCount, 1);

        await repository.follow(testTargetPubkey);

        expect(repository.followingCount, 1);
      });

      test('successfully follows a user', () async {
        final mockEvent = Event.fromJson({
          'id': testCurrentUserPubkey,
          'pubkey': testCurrentUserPubkey,
          'created_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
          'kind': 3,
          'tags': [
            ['p', testTargetPubkey],
          ],
          'content': '',
          'sig': '${testCurrentUserPubkey}${testCurrentUserPubkey}',
        });

        when(
          mockAuthService.createAndSignEvent(
            kind: anyNamed('kind'),
            content: anyNamed('content'),
            tags: anyNamed('tags'),
          ),
        ).thenAnswer((_) async => mockEvent);

        when(mockNostrService.broadcastEvent(any)).thenAnswer(
          (_) async => NostrBroadcastResult(
            event: mockEvent,
            successCount: 1,
            totalRelays: 1,
            results: {'relay1': true},
            errors: {},
          ),
        );
        await repository.initialize();
        expect(repository.isFollowing(testTargetPubkey), isFalse);
        await repository.follow(testTargetPubkey);
        expect(repository.isFollowing(testTargetPubkey), isTrue);
        expect(repository.followingCount, 1);
      });

      test('rolls back on broadcast failure', () async {
        final mockEvent = Event.fromJson({
          'id': testCurrentUserPubkey,
          'pubkey': testCurrentUserPubkey,
          'created_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
          'kind': 3,
          'tags': [
            ['p', testTargetPubkey],
          ],
          'content': '',
          'sig': '${testCurrentUserPubkey}${testCurrentUserPubkey}',
        });

        when(
          mockAuthService.createAndSignEvent(
            kind: anyNamed('kind'),
            content: anyNamed('content'),
            tags: anyNamed('tags'),
          ),
        ).thenAnswer((_) async => mockEvent);

        when(mockNostrService.broadcastEvent(any)).thenAnswer(
          (_) async => NostrBroadcastResult(
            event: mockEvent,
            successCount: 0,
            totalRelays: 1,
            results: {'relay1': false},
            errors: {'relay1': 'Connection failed'},
          ),
        );

        await repository.initialize();
        expect(repository.isFollowing(testTargetPubkey), isFalse);
        await expectLater(
          repository.follow(testTargetPubkey),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('Failed to broadcast'),
            ),
          ),
        );

        expect(repository.isFollowing(testTargetPubkey), isFalse);
        expect(repository.followingCount, 0);
      });
    });

    group('unfollow', () {
      test('throws when not authenticated', () async {
        when(mockAuthService.isAuthenticated).thenReturn(false);

        await repository.initialize();

        expect(
          () => repository.unfollow(testTargetPubkey),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('not authenticated'),
            ),
          ),
        );
      });

      test('does nothing when not following', () async {
        await repository.initialize();
        await repository.unfollow(testTargetPubkey);
        expect(repository.followingCount, 0);
      });

      test('successfully unfollows a user', () async {
        SharedPreferences.setMockInitialValues({
          'following_list_$testCurrentUserPubkey': '["$testTargetPubkey"]',
        });

        final mockEvent = Event.fromJson({
          'id': testCurrentUserPubkey,
          'pubkey': testCurrentUserPubkey,
          'created_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
          'kind': 3,
          'tags': <List<String>>[], // Empty tags after unfollow
          'content': '',
          'sig': '${testCurrentUserPubkey}${testCurrentUserPubkey}',
        });

        when(
          mockAuthService.createAndSignEvent(
            kind: anyNamed('kind'),
            content: anyNamed('content'),
            tags: anyNamed('tags'),
          ),
        ).thenAnswer((_) async => mockEvent);

        when(mockNostrService.broadcastEvent(any)).thenAnswer(
          (_) async => NostrBroadcastResult(
            event: mockEvent,
            successCount: 1,
            totalRelays: 1,
            results: {'relay1': true},
            errors: {},
          ),
        );

        await repository.initialize();
        expect(repository.isFollowing(testTargetPubkey), isTrue);
        expect(repository.followingCount, 1);

        await repository.unfollow(testTargetPubkey);

        expect(repository.isFollowing(testTargetPubkey), isFalse);
        expect(repository.followingCount, 0);
      });

      test('rolls back on broadcast failure', () async {
        // Pre-populate with followed user
        SharedPreferences.setMockInitialValues({
          'following_list_$testCurrentUserPubkey': '["$testTargetPubkey"]',
        });

        final mockEvent = Event.fromJson({
          'id': testCurrentUserPubkey,
          'pubkey': testCurrentUserPubkey,
          'created_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
          'kind': 3,
          'tags': <List<String>>[],
          'content': '',
          'sig': '${testCurrentUserPubkey}${testCurrentUserPubkey}',
        });

        when(
          mockAuthService.createAndSignEvent(
            kind: anyNamed('kind'),
            content: anyNamed('content'),
            tags: anyNamed('tags'),
          ),
        ).thenAnswer((_) async => mockEvent);

        when(mockNostrService.broadcastEvent(any)).thenAnswer(
          (_) async => NostrBroadcastResult(
            event: mockEvent,
            successCount: 0,
            totalRelays: 1,
            results: {'relay1': false},
            errors: {'relay1': 'Connection failed'},
          ),
        );

        await repository.initialize();
        expect(repository.isFollowing(testTargetPubkey), isTrue);
        expect(repository.followingCount, 1);

        await expectLater(
          repository.unfollow(testTargetPubkey),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('Failed to broadcast'),
            ),
          ),
        );

        // Should have rolled back
        expect(repository.isFollowing(testTargetPubkey), isTrue);
        expect(repository.followingCount, 1);
      });
    });

    group('followingStream', () {
      test('is a broadcast stream', () {
        expect(repository.followingStream.isBroadcast, isTrue);
      });

      test('emits updated list when follow succeeds', () async {
        final mockEvent = Event.fromJson({
          'id': testCurrentUserPubkey,
          'pubkey': testCurrentUserPubkey,
          'created_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
          'kind': 3,
          'tags': [
            ['p', testTargetPubkey],
          ],
          'content': '',
          'sig': '${testCurrentUserPubkey}${testCurrentUserPubkey}',
        });

        when(
          mockAuthService.createAndSignEvent(
            kind: anyNamed('kind'),
            content: anyNamed('content'),
            tags: anyNamed('tags'),
          ),
        ).thenAnswer((_) async => mockEvent);

        when(mockNostrService.broadcastEvent(any)).thenAnswer(
          (_) async => NostrBroadcastResult(
            event: mockEvent,
            successCount: 1,
            totalRelays: 1,
            results: {'relay1': true},
            errors: {},
          ),
        );

        await repository.initialize();

        final emittedValues = <List<String>>[];
        final subscription =
            repository.followingStream.listen(emittedValues.add);

        await repository.follow(testTargetPubkey);
        await Future<void>.delayed(Duration.zero);

        expect(emittedValues.length, greaterThanOrEqualTo(1));
        expect(emittedValues.last, contains(testTargetPubkey));

        await subscription.cancel();
      });

      test('emits updated list when unfollow succeeds', () async {
        SharedPreferences.setMockInitialValues({
          'following_list_$testCurrentUserPubkey': '["$testTargetPubkey"]',
        });

        final mockEvent = Event.fromJson({
          'id': testCurrentUserPubkey,
          'pubkey': testCurrentUserPubkey,
          'created_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
          'kind': 3,
          'tags': <List<String>>[],
          'content': '',
          'sig': '${testCurrentUserPubkey}${testCurrentUserPubkey}',
        });

        when(
          mockAuthService.createAndSignEvent(
            kind: anyNamed('kind'),
            content: anyNamed('content'),
            tags: anyNamed('tags'),
          ),
        ).thenAnswer((_) async => mockEvent);

        when(mockNostrService.broadcastEvent(any)).thenAnswer(
          (_) async => NostrBroadcastResult(
            event: mockEvent,
            successCount: 1,
            totalRelays: 1,
            results: {'relay1': true},
            errors: {},
          ),
        );

        await repository.initialize();

        final emittedValues = <List<String>>[];
        final subscription =
            repository.followingStream.listen(emittedValues.add);

        await repository.unfollow(testTargetPubkey);
        await Future<void>.delayed(Duration.zero);

        expect(emittedValues.length, greaterThanOrEqualTo(1));
        expect(emittedValues.last, isNot(contains(testTargetPubkey)));

        await subscription.cancel();
      });
    });

    group('dispose', () {
      test('closes the stream controller', () async {
        await repository.initialize();

        repository.dispose();

        expect(
          () => repository.followingStream.listen((_) {}),
          returnsNormally,
        );
      });
    });
  });
}
