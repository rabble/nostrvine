// ABOUTME: Tests the event-driven refresh triggers on relayNotificationsProvider
// ABOUTME: App-resume transition and foreground FCM message must drive refresh

import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/providers/app_foreground_provider.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/relay_notifications_provider.dart';
import 'package:openvine/services/auth_service.dart' hide UserProfile;
import 'package:openvine/services/nip98_auth_service.dart';
import 'package:openvine/services/relay_notification_api_service.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:profile_repository/profile_repository.dart';

class _MockRelayNotificationApiService extends Mock
    implements RelayNotificationApiService {}

class _MockAuthService extends Mock implements AuthService {}

class _MockVideoEventService extends Mock implements VideoEventService {}

class _MockProfileRepository extends Mock implements ProfileRepository {}

class _MockNip98AuthService extends Mock implements Nip98AuthService {}

class _TestAppForeground extends AppForeground {
  _TestAppForeground(this._initial);

  final bool _initial;

  @override
  bool build() => _initial;
}

void main() {
  group('RelayNotifications refresh triggers', () {
    late _MockRelayNotificationApiService mockApiService;
    late _MockAuthService mockAuthService;
    late _MockVideoEventService mockVideoEventService;
    late _MockProfileRepository mockProfileRepository;
    late _MockNip98AuthService mockNip98AuthService;
    late StreamController<RemoteMessage> fcmController;

    const testPubkey =
        'test_pubkey_0123456789abcdef0123456789abcdef0123456789abcdef01234567';

    setUp(() {
      mockApiService = _MockRelayNotificationApiService();
      mockAuthService = _MockAuthService();
      mockVideoEventService = _MockVideoEventService();
      mockProfileRepository = _MockProfileRepository();
      mockNip98AuthService = _MockNip98AuthService();
      fcmController = StreamController<RemoteMessage>.broadcast();

      when(() => mockAuthService.isAuthenticated).thenReturn(true);
      when(() => mockAuthService.currentPublicKeyHex).thenReturn(testPubkey);
      when(() => mockAuthService.authState).thenReturn(AuthState.authenticated);
      when(
        () => mockAuthService.authStateStream,
      ).thenAnswer((_) => const Stream<AuthState>.empty());

      when(() => mockApiService.isAvailable).thenReturn(true);
      when(
        () => mockVideoEventService.getVideoEventById(any()),
      ).thenReturn(null);
      when(
        () => mockProfileRepository.getCachedProfile(
          pubkey: any(named: 'pubkey'),
        ),
      ).thenAnswer((_) async => null);
      when(
        () => mockProfileRepository.fetchBatchProfiles(
          pubkeys: any(named: 'pubkeys'),
        ),
      ).thenAnswer((_) async => <String, UserProfile>{});

      // Empty pages so tests stay focused on refresh-trigger plumbing.
      when(
        () => mockApiService.getNotifications(
          pubkey: any(named: 'pubkey'),
          types: any(named: 'types'),
          unreadOnly: any(named: 'unreadOnly'),
          limit: any(named: 'limit'),
          before: any(named: 'before'),
        ),
      ).thenAnswer((_) async => NotificationsResponse.empty);
    });

    tearDown(() async {
      await fcmController.close();
    });

    ProviderContainer buildContainer({required bool initialForeground}) {
      final container = ProviderContainer(
        overrides: [
          currentAuthStateProvider.overrideWithValue(AuthState.authenticated),
          relayNotificationApiServiceProvider.overrideWithValue(mockApiService),
          authServiceProvider.overrideWithValue(mockAuthService),
          videoEventServiceProvider.overrideWithValue(mockVideoEventService),
          nip98AuthServiceProvider.overrideWithValue(mockNip98AuthService),
          profileRepositoryProvider.overrideWithValue(mockProfileRepository),
          firebaseOnMessageProvider.overrideWithValue(fcmController.stream),
          appForegroundProvider.overrideWith(
            () => _TestAppForeground(initialForeground),
          ),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    Future<void> waitForInitialLoad(ProviderContainer container) async {
      await container.read(relayNotificationsProvider.future);
    }

    /// Returns the number of `getNotifications` calls since the previous
    /// invocation of this helper (mocktail's `verify` consumes matched calls).
    /// Returns 0 instead of throwing when no new calls are present.
    int callsSinceLastCheck() {
      try {
        return verify(
          () => mockApiService.getNotifications(
            pubkey: any(named: 'pubkey'),
            types: any(named: 'types'),
            unreadOnly: any(named: 'unreadOnly'),
            limit: any(named: 'limit'),
            before: any(named: 'before'),
          ),
        ).callCount;
      } on TestFailure {
        return 0;
      }
    }

    test('refresh fires when app foreground flips false → true', () async {
      // Start backgrounded so the listener can observe a true transition,
      // not just the initial-build value.
      final container = buildContainer(initialForeground: false);

      await waitForInitialLoad(container);
      // Consume the initial-load call so we measure only the resume effect.
      callsSinceLastCheck();

      container.read(appForegroundProvider.notifier).setForeground(true);
      // Let the refresh future resolve.
      await container.read(relayNotificationsProvider.future);

      expect(
        callsSinceLastCheck(),
        greaterThan(0),
        reason: 'App resume must trigger a refresh',
      );
    });

    test('no refresh when foreground stays true (no transition)', () async {
      final container = buildContainer(initialForeground: true);

      await waitForInitialLoad(container);
      callsSinceLastCheck();

      // Re-set to true — same value as the initial; the edge-trigger guard
      // must skip this case to avoid duplicate work.
      container.read(appForegroundProvider.notifier).setForeground(true);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(
        callsSinceLastCheck(),
        equals(0),
        reason: 'Re-emitting the same foreground value must not refresh',
      );
    });

    test('no refresh on pause transition (true → false)', () async {
      final container = buildContainer(initialForeground: true);

      await waitForInitialLoad(container);
      callsSinceLastCheck();

      container.read(appForegroundProvider.notifier).setForeground(false);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(
        callsSinceLastCheck(),
        equals(0),
        reason: 'Backgrounding must never trigger a refresh',
      );
    });

    test('refresh fires when an FCM message arrives', () async {
      final container = buildContainer(initialForeground: true);

      await waitForInitialLoad(container);
      callsSinceLastCheck();

      fcmController.add(const RemoteMessage(data: {'body': 'New follower'}));
      // FCM listener is sync but refresh is async — pump the queue.
      await Future<void>.delayed(Duration.zero);
      await container.read(relayNotificationsProvider.future);

      expect(
        callsSinceLastCheck(),
        greaterThan(0),
        reason: 'A foreground FCM message must trigger a refresh',
      );
    });

    test('no Timer left scheduled after build', () {
      // The legacy 5-min wall-clock auto-refresh has been removed; the
      // provider must not leak any timer onto the zone scheduler.
      fakeAsync((fake) {
        final container = buildContainer(initialForeground: true);
        container.read(relayNotificationsProvider);
        fake.flushMicrotasks();
        // Allow the initial fetch to settle but do not advance wall-clock.
        fake.elapse(Duration.zero);
        fake.flushMicrotasks();

        // The previous implementation scheduled a Timer here. Now there
        // must be none — the only valid timers in the queue are anything
        // unrelated (none should exist in this isolated container).
        expect(fake.pendingTimers, isEmpty);
      });
    });
  });
}
