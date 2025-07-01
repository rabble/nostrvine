// ABOUTME: Tests for Riverpod SocialProvider state management and social interactions
// ABOUTME: Verifies reactive likes, follows, reposts, and comment functionality

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_sdk/event.dart';

import 'package:openvine/providers/social_providers.dart';
import 'package:openvine/state/social_state.dart';
import 'package:openvine/services/nostr_service_interface.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/subscription_manager.dart';

// Mock classes
class MockNostrService extends Mock implements INostrService {}
class MockAuthService extends Mock implements AuthService {}
class MockSubscriptionManager extends Mock implements SubscriptionManager {}
class MockEvent extends Mock implements Event {}

void main() {
  setUpAll(() {
    // Register fallback values for mocktail
    registerFallbackValue(MockEvent());
  });

  group('SocialProvider', () {
    late ProviderContainer container;
    late MockNostrService mockNostrService;
    late MockAuthService mockAuthService;
    late MockSubscriptionManager mockSubscriptionManager;

    setUp(() {
      mockNostrService = MockNostrService();
      mockAuthService = MockAuthService();
      mockSubscriptionManager = MockSubscriptionManager();
      
      container = ProviderContainer(
        overrides: [
          nostrServiceProvider.overrideWithValue(mockNostrService),
          authServiceProvider.overrideWithValue(mockAuthService),
          subscriptionManagerProvider.overrideWithValue(mockSubscriptionManager),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('should start with initial state', () {
      final state = container.read(socialProvider);
      
      expect(state, equals(SocialState.initial));
      expect(state.likedEventIds, isEmpty);
      expect(state.repostedEventIds, isEmpty);
      expect(state.followingPubkeys, isEmpty);
      expect(state.likeCounts, isEmpty);
      expect(state.followerStats, isEmpty);
      expect(state.isLoading, isFalse);
      expect(state.error, isNull);
    });

    test('should initialize user social data when authenticated', () async {
      // Setup authenticated user
      when(() => mockAuthService.isAuthenticated).thenReturn(true);
      when(() => mockAuthService.currentPublicKeyHex).thenReturn('test-pubkey');
      
      // Mock event streams
      when(() => mockNostrService.subscribeToEvents(filters: any(named: 'filters')))
          .thenAnswer((_) => Stream<Event>.empty());
      
      // Initialize
      await container.read(socialProvider.notifier).initialize();
      
      final state = container.read(socialProvider);
      expect(state.isInitialized, isTrue);
      
      // Verify it tried to load user data
      verify(() => mockNostrService.subscribeToEvents(filters: any(named: 'filters'))).called(greaterThan(0));
    });

    test('should toggle like on/off for an event', () async {
      const eventId = 'test-event-id';
      const authorPubkey = 'author-pubkey';
      
      // Setup authenticated user
      when(() => mockAuthService.isAuthenticated).thenReturn(true);
      when(() => mockAuthService.currentPublicKeyHex).thenReturn('test-pubkey');
      
      // Mock successful like event creation and broadcast
      final mockLikeEvent = MockEvent();
      when(() => mockLikeEvent.id).thenReturn('like-event-id');
      when(() => mockAuthService.createAndSignEvent(
        kind: 7,
        content: '+',
        tags: any(named: 'tags'),
      )).thenAnswer((_) async => mockLikeEvent);
      
      final mockBroadcastResult = NostrBroadcastResult(
        event: mockLikeEvent,
        successCount: 1,
        totalRelays: 1,
        results: {'relay1': true},
        errors: {},
      );
      when(() => mockNostrService.broadcastEvent(any())).thenAnswer((_) async => mockBroadcastResult);
      
      // Toggle like (should add)
      await container.read(socialProvider.notifier).toggleLike(eventId, authorPubkey);
      
      var state = container.read(socialProvider);
      expect(state.likedEventIds.contains(eventId), isTrue);
      expect(state.likeCounts[eventId], equals(1));
      
      // Mock successful unlike (deletion)
      when(() => mockAuthService.createAndSignEvent(
        kind: 5,
        content: any(named: 'content'),
        tags: any(named: 'tags'),
      )).thenAnswer((_) async => mockLikeEvent);
      
      // Toggle like again (should remove)
      await container.read(socialProvider.notifier).toggleLike(eventId, authorPubkey);
      
      state = container.read(socialProvider);
      expect(state.likedEventIds.contains(eventId), isFalse);
      expect(state.likeCounts[eventId], equals(0));
    });

    test('should follow and unfollow users', () async {
      const userToFollow = 'pubkey-to-follow';
      
      // Setup authenticated user
      when(() => mockAuthService.isAuthenticated).thenReturn(true);
      when(() => mockAuthService.currentPublicKeyHex).thenReturn('test-pubkey');
      
      // Mock contact list event creation and broadcast
      final mockContactEvent = MockEvent();
      when(() => mockContactEvent.id).thenReturn('contact-event-id');
      when(() => mockAuthService.createAndSignEvent(
        kind: 3,
        content: any(named: 'content'),
        tags: any(named: 'tags'),
      )).thenAnswer((_) async => mockContactEvent);
      
      final mockBroadcastResult = NostrBroadcastResult(
        event: mockContactEvent,
        successCount: 1,
        totalRelays: 1,
        results: {'relay1': true},
        errors: {},
      );
      when(() => mockNostrService.broadcastEvent(any())).thenAnswer((_) async => mockBroadcastResult);
      
      // Follow user
      await container.read(socialProvider.notifier).followUser(userToFollow);
      
      var state = container.read(socialProvider);
      expect(state.followingPubkeys.contains(userToFollow), isTrue);
      
      // Unfollow user
      await container.read(socialProvider.notifier).unfollowUser(userToFollow);
      
      state = container.read(socialProvider);
      expect(state.followingPubkeys.contains(userToFollow), isFalse);
    });

    test('should handle repost functionality', () async {
      // Create a mock event to repost
      final eventToRepost = MockEvent();
      when(() => eventToRepost.id).thenReturn('event-to-repost');
      when(() => eventToRepost.pubkey).thenReturn('original-author');
      when(() => eventToRepost.kind).thenReturn(22); // Video event
      // For reposts, content is typically empty in the existing implementation
      
      // Setup authenticated user
      when(() => mockAuthService.isAuthenticated).thenReturn(true);
      when(() => mockAuthService.currentPublicKeyHex).thenReturn('test-pubkey');
      
      // Mock repost event creation and broadcast
      final mockRepostEvent = MockEvent();
      when(() => mockRepostEvent.id).thenReturn('repost-event-id');
      when(() => mockAuthService.createAndSignEvent(
        kind: 6,
        content: any(named: 'content'),
        tags: any(named: 'tags'),
      )).thenAnswer((_) async => mockRepostEvent);
      
      final mockBroadcastResult = NostrBroadcastResult(
        event: mockRepostEvent,
        successCount: 1,
        totalRelays: 1,
        results: {'relay1': true},
        errors: {},
      );
      when(() => mockNostrService.broadcastEvent(any())).thenAnswer((_) async => mockBroadcastResult);
      
      // Repost event
      await container.read(socialProvider.notifier).repostEvent(eventToRepost);
      
      final state = container.read(socialProvider);
      expect(state.repostedEventIds.contains('event-to-repost'), isTrue);
    });

    test('should handle errors gracefully', () async {
      const eventId = 'test-event-id';
      const authorPubkey = 'author-pubkey';
      
      // Setup authenticated user
      when(() => mockAuthService.isAuthenticated).thenReturn(true);
      
      // Mock failed event creation
      when(() => mockAuthService.createAndSignEvent(
        kind: any(named: 'kind'),
        content: any(named: 'content'),
        tags: any(named: 'tags'),
      )).thenThrow(Exception('Network error'));
      
      // Try to toggle like
      await expectLater(
        () => container.read(socialProvider.notifier).toggleLike(eventId, authorPubkey),
        throwsException,
      );
      
      // State should remain unchanged
      final state = container.read(socialProvider);
      expect(state.likedEventIds.contains(eventId), isFalse);
    });

    test('should update follower stats cache', () async {
      const pubkey = 'test-pubkey';
      final stats = {'followers': 100, 'following': 50};
      
      // Update stats
      container.read(socialProvider.notifier).updateFollowerStats(pubkey, stats);
      
      final state = container.read(socialProvider);
      expect(state.followerStats[pubkey], equals(stats));
    });

    test('should check if user is following another user', () {
      // Add some following pubkeys
      container.read(socialProvider.notifier).updateFollowingList(['pubkey1', 'pubkey2', 'pubkey3']);
      
      final state = container.read(socialProvider);
      expect(state.isFollowing('pubkey2'), isTrue);
      expect(state.isFollowing('pubkey4'), isFalse);
    });
  });
}