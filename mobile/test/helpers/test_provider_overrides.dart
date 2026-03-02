// ABOUTME: Centralized provider overrides for widget tests to fix ProviderException failures
// ABOUTME: Provides mock implementations of all providers that throw UnimplementedError in production

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_cache/media_cache.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/blossom_auth_service.dart';
import 'package:openvine/services/openvine_media_cache.dart';
import 'package:openvine/services/social_service.dart';
import 'package:openvine/services/subscription_manager.dart';
import 'package:openvine/services/user_profile_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Mock classes (public because they are imported by many test files)
class MockSharedPreferences extends Mock implements SharedPreferences {}

class MockSocialService extends Mock implements SocialService {}

class MockAuthService extends Mock implements AuthService {}

class MockUserProfileService extends Mock implements UserProfileService {}

class MockSubscriptionManager extends Mock implements SubscriptionManager {}

class MockBlossomAuthService extends Mock implements BlossomAuthService {}

class MockMediaCacheManager extends Mock implements MediaCacheManager {}

class MockNostrClient extends Mock implements NostrClient {}

/// Creates a properly stubbed MockSharedPreferences for testing
MockSharedPreferences createMockSharedPreferences() {
  final mockPrefs = MockSharedPreferences();

  // Stub all FeatureFlag methods to return sensible defaults
  for (final flag in FeatureFlag.values) {
    when(() => mockPrefs.getBool('ff_${flag.name}')).thenReturn(null);
    when(
      () => mockPrefs.setBool('ff_${flag.name}', any()),
    ).thenAnswer((_) async => true);
    when(
      () => mockPrefs.remove('ff_${flag.name}'),
    ).thenAnswer((_) async => true);
    when(() => mockPrefs.containsKey('ff_${flag.name}')).thenReturn(false);
  }

  // Add common SharedPreferences stubs that tests might need
  when(() => mockPrefs.getBool(any())).thenReturn(null);
  when(() => mockPrefs.setBool(any(), any())).thenAnswer((_) async => true);
  when(() => mockPrefs.getString(any())).thenReturn(null);
  when(() => mockPrefs.setString(any(), any())).thenAnswer((_) async => true);
  when(() => mockPrefs.getInt(any())).thenReturn(null);
  when(() => mockPrefs.setInt(any(), any())).thenAnswer((_) async => true);
  when(() => mockPrefs.getDouble(any())).thenReturn(null);
  when(() => mockPrefs.setDouble(any(), any())).thenAnswer((_) async => true);
  when(() => mockPrefs.getStringList(any())).thenReturn(null);
  when(
    () => mockPrefs.setStringList(any(), any()),
  ).thenAnswer((_) async => true);
  when(() => mockPrefs.remove(any())).thenAnswer((_) async => true);
  when(mockPrefs.clear).thenAnswer((_) async => true);
  when(() => mockPrefs.containsKey(any())).thenReturn(false);

  return mockPrefs;
}

/// Creates a properly stubbed MockAuthService for testing
MockAuthService createMockAuthService() {
  final mockAuth = MockAuthService();

  // Stub common auth methods with sensible defaults
  when(() => mockAuth.isAuthenticated).thenReturn(false);
  when(() => mockAuth.currentPublicKeyHex).thenReturn(null);

  return mockAuth;
}

/// Creates a properly stubbed MockSocialService for testing
MockSocialService createMockSocialService() {
  final mockSocial = MockSocialService();

  // Stub common methods to return empty results by default
  when(
    () => mockSocial.getFollowerStats(any()),
  ).thenAnswer((_) async => {'followers': 0, 'following': 0});
  when(() => mockSocial.getUserVideoCount(any())).thenAnswer((_) async => 0);

  return mockSocial;
}

/// Creates a properly stubbed MockUserProfileService for testing
MockUserProfileService createMockUserProfileService() {
  final mockProfile = MockUserProfileService();

  // Stub common methods
  when(() => mockProfile.getCachedProfile(any())).thenReturn(null);
  when(() => mockProfile.hasProfile(any())).thenReturn(false);
  when(() => mockProfile.shouldSkipProfileFetch(any())).thenReturn(false);
  when(() => mockProfile.fetchProfile(any())).thenAnswer((_) async => null);
  when(() => mockProfile.fetchMultipleProfiles(any())).thenAnswer((_) async {});

  return mockProfile;
}

/// Creates a properly stubbed MockNostrClient for testing
MockNostrClient createMockNostrService() {
  final mockNostr = MockNostrClient();

  // Stub common properties
  when(() => mockNostr.isInitialized).thenReturn(true);
  when(() => mockNostr.connectedRelayCount).thenReturn(1);
  when(() => mockNostr.configuredRelays).thenReturn(<String>[]);

  // Stub subscribe() to return empty stream (never null) so
  // SubscriptionManager and UserProfileService batch fetch do not get
  // type 'Null' is not a subtype of type 'Stream<Event>'
  when(
    () => mockNostr.subscribe(any()),
  ).thenAnswer((_) => const Stream<Event>.empty());

  // Stub queryEvents() to return empty list (never null) so
  // FollowRepository getFollowers/getMyFollowers do not get
  // type 'Null' is not a subtype of type 'Future<List<String>>'
  when(() => mockNostr.queryEvents(any())).thenAnswer((_) async => <Event>[]);

  // Stub publicKey with empty string default so tests that access it
  // do not get type 'Null' is not a subtype of type 'String'
  when(() => mockNostr.publicKey).thenReturn('');
  return mockNostr;
}

/// Creates a properly stubbed MockSubscriptionManager for testing
MockSubscriptionManager createMockSubscriptionManager() {
  final mockSub = MockSubscriptionManager();

  // Stub createSubscription to return a valid subscription id (never null)
  // and immediately call onComplete to simulate empty results, so
  // UserProfileService batch fetch does not get
  // type 'Null' is not a subtype of type 'Future<String>'.
  when(
    () => mockSub.createSubscription(
      name: any(named: 'name'),
      filters: any(named: 'filters'),
      onEvent: any(named: 'onEvent'),
      onError: any(named: 'onError'),
      onComplete: any(named: 'onComplete'),
      timeout: any(named: 'timeout'),
      priority: any(named: 'priority'),
    ),
  ).thenAnswer((invocation) async {
    // Call onComplete callback if provided to signal subscription finished
    final onComplete =
        invocation.namedArguments[const Symbol('onComplete')] as Function()?;
    if (onComplete != null) {
      // Use Future.microtask to call after the subscription is "created"
      Future.microtask(onComplete);
    }
    return 'mock_subscription_${DateTime.now().millisecondsSinceEpoch}';
  });

  // Stub cancelSubscription to do nothing
  when(() => mockSub.cancelSubscription(any())).thenAnswer((_) async {});

  return mockSub;
}

/// Creates a properly stubbed MockBlossomAuthService for testing
///
/// This mock avoids the 15-minute cleanup timer that the real service creates.
MockBlossomAuthService createMockBlossomAuthService() {
  final mockBlossom = MockBlossomAuthService();

  // Stub common methods - use named parameters
  when(
    () => mockBlossom.createGetAuthHeader(
      sha256Hash: any(named: 'sha256Hash'),
      serverUrl: any(named: 'serverUrl'),
    ),
  ).thenAnswer((_) async => null);

  return mockBlossom;
}

/// Creates a properly stubbed MockMediaCacheManager for testing
MockMediaCacheManager createMockMediaCacheManager() {
  final mockCache = MockMediaCacheManager();

  // Stub common methods to return null (cache miss)
  when(() => mockCache.getCachedFileSync(any())).thenReturn(null);
  // Note: downloadFile is not stubbed because it returns non-nullable
  // FileInfo. The FullscreenFeedBloc uses unawaited() for background
  // caching, so this won't block tests. If a test needs it, stub with
  // a real FileInfo mock.

  return mockCache;
}

/// Standard provider overrides that fix most ProviderException failures
List<dynamic> getStandardTestOverrides({
  SharedPreferences? mockSharedPreferences,
  AuthService? mockAuthService,
  SocialService? mockSocialService,
  UserProfileService? mockUserProfileService,
  NostrClient? mockNostrService,
  SubscriptionManager? mockSubscriptionManager,
  BlossomAuthService? mockBlossomAuthService,
  MediaCacheManager? mockMediaCacheManager,
}) {
  final mockPrefs = mockSharedPreferences ?? createMockSharedPreferences();
  final mockAuth = mockAuthService ?? createMockAuthService();
  final mockSocial = mockSocialService ?? createMockSocialService();
  final mockProfile = mockUserProfileService ?? createMockUserProfileService();
  final mockNostr = mockNostrService ?? createMockNostrService();
  final mockSub = mockSubscriptionManager ?? createMockSubscriptionManager();
  final mockBlossom = mockBlossomAuthService ?? createMockBlossomAuthService();
  final mockCache = mockMediaCacheManager ?? createMockMediaCacheManager();

  return [
    // Override sharedPreferencesProvider which throws in production
    sharedPreferencesProvider.overrideWithValue(mockPrefs),

    // Always override NostrClient and SubscriptionManager with stubbed
    // mocks so UserProfileService/FollowRepository never get null
    // Stream<Event> or Future<List<String>> (fixes type errors during
    // ProfileCacheService use).
    nostrServiceProvider.overrideWithValue(mockNostr),
    subscriptionManagerProvider.overrideWithValue(mockSub),

    // Always override BlossomAuthService to avoid 15-minute cleanup timer
    blossomAuthServiceProvider.overrideWithValue(mockBlossom),

    // Always override MediaCacheManager for PooledFullscreenVideoFeedScreen
    mediaCacheProvider.overrideWithValue(mockCache),

    // ONLY override other service providers if explicitly requested
    if (mockAuthService != null)
      authServiceProvider.overrideWithValue(mockAuth),
    if (mockSocialService != null)
      socialServiceProvider.overrideWithValue(mockSocial),
    if (mockUserProfileService != null)
      userProfileServiceProvider.overrideWithValue(mockProfile),
  ];
}

/// Widget wrapper that provides all necessary provider overrides for testing
///
/// Use this instead of raw ProviderScope in widget tests to avoid
/// ProviderException.
///
/// Example:
/// ```dart
/// testWidgets('my test', (tester) async {
///   await tester.pumpWidget(
///     testProviderScope(
///       child: MyWidget(),
///     ),
///   );
/// });
/// ```
Widget testProviderScope({
  required Widget child,
  List<dynamic>? additionalOverrides,
  SharedPreferences? mockSharedPreferences,
  AuthService? mockAuthService,
  SocialService? mockSocialService,
  UserProfileService? mockUserProfileService,
  NostrClient? mockNostrService,
  SubscriptionManager? mockSubscriptionManager,
  BlossomAuthService? mockBlossomAuthService,
  MediaCacheManager? mockMediaCacheManager,
}) {
  return ProviderScope(
    overrides: [
      ...getStandardTestOverrides(
        mockSharedPreferences: mockSharedPreferences,
        mockAuthService: mockAuthService,
        mockSocialService: mockSocialService,
        mockUserProfileService: mockUserProfileService,
        mockNostrService: mockNostrService,
        mockSubscriptionManager: mockSubscriptionManager,
        mockBlossomAuthService: mockBlossomAuthService,
        mockMediaCacheManager: mockMediaCacheManager,
      ),
      ...?additionalOverrides,
    ],
    child: child,
  );
}

/// MaterialApp wrapper with provider overrides for widget tests
///
/// Use this for tests that need both MaterialApp and ProviderScope.
///
/// Example:
/// ```dart
/// testWidgets('my test', (tester) async {
///   await tester.pumpWidget(
///     testMaterialApp(
///       home: MyScreen(),
///     ),
///   );
/// });
/// ```
Widget testMaterialApp({
  Widget? home,
  Map<String, WidgetBuilder>? routes,
  String? initialRoute,
  List<dynamic>? additionalOverrides,
  SharedPreferences? mockSharedPreferences,
  AuthService? mockAuthService,
  SocialService? mockSocialService,
  UserProfileService? mockUserProfileService,
  NostrClient? mockNostrService,
  SubscriptionManager? mockSubscriptionManager,
  BlossomAuthService? mockBlossomAuthService,
  MediaCacheManager? mockMediaCacheManager,
  ThemeData? theme,
}) {
  return testProviderScope(
    additionalOverrides: additionalOverrides,
    mockSharedPreferences: mockSharedPreferences,
    mockAuthService: mockAuthService,
    mockSocialService: mockSocialService,
    mockUserProfileService: mockUserProfileService,
    mockNostrService: mockNostrService,
    mockSubscriptionManager: mockSubscriptionManager,
    mockBlossomAuthService: mockBlossomAuthService,
    mockMediaCacheManager: mockMediaCacheManager,
    child: MaterialApp(
      home: home,
      routes: routes ?? {},
      initialRoute: initialRoute,
      theme: theme ?? ThemeData.dark(),
    ),
  );
}
