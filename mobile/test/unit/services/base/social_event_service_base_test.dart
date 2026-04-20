// ABOUTME: Tests SocialEventServiceBase.broadcastAndCacheEvent routes through
// ABOUTME: publishEventWithRetry and surfaces PublishOutcome via the new
// ABOUTME: broadcastAndCacheEventAwaitOk sibling.

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/event_kind.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/base/social_event_service_base.dart';
import 'package:openvine/services/personal_event_cache_service.dart';

class _MockNostrClient extends Mock implements NostrClient {}

class _MockAuthService extends Mock implements AuthService {}

class _MockPersonalCache extends Mock implements PersonalEventCacheService {}

class _TestSocialEventService extends SocialEventServiceBase {
  _TestSocialEventService({
    required this.nostrService,
    required this.authService,
    required this.personalEventCache,
  });

  @override
  final NostrClient nostrService;
  @override
  final AuthService authService;
  @override
  final PersonalEventCacheService? personalEventCache;
}

const _testPubkey =
    '82341f882b6eabcd2ba7f1ef90aad961cf074af15b9ef44a09f9d2a8fbfbe6a2';

Event _buildEvent() {
  return Event(_testPubkey, EventKind.reaction, const [
      ['e', 'target'],
    ], '+')
    ..id = 'a' * 64
    ..sig = 'sig';
}

PublishOutcome _accepted(String id) => PublishOutcome(
  eventId: id,
  acceptedBy: const {'wss://relay.example.com'},
  rejectedBy: const {},
  noResponseFrom: const {},
);

PublishOutcome _transient(String id) => PublishOutcome(
  eventId: id,
  acceptedBy: const {},
  rejectedBy: const {},
  noResponseFrom: const {'wss://relay.example.com'},
);

void main() {
  late _MockNostrClient nostr;
  late _MockAuthService auth;
  late _MockPersonalCache cache;
  late _TestSocialEventService service;

  setUpAll(() {
    registerFallbackValue(_buildEvent());
    registerFallbackValue(const RetryPolicy());
  });

  setUp(() {
    nostr = _MockNostrClient();
    auth = _MockAuthService();
    cache = _MockPersonalCache();
    service = _TestSocialEventService(
      nostrService: nostr,
      authService: auth,
      personalEventCache: cache,
    );
  });

  group('SocialEventServiceBase', () {
    test(
      'broadcastAndCacheEvent returns event id and caches on acceptedByAny',
      () async {
        final event = _buildEvent();
        when(
          () => nostr.publishEventWithRetry(
            any(),
            policy: any(named: 'policy'),
            targetRelays: any(named: 'targetRelays'),
          ),
        ).thenAnswer((_) async => _accepted(event.id));

        final id = await service.broadcastAndCacheEvent(event);

        expect(id, equals(event.id));
        verify(() => cache.cacheUserEvent(event)).called(1);
      },
    );

    test(
      'broadcastAndCacheEvent throws and does NOT cache on failure',
      () async {
        final event = _buildEvent();
        when(
          () => nostr.publishEventWithRetry(
            any(),
            policy: any(named: 'policy'),
            targetRelays: any(named: 'targetRelays'),
          ),
        ).thenAnswer((_) async => _transient(event.id));

        expect(
          () => service.broadcastAndCacheEvent(event),
          throwsA(isA<Exception>()),
        );

        // Wait for the future to complete so mocktail settles.
        try {
          await service.broadcastAndCacheEvent(event);
        } on Exception {
          // expected
        }

        verifyNever(() => cache.cacheUserEvent(any()));
      },
    );

    test(
      'broadcastAndCacheEventAwaitOk surfaces outcome to caller',
      () async {
        final event = _buildEvent();
        when(
          () => nostr.publishEventWithRetry(
            any(),
            policy: any(named: 'policy'),
            targetRelays: any(named: 'targetRelays'),
          ),
        ).thenAnswer((_) async => _transient(event.id));

        final outcome = await service.broadcastAndCacheEventAwaitOk(event);

        expect(outcome.acceptedByAny, isFalse);
        expect(outcome.transientRelays, {'wss://relay.example.com'});
        verifyNever(() => cache.cacheUserEvent(any()));
      },
    );
  });
}
