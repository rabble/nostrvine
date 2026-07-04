// ABOUTME: Tests provider auth reactivity for PersonalEventCacheService.
// ABOUTME: Ensures late auth initialization flushes queued personal events.

import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_sdk/event.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/personal_event_cache_service.dart';

class _MockAuthService extends Mock implements AuthService {}

const String _userPubkey =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const String _otherPubkey =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

String _hexId(int index) => index.toRadixString(16).padLeft(64, '0');

Event _createEvent({required String pubkey, required String id}) {
  final event = Event(
    pubkey,
    32222,
    const [
      ['d', 'test-video-id'],
      ['title', 'Plants'],
    ],
    'A plant video',
    createdAt: 1700000000,
  );
  event.id = id;
  event.sig = id.padRight(128, '0').substring(0, 128);
  return event;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group(personalEventCacheServiceProvider, () {
    late Directory testDir;
    late _MockAuthService authService;
    late StreamController<AuthState> authStateController;

    setUp(() async {
      // Defend against Hive state leaked by an earlier file in the shared
      // very_good --optimization isolate: this provider suite and the sibling
      // service suite (personal_event_cache_service_test.dart) both open boxes
      // under the same fixed names, so force a clean Hive registry before init
      // (#5738).
      try {
        await Hive.close();
      } on PathNotFoundException catch (_) {}
      testDir = await Directory.systemTemp.createTemp(
        'personal_event_cache_service_provider_test_',
      );
      Hive.init(testDir.path);

      authService = _MockAuthService();
      authStateController = StreamController<AuthState>.broadcast();
      when(() => authService.authState).thenReturn(AuthState.unauthenticated);
      when(
        () => authService.authStateStream,
      ).thenAnswer((_) => authStateController.stream);
      when(() => authService.isAuthenticated).thenReturn(false);
      when(() => authService.currentPublicKeyHex).thenReturn(null);
    });

    tearDown(() async {
      await authStateController.close();
      // PersonalEventCacheService.dispose() closes its Hive boxes
      // fire-and-forget (unawaited _closeBox). Drain the event queue so that
      // close completes before Hive.close() below — otherwise the two race,
      // corrupt Hive's global box registry, and leak box state into the next
      // test in the shared very_good --optimization isolate (#5738). Boxes are
      // opened under fixed global names, so a poisoned registry makes a later
      // test's openBox return a stale box and its writes silently vanish.
      await pumpEventQueue();
      try {
        await Hive.close();
      } on PathNotFoundException catch (_) {
        // Hive may already have removed its lock file during async shutdown.
      }
      try {
        await testDir.delete(recursive: true);
      } on PathNotFoundException catch (_) {
        // Lock file may already be gone after Hive.close().
      }
    });

    ProviderContainer buildContainer() {
      final container = ProviderContainer(
        overrides: [authServiceProvider.overrideWithValue(authService)],
      );
      addTearDown(container.dispose);
      return container;
    }

    Future<void> authenticate() async {
      when(() => authService.authState).thenReturn(AuthState.authenticated);
      when(() => authService.isAuthenticated).thenReturn(true);
      when(() => authService.currentPublicKeyHex).thenReturn(_userPubkey);

      authStateController.add(AuthState.authenticated);
    }

    void unauthenticate() {
      when(() => authService.authState).thenReturn(AuthState.unauthenticated);
      when(() => authService.isAuthenticated).thenReturn(false);
      when(() => authService.currentPublicKeyHex).thenReturn(null);

      authStateController.add(AuthState.unauthenticated);
    }

    void emitChecking() {
      when(() => authService.authState).thenReturn(AuthState.checking);
      when(() => authService.isAuthenticated).thenReturn(false);
      when(() => authService.currentPublicKeyHex).thenReturn(null);

      authStateController.add(AuthState.checking);
    }

    Future<void> waitForInitialized(PersonalEventCacheService service) async {
      for (var attempt = 0; attempt < 20; attempt++) {
        await pumpEventQueue();
        if (service.isInitialized) {
          return;
        }
      }
    }

    Future<void> waitForCachedEvent(
      PersonalEventCacheService service,
      String eventId,
    ) async {
      for (var attempt = 0; attempt < 20; attempt++) {
        await pumpEventQueue();
        if (service.hasEvent(eventId)) {
          return;
        }
      }
    }

    test(
      'initializes when auth becomes ready after provider construction',
      () async {
        final container = buildContainer();
        final subscription = container.listen(
          personalEventCacheServiceProvider,
          (_, _) {},
          fireImmediately: true,
        );
        addTearDown(subscription.close);

        final service = subscription.read();
        expect(service.isInitialized, isFalse);

        await authenticate();
        await waitForInitialized(service);

        expect(service.isInitialized, isTrue);
      },
    );

    test(
      'flushes queued personal events after late auth initialization',
      () async {
        final container = buildContainer();
        final subscription = container.listen(
          personalEventCacheServiceProvider,
          (_, _) {},
          fireImmediately: true,
        );
        addTearDown(subscription.close);
        final ownEvent = _createEvent(pubkey: _userPubkey, id: _hexId(1));
        final otherEvent = _createEvent(pubkey: _otherPubkey, id: _hexId(2));

        final service = subscription.read();
        service.cacheUserEvent(ownEvent);
        service.cacheUserEvent(otherEvent);

        await authenticate();
        await waitForInitialized(service);

        expect(service.hasEvent(ownEvent.id), isTrue);
        expect(service.getEventById(ownEvent.id)?.id, ownEvent.id);
        expect(service.hasEvent(otherEvent.id), isFalse);
        expect(service.getEventById(otherEvent.id), isNull);
      },
    );

    test(
      'keeps queued events through transient non-auth states',
      () async {
        final container = buildContainer();
        final subscription = container.listen(
          personalEventCacheServiceProvider,
          (_, _) {},
          fireImmediately: true,
        );
        addTearDown(subscription.close);
        final ownEvent = _createEvent(pubkey: _userPubkey, id: _hexId(3));

        final service = subscription.read();
        service.cacheUserEvent(ownEvent);

        emitChecking();
        await authenticate();
        await waitForInitialized(service);

        expect(service.hasEvent(ownEvent.id), isTrue);
        expect(service.getEventById(ownEvent.id)?.id, ownEvent.id);
      },
    );

    test(
      'resets active cache session when auth becomes unauthenticated',
      () async {
        final container = buildContainer();
        final subscription = container.listen(
          personalEventCacheServiceProvider,
          (_, _) {},
          fireImmediately: true,
        );
        addTearDown(subscription.close);
        final ownEvent = _createEvent(pubkey: _userPubkey, id: _hexId(4));

        final service = subscription.read();
        await authenticate();
        await waitForInitialized(service);
        service.cacheUserEvent(ownEvent);
        await waitForCachedEvent(service, ownEvent.id);
        expect(service.hasEvent(ownEvent.id), isTrue);

        unauthenticate();
        await pumpEventQueue();

        expect(service.isInitialized, isFalse);
        expect(service.hasEvent(ownEvent.id), isFalse);
        expect(service.getEventById(ownEvent.id), isNull);
      },
    );
  });
}
