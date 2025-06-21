import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:nostr/nostr.dart';
import 'package:nostrvine_app/services/social_service.dart';
import 'package:nostrvine_app/services/nostr_service_interface.dart';
import 'package:nostrvine_app/services/auth_service.dart';

// Generate mocks
@GenerateMocks([INostrService, AuthService])
import 'social_service_test.mocks.dart';

void main() {
  group('SocialService', () {
    late SocialService socialService;
    late MockINostrService mockNostrService;
    late MockAuthService mockAuthService;

    setUp(() {
      mockNostrService = MockINostrService();
      mockAuthService = MockAuthService();
      
      // Set up default stubs for AuthService
      when(mockAuthService.isAuthenticated).thenReturn(true);
      when(mockAuthService.currentPublicKeyHex).thenReturn('test_user_pubkey');
      
      // Set up default stubs for NostrService
      when(mockNostrService.subscribeToEvents(filters: anyNamed('filters')))
          .thenAnswer((_) => Stream.fromIterable([]));
      
      socialService = SocialService(mockNostrService, mockAuthService);
    });

    tearDown(() {
      socialService.dispose();
    });

    group('Like Functionality', () {
      const testEventId = 'test_event_id_123';
      const testAuthorPubkey = 'test_author_pubkey_456';
      const testUserPubkey = 'test_user_pubkey_789';

      setUp(() {
        // Mock authentication state
        when(mockAuthService.isAuthenticated).thenReturn(true);
        when(mockAuthService.currentPublicKeyHex).thenReturn(testUserPubkey);
      });

      test('should check if event is liked correctly', () {
        // Initially not liked
        expect(socialService.isLiked(testEventId), false);

        // After adding to liked set
        socialService.likedEventIds.add(testEventId);
        expect(socialService.isLiked(testEventId), true);
      });

      test('should return cached like count', () {
        // Initially no cached count
        expect(socialService.getCachedLikeCount(testEventId), null);

        // After caching a count
        socialService.likedEventIds; // Access to trigger cache setup
        // Note: Private _likeCounts map can't be directly accessed in tests
        // This would need a public method or getter for testing
      });

      test('should create proper NIP-25 like event when toggling like', () async {
        // Mock event creation
        final mockEvent = Event.from(
          kind: 7,
          content: '+',
          tags: [
            ['e', testEventId],
            ['p', testAuthorPubkey],
          ],
          privkey: '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
        );

        when(mockAuthService.createAndSignEvent(
          kind: 7,
          content: '+',
          tags: [
            ['e', testEventId],
            ['p', testAuthorPubkey],
          ],
        )).thenAnswer((_) async => mockEvent);

        // Mock successful broadcast
        when(mockNostrService.broadcastEvent(mockEvent)).thenAnswer(
          (_) async => NostrBroadcastResult(
            event: mockEvent,
            successCount: 1,
            totalRelays: 1,
            results: const {'relay1': true},
            errors: const {},
          ),
        );

        // Test toggling like
        await socialService.toggleLike(testEventId, testAuthorPubkey);

        // Verify event creation was called with correct parameters
        verify(mockAuthService.createAndSignEvent(
          kind: 7,
          content: '+',
          tags: [
            ['e', testEventId],
            ['p', testAuthorPubkey],
          ],
        )).called(1);

        // Verify broadcast was called
        verify(mockNostrService.broadcastEvent(mockEvent)).called(1);

        // Verify event is now liked locally
        expect(socialService.isLiked(testEventId), true);
      });

      test('should handle broadcast failure gracefully', () async {
        // Mock event creation
        final mockEvent = Event.from(
          kind: 7,
          content: '+',
          tags: [
            ['e', testEventId],
            ['p', testAuthorPubkey],
          ],
          privkey: '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
        );

        when(mockAuthService.createAndSignEvent(
          kind: 7,
          content: '+',
          tags: [
            ['e', testEventId],
            ['p', testAuthorPubkey],
          ],
        )).thenAnswer((_) async => mockEvent);

        // Mock failed broadcast
        when(mockNostrService.broadcastEvent(mockEvent)).thenAnswer(
          (_) async => NostrBroadcastResult(
            event: mockEvent,
            successCount: 0,
            totalRelays: 1,
            results: const {'relay1': false},
            errors: const {'relay1': 'Connection failed'},
          ),
        );

        // Test toggling like should throw exception
        expect(
          () => socialService.toggleLike(testEventId, testAuthorPubkey),
          throwsException,
        );
      });

      test('should not like when user is not authenticated', () async {
        // Mock unauthenticated state
        when(mockAuthService.isAuthenticated).thenReturn(false);

        // Test toggling like
        await socialService.toggleLike(testEventId, testAuthorPubkey);

        // Verify no event creation was attempted
        verifyNever(mockAuthService.createAndSignEvent(
          kind: any,
          content: any,
          tags: any,
        ));

        // Verify event is not liked locally
        expect(socialService.isLiked(testEventId), false);
      });

      test('should handle event creation failure', () async {
        // Mock event creation failure
        when(mockAuthService.createAndSignEvent(
          kind: 7,
          content: '+',
          tags: [
            ['e', testEventId],
            ['p', testAuthorPubkey],
          ],
        )).thenAnswer((_) async => null);

        // Test toggling like should throw exception
        expect(
          () => socialService.toggleLike(testEventId, testAuthorPubkey),
          throwsException,
        );
      });

      test('should toggle like state locally on second tap', () async {
        // First, like the event
        final mockEvent = Event.from(
          kind: 7,
          content: '+',
          tags: [
            ['e', testEventId],
            ['p', testAuthorPubkey],
          ],
          privkey: '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
        );

        when(mockAuthService.createAndSignEvent(
          kind: 7,
          content: '+',
          tags: [
            ['e', testEventId],
            ['p', testAuthorPubkey],
          ],
        )).thenAnswer((_) async => mockEvent);

        when(mockNostrService.broadcastEvent(mockEvent)).thenAnswer(
          (_) async => NostrBroadcastResult(
            event: mockEvent,
            successCount: 1,
            totalRelays: 1,
            results: const {'relay1': true},
            errors: const {},
          ),
        );

        // First toggle - should like
        await socialService.toggleLike(testEventId, testAuthorPubkey);
        expect(socialService.isLiked(testEventId), true);

        // Second toggle - should unlike locally (no new network call)
        await socialService.toggleLike(testEventId, testAuthorPubkey);
        expect(socialService.isLiked(testEventId), false);

        // Verify only one network call was made (for the like)
        verify(mockNostrService.broadcastEvent(any)).called(1);
      });
    });

    group('Like Count Fetching', () {
      const testEventId = 'test_event_id_123';

      test('should fetch like count from network', () async {
        // Mock subscription stream
        final controller = Stream<Event>.fromIterable([
          Event.from(kind: 7, content: '+', tags: [['e', testEventId]], privkey: 'key1'),
          Event.from(kind: 7, content: '+', tags: [['e', testEventId]], privkey: 'key2'),
          Event.from(kind: 7, content: '-', tags: [['e', testEventId]], privkey: 'key3'), // Should not count
        ]);

        when(mockNostrService.subscribeToEvents(filters: anyNamed('filters')))
            .thenAnswer((_) => controller);

        // Test fetching like status
        final result = await socialService.getLikeStatus(testEventId);

        expect(result['count'], 2); // Only '+' reactions should count
        expect(result['user_liked'], false); // User hasn't liked it
      });

      test('should return cached like count when available', () async {
        // This test would require access to private _likeCounts map
        // In a real implementation, we might need a public setter for testing
        // or dependency injection of the cache
        
        // For now, we test the behavior through getLikeStatus
        when(mockAuthService.isAuthenticated).thenReturn(true);
        when(mockAuthService.currentPublicKeyHex).thenReturn('test_user');

        final result = await socialService.getLikeStatus(testEventId);
        
        // Should return default values when no cache exists
        expect(result['count'], 0);
        expect(result['user_liked'], false);
      });
    });

    group('Liked Events Fetching', () {
      const testUserPubkey = 'test_user_pubkey';

      test('should fetch liked events for user', () async {
        // Mock user's reaction events
        final reactionEvents = [
          Event.from(
            kind: 7,
            content: '+',
            tags: [['e', 'video1'], ['p', 'author1']],
            privkey: '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
          ),
          Event.from(
            kind: 7,
            content: '+',
            tags: [['e', 'video2'], ['p', 'author2']],
            privkey: '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
          ),
        ];

        // Mock actual video events
        final videoEvents = [
          Event.from(kind: 34550, content: 'video1 content', privkey: '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef'),
          Event.from(kind: 34550, content: 'video2 content', privkey: '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef'),
        ];

        when(mockNostrService.subscribeToEvents(filters: anyNamed('filters')))
            .thenAnswer((_) {
          // First call returns reactions, second call returns videos
          return Stream.fromIterable(reactionEvents);
        });

        final result = await socialService.fetchLikedEvents(testUserPubkey);

        // Verify the subscription was called to get reactions
        verify(mockNostrService.subscribeToEvents(filters: anyNamed('filters'))).called(1);
        
        // Note: The actual implementation uses two subscriptions and complex async logic
        // A more comprehensive test would need to mock both subscription calls
        expect(result, isA<List<Event>>());
      });

      test('should return empty list when user has no liked events', () async {
        // Mock empty reaction stream
        when(mockNostrService.subscribeToEvents(filters: anyNamed('filters')))
            .thenAnswer((_) => Stream.fromIterable([]));

        final result = await socialService.fetchLikedEvents(testUserPubkey);

        expect(result, isEmpty);
      });

      test('should handle errors when fetching liked events', () async {
        // Mock stream with error
        when(mockNostrService.subscribeToEvents(filters: anyNamed('filters')))
            .thenAnswer((_) => Stream.error('Network error'));

        final result = await socialService.fetchLikedEvents(testUserPubkey);

        // Should return empty list on error
        expect(result, isEmpty);
      });
    });

    group('Follow System (NIP-02)', () {
      const testUserPubkey = 'test_user_pubkey';
      const testTargetPubkey = 'target_user_pubkey';

      setUp(() {
        when(mockAuthService.isAuthenticated).thenReturn(true);
        when(mockAuthService.currentPublicKeyHex).thenReturn(testUserPubkey);
      });

      test('should check if user is following correctly', () {
        // Initially not following
        expect(socialService.isFollowing(testTargetPubkey), false);

        // After adding to follow list
        socialService.followingPubkeys.add(testTargetPubkey);
        expect(socialService.isFollowing(testTargetPubkey), true);
      });

      test('should return current following list', () {
        final followingList = socialService.followingPubkeys;
        expect(followingList, isA<List<String>>());
        expect(followingList, isEmpty); // Initially empty
      });

      test('should fetch current user follow list from Kind 3 events', () async {
        // Mock Kind 3 contact list event
        final contactListEvent = Event.from(
          kind: 3,
          content: '',
          tags: [
            ['p', 'pubkey1'],
            ['p', 'pubkey2'],
            ['p', 'pubkey3'],
          ],
          privkey: '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
        );

        when(mockNostrService.subscribeToEvents(filters: anyNamed('filters')))
            .thenAnswer((_) => Stream.fromIterable([contactListEvent]));

        await socialService.fetchCurrentUserFollowList();

        // Verify subscription was called for Kind 3 events
        verify(mockNostrService.subscribeToEvents(
          filters: argThat(isA<List>(), named: 'filters'),
        )).called(1);

        // Following list should be updated
        expect(socialService.followingPubkeys.length, 3);
        expect(socialService.isFollowing('pubkey1'), true);
        expect(socialService.isFollowing('pubkey2'), true);
        expect(socialService.isFollowing('pubkey3'), true);
      });

      test('should follow user by creating Kind 3 event', () async {
        // Mock successful Kind 3 event creation
        final mockContactListEvent = Event.from(
          kind: 3,
          content: '',
          tags: [['p', testTargetPubkey]],
          privkey: '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
        );

        when(mockAuthService.createAndSignEvent(
          kind: 3,
          content: '',
          tags: [['p', testTargetPubkey]],
        )).thenAnswer((_) async => mockContactListEvent);

        when(mockNostrService.broadcastEvent(mockContactListEvent)).thenAnswer(
          (_) async => NostrBroadcastResult(
            event: mockContactListEvent,
            successCount: 1,
            totalRelays: 1,
            results: const {'relay1': true},
            errors: const {},
          ),
        );

        // Test following user
        await socialService.followUser(testTargetPubkey);

        // Verify event creation with correct Kind 3 parameters
        verify(mockAuthService.createAndSignEvent(
          kind: 3,
          content: '',
          tags: [['p', testTargetPubkey]],
        )).called(1);

        // Verify broadcast was called
        verify(mockNostrService.broadcastEvent(mockContactListEvent)).called(1);

        // Verify user is now followed locally
        expect(socialService.isFollowing(testTargetPubkey), true);
      });

      test('should unfollow user by updating Kind 3 event', () async {
        // First, add user to following list
        await socialService.followUser(testTargetPubkey);
        reset(mockAuthService);
        reset(mockNostrService);

        // Mock unfollowing - empty contact list
        final mockEmptyContactListEvent = Event.from(
          kind: 3,
          content: '',
          tags: [],
          privkey: '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
        );

        when(mockAuthService.createAndSignEvent(
          kind: 3,
          content: '',
          tags: [],
        )).thenAnswer((_) async => mockEmptyContactListEvent);

        when(mockNostrService.broadcastEvent(mockEmptyContactListEvent)).thenAnswer(
          (_) async => NostrBroadcastResult(
            event: mockEmptyContactListEvent,
            successCount: 1,
            totalRelays: 1,
            results: const {'relay1': true},
            errors: const {},
          ),
        );

        // Test unfollowing user
        await socialService.unfollowUser(testTargetPubkey);

        // Verify event creation with empty tags
        verify(mockAuthService.createAndSignEvent(
          kind: 3,
          content: '',
          tags: [],
        )).called(1);

        // Verify broadcast was called
        verify(mockNostrService.broadcastEvent(mockEmptyContactListEvent)).called(1);

        // Verify user is no longer followed locally
        expect(socialService.isFollowing(testTargetPubkey), false);
      });

      test('should not follow when user is not authenticated', () async {
        when(mockAuthService.isAuthenticated).thenReturn(false);

        await socialService.followUser(testTargetPubkey);

        // Verify no event creation was attempted
        verifyNever(mockAuthService.createAndSignEvent(
          kind: any,
          content: any,
          tags: any,
        ));

        // Verify user is not followed locally
        expect(socialService.isFollowing(testTargetPubkey), false);
      });

      test('should handle follow broadcast failure gracefully', () async {
        // Mock successful event creation but failed broadcast
        final mockContactListEvent = Event.from(
          kind: 3,
          content: '',
          tags: [['p', testTargetPubkey]],
          privkey: '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
        );

        when(mockAuthService.createAndSignEvent(
          kind: 3,
          content: '',
          tags: [['p', testTargetPubkey]],
        )).thenAnswer((_) async => mockContactListEvent);

        when(mockNostrService.broadcastEvent(mockContactListEvent)).thenAnswer(
          (_) async => NostrBroadcastResult(
            event: mockContactListEvent,
            successCount: 0,
            totalRelays: 1,
            results: const {'relay1': false},
            errors: const {'relay1': 'Connection failed'},
          ),
        );

        // Test following should throw exception
        expect(
          () => socialService.followUser(testTargetPubkey),
          throwsException,
        );
      });

      test('should not follow already followed user', () async {
        // First follow the user
        await socialService.followUser(testTargetPubkey);
        reset(mockAuthService);
        reset(mockNostrService);

        // Try to follow again
        await socialService.followUser(testTargetPubkey);

        // Verify no additional event creation was attempted
        verifyNever(mockAuthService.createAndSignEvent(
          kind: any,
          content: any,
          tags: any,
        ));
      });

      test('should not unfollow user that is not followed', () async {
        // Try to unfollow user not in following list
        await socialService.unfollowUser(testTargetPubkey);

        // Verify no event creation was attempted
        verifyNever(mockAuthService.createAndSignEvent(
          kind: any,
          content: any,
          tags: any,
        ));
      });

      test('should fetch follower stats from network', () async {
        const targetPubkey = 'target_pubkey';
        
        // Mock user's Kind 3 event (following count)
        final userContactList = Event.from(
          kind: 3,
          content: '',
          tags: [
            ['p', 'pubkey1'],
            ['p', 'pubkey2'],
            ['p', 'pubkey3'],
          ],
          privkey: '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
        );

        // Mock followers' Kind 3 events that mention target user
        final followerEvents = [
          Event.from(
            kind: 3,
            content: '',
            tags: [['p', targetPubkey]],
            privkey: '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
          ),
          Event.from(
            kind: 3,
            content: '',
            tags: [['p', targetPubkey]],
            privkey: '1123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
          ),
        ];

        // Mock subscription calls
        when(mockNostrService.subscribeToEvents(filters: anyNamed('filters')))
            .thenAnswer((invocation) {
          final filters = invocation.namedArguments[const Symbol('filters')] as List;
          final filter = filters.first as Filter;
          
          if (filter.authors?.contains(targetPubkey) == true) {
            // Following count query
            return Stream.fromIterable([userContactList]);
          } else if (filter.p?.contains(targetPubkey) == true) {
            // Followers count query
            return Stream.fromIterable(followerEvents);
          }
          return Stream.fromIterable([]);
        });

        final stats = await socialService.getFollowerStats(targetPubkey);

        expect(stats['following'], 3); // 3 p tags in contact list
        expect(stats['followers'], 2); // 2 unique followers
      });

      test('should return cached follower stats when available', () async {
        const targetPubkey = 'target_pubkey';
        
        // First call will fetch from network
        when(mockNostrService.subscribeToEvents(filters: anyNamed('filters')))
            .thenAnswer((_) => Stream.fromIterable([]));

        final firstResult = await socialService.getFollowerStats(targetPubkey);
        
        // Second call should use cache
        final secondResult = await socialService.getFollowerStats(targetPubkey);
        
        expect(firstResult, equals(secondResult));
        
        // Should only call network once
        verify(mockNostrService.subscribeToEvents(filters: anyNamed('filters'))).called(2); // Once for following, once for followers
      });

      test('should handle follower stats fetch failure', () async {
        const targetPubkey = 'target_pubkey';
        
        when(mockNostrService.subscribeToEvents(filters: anyNamed('filters')))
            .thenAnswer((_) => Stream.error('Network error'));

        final stats = await socialService.getFollowerStats(targetPubkey);

        expect(stats['followers'], 0);
        expect(stats['following'], 0);
      });
    });

    group('Profile Statistics', () {
      const testUserPubkey = 'test_user_pubkey';

      setUp(() {
        when(mockAuthService.isAuthenticated).thenReturn(true);
        when(mockAuthService.currentPublicKeyHex).thenReturn(testUserPubkey);
      });

      test('should fetch user video count', () async {
        // Mock user's video events
        final videoEvents = [
          Event.from(
            kind: 34550,
            content: 'Video 1',
            privkey: '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
          ),
          Event.from(
            kind: 34550,
            content: 'Video 2',
            privkey: '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
          ),
          Event.from(
            kind: 34550,
            content: 'Video 3',
            privkey: '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
          ),
        ];

        when(mockNostrService.subscribeToEvents(filters: anyNamed('filters')))
            .thenAnswer((_) => Stream.fromIterable(videoEvents));

        final count = await socialService.getUserVideoCount(testUserPubkey);

        expect(count, 3);
        
        // Verify subscription was called for video events
        verify(mockNostrService.subscribeToEvents(
          filters: argThat(isA<List>(), named: 'filters'),
        )).called(1);
      });

      test('should return zero for user with no videos', () async {
        when(mockNostrService.subscribeToEvents(filters: anyNamed('filters')))
            .thenAnswer((_) => Stream.fromIterable([]));

        final count = await socialService.getUserVideoCount(testUserPubkey);

        expect(count, 0);
      });

      test('should fetch user total likes across all videos', () async {
        // Mock user's video events
        final videoEvents = [
          Event.from(
            kind: 34550,
            content: 'Video 1',
            privkey: '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
          ),
          Event.from(
            kind: 34550,
            content: 'Video 2',
            privkey: '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
          ),
        ];

        // Mock like events for these videos
        final likeEvents = [
          Event.from(
            kind: 7,
            content: '+',
            tags: [['e', videoEvents[0].id]],
            privkey: '1123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
          ),
          Event.from(
            kind: 7,
            content: '+',
            tags: [['e', videoEvents[0].id]],
            privkey: '2123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
          ),
          Event.from(
            kind: 7,
            content: '+',
            tags: [['e', videoEvents[1].id]],
            privkey: '3123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
          ),
          Event.from(
            kind: 7,
            content: '-', // Should not count
            tags: [['e', videoEvents[1].id]],
            privkey: '4123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
          ),
        ];

        when(mockNostrService.subscribeToEvents(filters: anyNamed('filters')))
            .thenAnswer((invocation) {
          final filters = invocation.namedArguments[const Symbol('filters')] as List;
          final filter = filters.first as Filter;
          
          if (filter.authors?.contains(testUserPubkey) == true) {
            // Video events query
            return Stream.fromIterable(videoEvents);
          } else if (filter.kinds?.contains(7) == true) {
            // Like events query
            return Stream.fromIterable(likeEvents);
          }
          return Stream.fromIterable([]);
        });

        final totalLikes = await socialService.getUserTotalLikes(testUserPubkey);

        expect(totalLikes, 3); // Only '+' reactions should count
        
        // Should call subscription twice: once for videos, once for likes
        verify(mockNostrService.subscribeToEvents(filters: anyNamed('filters'))).called(2);
      });

      test('should return zero likes for user with no videos', () async {
        when(mockNostrService.subscribeToEvents(filters: anyNamed('filters')))
            .thenAnswer((_) => Stream.fromIterable([]));

        final totalLikes = await socialService.getUserTotalLikes(testUserPubkey);

        expect(totalLikes, 0);
      });

      test('should handle video count fetch error gracefully', () async {
        when(mockNostrService.subscribeToEvents(filters: anyNamed('filters')))
            .thenAnswer((_) => Stream.error('Network error'));

        final count = await socialService.getUserVideoCount(testUserPubkey);

        expect(count, 0);
      });

      test('should handle total likes fetch error gracefully', () async {
        when(mockNostrService.subscribeToEvents(filters: anyNamed('filters')))
            .thenAnswer((_) => Stream.error('Network error'));

        final totalLikes = await socialService.getUserTotalLikes(testUserPubkey);

        expect(totalLikes, 0);
      });
    });
  });
}