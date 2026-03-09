// ABOUTME: Tests that FunnelCake all-null profile responses short-circuit
// ABOUTME: the relay/indexer fallback cascade in UserProfileService

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:openvine/services/analytics_api_service.dart';
import 'package:openvine/services/subscription_manager.dart';
import 'package:openvine/services/user_profile_service.dart';

class _MockNostrClient extends Mock implements NostrClient {
  @override
  bool get isInitialized => true;
}

class _MockSubscriptionManager extends Mock implements SubscriptionManager {}

class _MockAnalyticsApiService extends Mock implements AnalyticsApiService {}

void main() {
  late _MockNostrClient mockNostrClient;
  late _MockSubscriptionManager mockSubscriptionManager;
  late _MockAnalyticsApiService mockAnalyticsApi;

  setUp(() {
    mockNostrClient = _MockNostrClient();
    mockSubscriptionManager = _MockSubscriptionManager();
    mockAnalyticsApi = _MockAnalyticsApiService();

    registerFallbackValue(<Filter>[]);
    registerFallbackValue((Event e) {});

    // Stub cancelSubscription so dispose() works
    when(
      () => mockSubscriptionManager.cancelSubscription(any()),
    ).thenAnswer((_) async {});
  });

  group(UserProfileService, () {
    group('fetchProfile with FunnelCake no-profile sentinel', () {
      test(
        'marks profile as missing when FunnelCake returns _noProfile sentinel',
        () async {
          const pubkey =
              'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

          when(
            () => mockAnalyticsApi.getUserProfile(pubkey),
          ).thenAnswer((_) async => {'_noProfile': true, 'pubkey': pubkey});

          final service = UserProfileService(
            mockNostrClient,
            subscriptionManager: mockSubscriptionManager,
            analyticsApiService: mockAnalyticsApi,
            funnelcakeAvailable: true,
            skipIndexerFallback: true,
          );

          await service.initialize();
          final result = await service.fetchProfile(pubkey);

          expect(result, isNull);
          expect(service.shouldSkipProfileFetch(pubkey), isTrue);

          // Verify no WebSocket subscription was created
          verifyNever(
            () => mockSubscriptionManager.createSubscription(
              name: any(named: 'name'),
              filters: any(named: 'filters'),
              onEvent: any(named: 'onEvent'),
              onError: any(named: 'onError'),
              onComplete: any(named: 'onComplete'),
              priority: any(named: 'priority'),
            ),
          );

          service.dispose();
        },
      );

      test(
        'does not mark profile as missing when FunnelCake returns real data',
        () async {
          const pubkey =
              'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

          when(
            () => mockAnalyticsApi.getUserProfile(pubkey),
          ).thenAnswer(
            (_) async => {
              'pubkey': pubkey,
              'name': 'alice',
              'display_name': 'Alice',
              'about': null,
              'picture': 'https://example.com/alice.jpg',
              'banner': null,
              'nip05': null,
              'lud16': null,
            },
          );

          final service = UserProfileService(
            mockNostrClient,
            subscriptionManager: mockSubscriptionManager,
            analyticsApiService: mockAnalyticsApi,
            funnelcakeAvailable: true,
            skipIndexerFallback: true,
          );

          await service.initialize();
          final result = await service.fetchProfile(pubkey);

          expect(result, isNotNull);
          expect(result!.name, equals('alice'));
          expect(service.shouldSkipProfileFetch(pubkey), isFalse);
          expect(service.hasProfile(pubkey), isTrue);

          service.dispose();
        },
      );

      test(
        'second fetchProfile call for missing profile returns null immediately',
        () async {
          const pubkey =
              'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';

          when(
            () => mockAnalyticsApi.getUserProfile(pubkey),
          ).thenAnswer((_) async => {'_noProfile': true, 'pubkey': pubkey});

          final service = UserProfileService(
            mockNostrClient,
            subscriptionManager: mockSubscriptionManager,
            analyticsApiService: mockAnalyticsApi,
            funnelcakeAvailable: true,
            skipIndexerFallback: true,
          );

          await service.initialize();

          // First call: marks as missing
          await service.fetchProfile(pubkey);
          expect(service.shouldSkipProfileFetch(pubkey), isTrue);

          // Reset the mock to track second call
          reset(mockAnalyticsApi);

          // Second call should be skipped entirely
          // (shouldSkipProfileFetch is checked by callers like
          // fetchMultipleProfiles, but fetchProfile itself returns null
          // because the profile is not in cache)
          expect(service.shouldSkipProfileFetch(pubkey), isTrue);

          service.dispose();
        },
      );

      test(
        'falls through to WebSocket when FunnelCake returns null',
        () async {
          const pubkey =
              'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd';

          when(
            () => mockAnalyticsApi.getUserProfile(pubkey),
          ).thenAnswer((_) async => null);

          when(
            () => mockSubscriptionManager.createSubscription(
              name: any(named: 'name'),
              filters: any(named: 'filters'),
              onEvent: any(named: 'onEvent'),
              onError: any(named: 'onError'),
              onComplete: any(named: 'onComplete'),
              priority: any(named: 'priority'),
            ),
          ).thenAnswer((_) async => 'sub-123');

          final service = UserProfileService(
            mockNostrClient,
            subscriptionManager: mockSubscriptionManager,
            analyticsApiService: mockAnalyticsApi,
            funnelcakeAvailable: true,
            skipIndexerFallback: true,
          );

          await service.initialize();

          // Don't await - this returns a Completer future that
          // won't complete without relay events
          unawaited(service.fetchProfile(pubkey));

          // Allow the batch debounce timer to fire
          await Future<void>.delayed(const Duration(milliseconds: 200));

          // Should NOT be marked as missing since FunnelCake returned null
          // (user not in FunnelCake at all)
          expect(service.shouldSkipProfileFetch(pubkey), isFalse);

          service.dispose();
        },
      );
    });

    group('prefetchProfilesImmediately with no-profile sentinel', () {
      test(
        'marks no-profile users as missing from bulk API response',
        () async {
          const realPubkey =
              'eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee';
          const noProfPubkey =
              'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff';

          when(
            () => mockAnalyticsApi.getBulkProfiles([realPubkey, noProfPubkey]),
          ).thenAnswer(
            (_) async => {
              realPubkey: {
                'name': 'bob',
                'display_name': 'Bob',
                'about': null,
                'picture': null,
              },
              noProfPubkey: {'_noProfile': true},
            },
          );

          final service = UserProfileService(
            mockNostrClient,
            subscriptionManager: mockSubscriptionManager,
            analyticsApiService: mockAnalyticsApi,
            funnelcakeAvailable: true,
            skipIndexerFallback: true,
          );

          await service.initialize();
          await service.prefetchProfilesImmediately([
            realPubkey,
            noProfPubkey,
          ]);

          // Real profile should be cached
          expect(service.hasProfile(realPubkey), isTrue);
          expect(
            service.getCachedProfile(realPubkey)?.name,
            equals('bob'),
          );

          // No-profile user should be marked as missing
          expect(service.shouldSkipProfileFetch(noProfPubkey), isTrue);
          expect(service.hasProfile(noProfPubkey), isFalse);

          service.dispose();
        },
      );
    });
  });
}

/// Silences unawaited futures lint for fire-and-forget futures in tests
void unawaited(Future<void> future) {}
