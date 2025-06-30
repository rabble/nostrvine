// ABOUTME: Factory helper for creating service instances in tests with proper dependencies
// ABOUTME: Provides consistent setup for VideoEventService, SocialService, and UserProfileService

import 'package:mockito/mockito.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:openvine/services/social_service.dart';
import 'package:openvine/services/user_profile_service.dart';
import 'package:openvine/services/nostr_service_interface.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/subscription_manager.dart';
import 'package:openvine/services/seen_videos_service.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/filter.dart';

/// Creates a VideoEventService with mocked dependencies for testing
VideoEventService createTestVideoEventService({
  required INostrService mockNostrService,
  required SubscriptionManager mockSubscriptionManager,
  SeenVideosService? mockSeenVideosService,
}) {
  // Set up default mock behaviors
  when(mockNostrService.isInitialized).thenReturn(true);
  when(mockNostrService.connectedRelayCount).thenReturn(1);
  when(mockNostrService.subscribeToEvents(filters: anyNamed('filters')))
      .thenAnswer((_) => const Stream<Event>.empty());
      
  return VideoEventService(
    mockNostrService,
    seenVideosService: mockSeenVideosService,
    subscriptionManager: mockSubscriptionManager,
  );
}

/// Creates a SocialService with mocked dependencies for testing
SocialService createTestSocialService({
  required INostrService mockNostrService,
  required AuthService mockAuthService,
  required SubscriptionManager mockSubscriptionManager,
}) {
  // Set up default mock behaviors
  when(mockNostrService.subscribeToEvents(filters: anyNamed('filters')))
      .thenAnswer((_) => const Stream<Event>.empty());
  when(mockAuthService.isAuthenticated).thenReturn(false);
  
  return SocialService(
    mockNostrService,
    mockAuthService,
    subscriptionManager: mockSubscriptionManager,
  );
}

/// Creates a UserProfileService with mocked dependencies for testing  
UserProfileService createTestUserProfileService({
  required INostrService mockNostrService,
  required SubscriptionManager mockSubscriptionManager,
}) {
  // Set up default mock behaviors
  when(mockNostrService.isInitialized).thenReturn(true);
  when(mockNostrService.subscribeToEvents(filters: anyNamed('filters')))
      .thenAnswer((_) => const Stream<Event>.empty());
      
  return UserProfileService(
    mockNostrService,
    subscriptionManager: mockSubscriptionManager,
  );
}

/// Sets up common mock behaviors for SubscriptionManager
void setupMockSubscriptionManager(SubscriptionManager mockSubscriptionManager) {
  when(mockSubscriptionManager.createSubscription(
    name: anyNamed('name'),
    filters: anyNamed('filters'),
    onEvent: anyNamed('onEvent'),
    onError: anyNamed('onError'),
    onComplete: anyNamed('onComplete'),
    timeout: anyNamed('timeout'),
    priority: anyNamed('priority'),
  )).thenAnswer((invocation) async {
    final name = invocation.namedArguments[#name] as String;
    return 'mock_sub_$name';
  });
  
  when(mockSubscriptionManager.cancelSubscription(any()))
      .thenAnswer((_) async {});
}