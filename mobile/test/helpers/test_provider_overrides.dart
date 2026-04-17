// ABOUTME: Centralized provider overrides for widget tests to fix ProviderException failures
// ABOUTME: Provides mock implementations of all providers that throw UnimplementedError in production

import 'package:blossom_upload_service/blossom_upload_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_cache/media_cache.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:openvine/features/feature_flags/services/build_configuration.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/nip05_verification_provider.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/moderation_label_service.dart';
import 'package:openvine/services/nip05_verification_service.dart';
import 'package:openvine/services/openvine_media_cache.dart';
import 'package:openvine/services/social_service.dart';
import 'package:openvine/services/subscription_manager.dart';
import 'package:profile_repository/profile_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Mock classes (public because they are imported by many test files)
class MockSharedPreferences extends Mock implements SharedPreferences {}

class MockSocialService extends Mock implements SocialService {}

class MockAuthService extends Mock implements AuthService {}

class MockSubscriptionManager extends Mock implements SubscriptionManager {}

class MockBlossomAuthService extends Mock implements BlossomAuthService {}

class MockMediaCacheManager extends Mock implements MediaCacheManager {}

class MockNostrClient extends Mock implements NostrClient {}

class MockProfileRepository extends Mock implements ProfileRepository {}

class MockNip05VerificationService extends Mock
    implements Nip05VerificationService {}

class MockModerationLabelService extends Mock
    implements ModerationLabelService {}

/// Flags whose BuildConfiguration default is off in production but whose
/// test-suite behaviour assumes they are on. Widget tests for these surfaces
/// pre-date the feature flag gate, so we enable them by default here instead
/// of scattering per-test overrides.
const Map<FeatureFlag, bool> _testDefaultFlagValues = {
  FeatureFlag.feedAutoAdvance: true,
};

/// Test BuildConfiguration that overrides the production defaults for the
/// flags listed in [_testDefaultFlagValues]. Used to make sure widget tests
/// render the relevant UI even when the production env var is unset.
class _TestBuildConfiguration extends BuildConfiguration {
  const _TestBuildConfiguration();

  @override
  bool getDefault(FeatureFlag flag) {
    final overridden = _testDefaultFlagValues[flag];
    if (overridden != null) return overridden;
    return super.getDefault(flag);
  }
}

/// Creates a properly stubbed MockSharedPreferences for testing
MockSharedPreferences createMockSharedPreferences() {
  final mockPrefs = MockSharedPreferences();

  // Stub all FeatureFlag methods to return sensible defaults
  for (final flag in FeatureFlag.values) {
    // Flags that the test suite expects to be ON by default so existing
    // widget tests don't need per-file overrides. Add new flags here only
    // if the legacy test behaviour assumed the feature was already live.
    final defaultValue = _testDefaultFlagValues[flag];
    when(() => mockPrefs.getBool('ff_${flag.name}')).thenReturn(defaultValue);
    when(
      () => mockPrefs.setBool('ff_${flag.name}', any()),
    ).thenAnswer((_) async => true);
    when(
      () => mockPrefs.remove('ff_${flag.name}'),
    ).thenAnswer((_) async => true);
    when(
      () => mockPrefs.containsKey('ff_${flag.name}'),
    ).thenReturn(defaultValue != null);
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

  // Stub authState and authStateStream so currentAuthStateProvider does not
  // crash with type 'Null' is not a subtype of type 'Stream<AuthState>'
  when(() => mockAuth.authState).thenReturn(AuthState.unauthenticated);
  when(
    () => mockAuth.authStateStream,
  ).thenAnswer((_) => const Stream<AuthState>.empty());

  return mockAuth;
}

/// Creates a properly stubbed MockSocialService for testing
MockSocialService createMockSocialService() {
  final mockSocial = MockSocialService();

  // Stub common methods to return empty results by default
  when(() => mockSocial.getUserVideoCount(any())).thenAnswer((_) async => 0);

  return mockSocial;
}

/// Creates a properly stubbed MockNostrClient for testing
MockNostrClient createMockNostrService() {
  final mockNostr = MockNostrClient();

  // Stub common properties
  when(() => mockNostr.isInitialized).thenReturn(true);
  when(() => mockNostr.hasKeys).thenReturn(false);
  when(() => mockNostr.connectedRelayCount).thenReturn(1);
  when(() => mockNostr.configuredRelays).thenReturn(<String>[]);

  // Stub subscribe() to return empty stream (never null) so
  // SubscriptionManager batch fetch does not get
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
  // and immediately call onComplete to simulate empty results.
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

/// Creates a properly stubbed MockProfileRepository for testing
MockProfileRepository createMockProfileRepository() {
  final mockRepo = MockProfileRepository();

  when(
    () => mockRepo.getCachedProfile(pubkey: any(named: 'pubkey')),
  ).thenAnswer((_) async => null);
  when(
    () => mockRepo.fetchFreshProfile(pubkey: any(named: 'pubkey')),
  ).thenAnswer((_) async => null);
  when(
    () => mockRepo.watchProfile(pubkey: any(named: 'pubkey')),
  ).thenAnswer((_) => Stream.value(null));

  return mockRepo;
}

/// Creates a properly stubbed MockNip05VerificationService for testing
MockNip05VerificationService createMockNip05VerificationService() {
  final mockService = MockNip05VerificationService();

  when(() => mockService.getCachedStatus(any())).thenReturn(null);
  when(
    () => mockService.getVerificationStatus(any(), any()),
  ).thenAnswer((_) async => Nip05VerificationStatus.none);
  when(() => mockService.addListener(any())).thenReturn(null);
  when(() => mockService.removeListener(any())).thenReturn(null);

  return mockService;
}

/// Creates a properly stubbed MockModerationLabelService for testing
///
/// This mock avoids the real NIP-05 HTTP call that
/// `ModerationLabelService.initialize()` triggers via `Nip05Validor.getPubkey`,
/// which creates pending Dio timers that break `pumpAndSettle`.
MockModerationLabelService createMockModerationLabelService() {
  final mock = MockModerationLabelService();

  when(() => mock.divineModerationPubkeyHex).thenReturn(
    ModerationLabelService.fallbackModerationPubkeyHex,
  );
  when(() => mock.subscribedLabelers).thenReturn({});
  when(() => mock.isDivineLabelerSubscribed).thenReturn(false);
  when(() => mock.customLabelers).thenReturn({});
  when(() => mock.isFollowingModerationEnabled).thenReturn(false);
  when(mock.initialize).thenAnswer((_) async {});
  when(() => mock.getContentWarnings(any())).thenReturn([]);
  when(() => mock.getContentWarningsByAddressableId(any())).thenReturn([]);
  when(() => mock.getContentWarningsByHash(any())).thenReturn([]);
  when(() => mock.getLabelsForPubkey(any())).thenReturn([]);
  when(() => mock.getAIDetectionResult(any())).thenReturn(null);
  when(() => mock.getAIDetectionByHash(any())).thenReturn(null);
  when(() => mock.hasContentWarning(any())).thenReturn(false);
  when(() => mock.subscribeToLabeler(any())).thenAnswer((_) async {});
  when(() => mock.addLabeler(any())).thenAnswer((_) async {});
  when(() => mock.removeLabeler(any())).thenAnswer((_) async {});
  when(mock.addDivineLabeler).thenAnswer((_) async {});
  when(mock.removeDivineLabeler).thenAnswer((_) async {});
  when(
    () => mock.setFollowingModerationEnabled(
      any(),
      followedPubkeys: any(named: 'followedPubkeys'),
    ),
  ).thenAnswer((_) async {});
  when(() => mock.syncFollowedLabelers(any())).thenAnswer((_) async {});

  return mock;
}

/// Standard provider overrides that fix most ProviderException failures
List<dynamic> getStandardTestOverrides({
  SharedPreferences? mockSharedPreferences,
  AuthService? mockAuthService,
  SocialService? mockSocialService,
  NostrClient? mockNostrService,
  SubscriptionManager? mockSubscriptionManager,
  BlossomAuthService? mockBlossomAuthService,
  MediaCacheManager? mockMediaCacheManager,
  ProfileRepository? mockProfileRepository,
  Nip05VerificationService? mockNip05VerificationService,
  ModerationLabelService? mockModerationLabelService,
}) {
  final mockPrefs = mockSharedPreferences ?? createMockSharedPreferences();
  final mockAuth = mockAuthService ?? createMockAuthService();
  final mockSocial = mockSocialService ?? createMockSocialService();
  final mockNostr = mockNostrService ?? createMockNostrService();
  final mockSub = mockSubscriptionManager ?? createMockSubscriptionManager();
  final mockBlossom = mockBlossomAuthService ?? createMockBlossomAuthService();
  final mockCache = mockMediaCacheManager ?? createMockMediaCacheManager();
  final mockProfile = mockProfileRepository ?? createMockProfileRepository();
  final mockModeration =
      mockModerationLabelService ?? createMockModerationLabelService();

  return [
    // Override sharedPreferencesProvider which throws in production
    sharedPreferencesProvider.overrideWithValue(mockPrefs),

    // Override BuildConfiguration so flags listed in _testDefaultFlagValues
    // are enabled by default across widget tests.
    buildConfigurationProvider.overrideWithValue(
      const _TestBuildConfiguration(),
    ),

    // Always override NostrClient and SubscriptionManager with stubbed mocks
    // so FollowRepository never gets null Stream<Event> or
    // Future<List<String>>.
    nostrServiceProvider.overrideWithValue(mockNostr),
    subscriptionManagerProvider.overrideWithValue(mockSub),

    // Always override BlossomAuthService to avoid 15-minute cleanup timer
    blossomAuthServiceProvider.overrideWithValue(mockBlossom),

    // Always override MediaCacheManager for PooledFullscreenVideoFeedScreen
    mediaCacheProvider.overrideWithValue(mockCache),

    // Always override ModerationLabelService to avoid NIP-05 HTTP calls
    // from initialize() → _resolveModerationPubkey() → Nip05Validor.getPubkey
    moderationLabelServiceProvider.overrideWithValue(mockModeration),

    // Override NIP-05 verification service to avoid opening Drift/SQLite in
    // widget tests that only care about badge presence, not verification.
    if (mockNip05VerificationService != null)
      nip05VerificationServiceProvider.overrideWithValue(
        mockNip05VerificationService,
      ),

    // ONLY override other service providers if explicitly requested
    if (mockAuthService != null)
      authServiceProvider.overrideWithValue(mockAuth),
    if (mockSocialService != null)
      socialServiceProvider.overrideWithValue(mockSocial),
    if (mockProfileRepository != null)
      profileRepositoryProvider.overrideWithValue(mockProfile),
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
  NostrClient? mockNostrService,
  SubscriptionManager? mockSubscriptionManager,
  BlossomAuthService? mockBlossomAuthService,
  MediaCacheManager? mockMediaCacheManager,
  ProfileRepository? mockProfileRepository,
  Nip05VerificationService? mockNip05VerificationService,
  ModerationLabelService? mockModerationLabelService,
}) {
  return ProviderScope(
    overrides: [
      ...getStandardTestOverrides(
        mockSharedPreferences: mockSharedPreferences,
        mockAuthService: mockAuthService,
        mockSocialService: mockSocialService,
        mockNostrService: mockNostrService,
        mockSubscriptionManager: mockSubscriptionManager,
        mockBlossomAuthService: mockBlossomAuthService,
        mockMediaCacheManager: mockMediaCacheManager,
        mockProfileRepository: mockProfileRepository,
        mockNip05VerificationService: mockNip05VerificationService,
        mockModerationLabelService: mockModerationLabelService,
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
  NostrClient? mockNostrService,
  SubscriptionManager? mockSubscriptionManager,
  BlossomAuthService? mockBlossomAuthService,
  MediaCacheManager? mockMediaCacheManager,
  ProfileRepository? mockProfileRepository,
  Nip05VerificationService? mockNip05VerificationService,
  ModerationLabelService? mockModerationLabelService,
  ThemeData? theme,
}) {
  return testProviderScope(
    additionalOverrides: additionalOverrides,
    mockSharedPreferences: mockSharedPreferences,
    mockAuthService: mockAuthService,
    mockSocialService: mockSocialService,
    mockNostrService: mockNostrService,
    mockSubscriptionManager: mockSubscriptionManager,
    mockBlossomAuthService: mockBlossomAuthService,
    mockMediaCacheManager: mockMediaCacheManager,
    mockProfileRepository: mockProfileRepository,
    mockNip05VerificationService: mockNip05VerificationService,
    mockModerationLabelService: mockModerationLabelService,
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
      routes: routes ?? {},
      initialRoute: initialRoute,
      theme: theme ?? ThemeData.dark(),
    ),
  );
}
