// ABOUTME: Tests for Riverpod UserProfileProvider state management and profile caching
// ABOUTME: Verifies reactive user profile updates and proper cache management

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_sdk/event.dart';

import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/state/user_profile_state.dart';
import 'package:openvine/services/nostr_service_interface.dart';
import 'package:openvine/services/subscription_manager.dart';
import 'package:openvine/models/user_profile.dart' as models;

// Mock classes
class MockNostrService extends Mock implements INostrService {}
class MockSubscriptionManager extends Mock implements SubscriptionManager {}
class MockEvent extends Mock implements Event {}

void main() {
  setUpAll(() {
    // Register fallback values for mocktail
    registerFallbackValue(MockEvent());
  });

  group('UserProfileProvider', () {
    late ProviderContainer container;
    late MockNostrService mockNostrService;
    late MockSubscriptionManager mockSubscriptionManager;

    setUp(() {
      mockNostrService = MockNostrService();
      mockSubscriptionManager = MockSubscriptionManager();
      
      container = ProviderContainer(
        overrides: [
          nostrServiceProvider.overrideWithValue(mockNostrService),
          subscriptionManagerProvider.overrideWithValue(mockSubscriptionManager),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('should start with initial state', () {
      final state = container.read(userProfilesProvider);
      
      expect(state, equals(UserProfileState.initial));
      expect(state.profileCache, isEmpty);
      expect(state.pendingRequests, isEmpty);
      expect(state.isLoading, isFalse);
      expect(state.error, isNull);
    });

    test('should initialize properly', () async {
      // Setup mock Nostr service
      when(() => mockNostrService.isInitialized).thenReturn(true);
      
      // Initialize
      await container.read(userProfilesProvider.notifier).initialize();
      
      final state = container.read(userProfilesProvider);
      expect(state.isInitialized, isTrue);
    });

    test('should fetch and cache a user profile', () async {
      const pubkey = 'test-pubkey-123';
      
      // Setup mock Nostr service
      when(() => mockNostrService.isInitialized).thenReturn(true);
      
      // Setup mock event
      final mockEvent = MockEvent();
      when(() => mockEvent.kind).thenReturn(0);
      when(() => mockEvent.pubkey).thenReturn(pubkey);
      when(() => mockEvent.id).thenReturn('event-id-123');
      when(() => mockEvent.createdAt).thenReturn(1234567890);
      when(() => mockEvent.content).thenReturn('{"name":"Test User","picture":"https://example.com/avatar.jpg"}');
      
      // Mock Nostr service subscription
      when(() => mockNostrService.subscribeToEvents(filters: any(named: 'filters')))
          .thenAnswer((_) => Stream.value(mockEvent));
      
      // Fetch profile
      final profile = await container.read(userProfilesProvider.notifier).fetchProfile(pubkey);
      
      expect(profile, isNotNull);
      expect(profile!.pubkey, equals(pubkey));
      expect(profile.name, equals('Test User'));
      expect(profile.picture, equals('https://example.com/avatar.jpg'));
      
      // Verify it's cached
      final state = container.read(userProfilesProvider);
      expect(state.profileCache.containsKey(pubkey), isTrue);
      expect(state.profileCache[pubkey], equals(profile));
    });

    test('should return cached profile without fetching', () async {
      const pubkey = 'test-pubkey-123';
      
      // Setup mock Nostr service
      when(() => mockNostrService.isInitialized).thenReturn(true);
      
      // Pre-populate cache
      final testProfile = models.UserProfile(
        pubkey: pubkey,
        name: 'Cached User',
        rawData: {},
        createdAt: DateTime.now(),
        eventId: 'cached-event-id',
      );
      
      container.read(userProfilesProvider.notifier).updateCachedProfile(testProfile);
      
      // Fetch should return cached profile without network call
      final profile = await container.read(userProfilesProvider.notifier).fetchProfile(pubkey);
      
      expect(profile, equals(testProfile));
      verifyNever(() => mockNostrService.subscribeToEvents(filters: any(named: 'filters')));
    });

    test('should handle batch profile fetching', () async {
      final pubkeys = ['pubkey1', 'pubkey2', 'pubkey3'];
      
      // Track state changes
      final stateChanges = <UserProfileState>[];
      container.listen(userProfilesProvider, (previous, next) {
        stateChanges.add(next);
      }, fireImmediately: true);
      
      // Setup mock Nostr service
      when(() => mockNostrService.isInitialized).thenReturn(true);
      
      // Setup mock events
      final mockEvents = pubkeys.map((pubkey) {
        final event = MockEvent();
        when(() => event.kind).thenReturn(0);
        when(() => event.pubkey).thenReturn(pubkey);
        when(() => event.id).thenReturn('event-$pubkey');
        when(() => event.createdAt).thenReturn(1234567890);
        when(() => event.content).thenReturn('{"name":"User $pubkey"}');
        return event;
      }).toList();
      
      // Mock batch subscription with stream controller for proper async handling
      final streamController = StreamController<Event>();
      when(() => mockNostrService.subscribeToEvents(filters: any(named: 'filters')))
          .thenAnswer((_) {
            // Send events asynchronously
            Future.microtask(() async {
              for (final event in mockEvents) {
                streamController.add(event);
                await Future.delayed(Duration(milliseconds: 10));
              }
              await streamController.close();
            });
            return streamController.stream;
          });
      
      // Check initial state
      var state = container.read(userProfilesProvider);
      
      // Fetch multiple profiles
      await container.read(userProfilesProvider.notifier).fetchMultipleProfiles(pubkeys);
      
      // Check state immediately after call
      state = container.read(userProfilesProvider);
      
      // Instead of waiting for the timer, call batch fetch directly
      await container.read(userProfilesProvider.notifier).executeBatchFetch();
      
      // Wait for stream processing to complete
      await Future.delayed(Duration(milliseconds: 100));
      
      // Verify all profiles are cached
      state = container.read(userProfilesProvider);
      
      for (final pubkey in pubkeys) {
        expect(state.profileCache.containsKey(pubkey), isTrue);
        expect(state.profileCache[pubkey]!.name, equals('User $pubkey'));
      }
    });

    test('should handle profile not found', () async {
      const pubkey = 'non-existent-pubkey';
      
      // Setup mock Nostr service
      when(() => mockNostrService.isInitialized).thenReturn(true);
      
      // Mock empty stream (no profile found)
      when(() => mockNostrService.subscribeToEvents(filters: any(named: 'filters')))
          .thenAnswer((_) => Stream.empty());
      
      // Fetch profile
      final profile = await container.read(userProfilesProvider.notifier).fetchProfile(pubkey);
      
      expect(profile, isNull);
      
      // Verify it's marked as missing
      final state = container.read(userProfilesProvider);
      expect(state.knownMissingProfiles.contains(pubkey), isTrue);
    });

    test('should force refresh cached profile', () async {
      const pubkey = 'test-pubkey-123';
      
      // Setup mock Nostr service
      when(() => mockNostrService.isInitialized).thenReturn(true);
      
      // Pre-populate cache with old profile
      final oldProfile = models.UserProfile(
        pubkey: pubkey,
        name: 'Old Name',
        rawData: {},
        createdAt: DateTime.now().subtract(Duration(hours: 1)),
        eventId: 'old-event-id',
      );
      
      container.read(userProfilesProvider.notifier).updateCachedProfile(oldProfile);
      
      // Setup new profile event
      final mockEvent = MockEvent();
      when(() => mockEvent.kind).thenReturn(0);
      when(() => mockEvent.pubkey).thenReturn(pubkey);
      when(() => mockEvent.id).thenReturn('new-event-id');
      when(() => mockEvent.createdAt).thenReturn(DateTime.now().millisecondsSinceEpoch ~/ 1000);
      when(() => mockEvent.content).thenReturn('{"name":"New Name"}');
      
      when(() => mockNostrService.subscribeToEvents(filters: any(named: 'filters')))
          .thenAnswer((_) => Stream.value(mockEvent));
      
      // Force refresh
      final profile = await container.read(userProfilesProvider.notifier).fetchProfile(pubkey, forceRefresh: true);
      
      expect(profile, isNotNull);
      expect(profile!.name, equals('New Name'));
      
      // Verify network call was made
      verify(() => mockNostrService.subscribeToEvents(filters: any(named: 'filters'))).called(1);
    });

    test('should handle errors gracefully', () async {
      const pubkey = 'test-pubkey-123';
      
      // Setup mock Nostr service
      when(() => mockNostrService.isInitialized).thenReturn(true);
      
      // Mock subscription error
      when(() => mockNostrService.subscribeToEvents(filters: any(named: 'filters')))
          .thenAnswer((_) => Stream.error(Exception('Network error')));
      
      // Fetch profile should handle error
      final profile = await container.read(userProfilesProvider.notifier).fetchProfile(pubkey);
      
      expect(profile, isNull);
      
      // Check error state
      final state = container.read(userProfilesProvider);
      expect(state.error, contains('Network error'));
    });
  });
}