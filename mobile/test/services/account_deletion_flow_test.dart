@Tags(['skip_very_good_optimization', 'integration'])
// ABOUTME: Integration test for the reliable account deletion flow
// ABOUTME: Asserts the PR7 contract: NIP-62 retry + abort-on-failure +
// ABOUTME: parallel kind-5 batch + Retry-failed subset.
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/client_utils/keys.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:openvine/services/account_deletion_service.dart';
import 'package:openvine/services/auth_service.dart';

class _MockNostrClient extends Mock implements NostrClient {}

class _MockAuthService extends Mock implements AuthService {}

class _FakeEvent extends Fake implements Event {}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeEvent());
    registerFallbackValue(<Filter>[]);
    registerFallbackValue(const RetryPolicy());
  });

  group('Account Deletion Flow — reliable publish contract', () {
    late _MockNostrClient nostr;
    late _MockAuthService auth;
    late String pubkey;

    setUp(() {
      nostr = _MockNostrClient();
      auth = _MockAuthService();
      final priv = generatePrivateKey();
      pubkey = getPublicKey(priv);
      when(() => auth.isAuthenticated).thenReturn(true);
      when(() => auth.currentPublicKeyHex).thenReturn(pubkey);
      when(
        () => nostr.queryEvents(any()),
      ).thenAnswer((_) async => <Event>[]);
      when(
        () => auth.createAndSignEvent(
          kind: any(named: 'kind'),
          content: any(named: 'content'),
          tags: any(named: 'tags'),
        ),
      ).thenAnswer((invocation) async {
        final kind = invocation.namedArguments[#kind] as int;
        final content = invocation.namedArguments[#content] as String;
        final tags = invocation.namedArguments[#tags] as List<List<String>>;
        return Event(pubkey, kind, tags, content)
          ..id = 'signed_${kind}_${DateTime.now().microsecondsSinceEpoch}'
          ..sig = 'sig';
      });
    });

    test(
      'aborts entire flow when NIP-62 never lands on any relay',
      () async {
        // User has events — but the batch MUST NOT run if NIP-62 fails.
        final userVideo = Event(pubkey, 34236, const [], 'v')..id = 'v1';
        when(
          () => nostr.queryEvents(any()),
        ).thenAnswer((_) async => [userVideo]);

        when(
          () => nostr.publishEventWithRetry(
            any(),
            policy: any(named: 'policy'),
            targetRelays: any(named: 'targetRelays'),
          ),
        ).thenAnswer((invocation) async {
          final event = invocation.positionalArguments[0] as Event;
          return PublishOutcome(
            eventId: event.id,
            acceptedBy: const {},
            rejectedBy: const {},
            noResponseFrom: const {'wss://a', 'wss://b'},
          );
        });

        final service = AccountDeletionService(
          nostrService: nostr,
          authService: auth,
        );
        final result = await service.deleteAccount();

        expect(result.success, isFalse);
        expect(result.failureKind, AccountDeletionFailureKind.nip62Failed);
        expect(result.batch, isNull);
        // Only one publish was attempted — the NIP-62 event.
        verify(
          () => nostr.publishEventWithRetry(
            any(),
            policy: any(named: 'policy'),
            targetRelays: any(named: 'targetRelays'),
          ),
        ).called(1);
        // And critically, queryEvents was never called — we aborted before
        // fetching the user's events.
        verifyNever(() => nostr.queryEvents(any()));
      },
    );

    test(
      'partial kind-5 failure surfaces failedEventIds in result.batch',
      () async {
        final v1 = Event(pubkey, 34236, const [], 'a')..id = 'v1';
        final v2 = Event(pubkey, 1, const [], 'b')..id = 'n1';
        when(
          () => nostr.queryEvents(any()),
        ).thenAnswer((_) async => [v1, v2]);

        when(
          () => nostr.publishEventWithRetry(
            any(),
            policy: any(named: 'policy'),
            targetRelays: any(named: 'targetRelays'),
          ),
        ).thenAnswer((invocation) async {
          final event = invocation.positionalArguments[0] as Event;
          if (event.kind == 62) {
            return PublishOutcome(
              eventId: event.id,
              acceptedBy: const {'wss://a'},
              rejectedBy: const {},
              noResponseFrom: const {},
            );
          }
          // Fail the batch event targeting v1.
          final isForV1 = event.tags.any(
            (t) => t.length >= 2 && t[0] == 'e' && t[1] == 'v1',
          );
          if (isForV1) {
            return PublishOutcome(
              eventId: event.id,
              acceptedBy: const {},
              rejectedBy: const {'wss://a': 'blocked: not allowed'},
              noResponseFrom: const {},
            );
          }
          return PublishOutcome(
            eventId: event.id,
            acceptedBy: const {'wss://a'},
            rejectedBy: const {},
            noResponseFrom: const {},
          );
        });

        final service = AccountDeletionService(
          nostrService: nostr,
          authService: auth,
        );
        final result = await service.deleteAccount();

        expect(result.success, isTrue);
        expect(result.batch, isNotNull);
        expect(result.batch!.failedEventIds, equals({'v1'}));
        expect(result.batch!.succeededEventIds, equals({'n1'}));
        // The original user events must be retained so Retry-failed can
        // re-invoke the service on the subset without another fetch.
        expect(
          result.fetchedEvents.map((e) => e.id),
          containsAll(['v1', 'n1']),
        );
      },
    );

    test(
      'Retry-failed re-runs only the failed subset',
      () async {
        final v1 = Event(pubkey, 34236, const [], 'a')..id = 'v1';
        final v2 = Event(pubkey, 1, const [], 'b')..id = 'n1';
        when(
          () => nostr.queryEvents(any()),
        ).thenAnswer((_) async => [v1, v2]);

        // First pass: NIP-62 ok, v1 batch fails (transient), v2 ok. Second
        // pass (retry): the single batch publish succeeds.
        var call = 0;
        when(
          () => nostr.publishEventWithRetry(
            any(),
            policy: any(named: 'policy'),
            targetRelays: any(named: 'targetRelays'),
          ),
        ).thenAnswer((invocation) async {
          call++;
          final event = invocation.positionalArguments[0] as Event;
          if (event.kind == 62) {
            return PublishOutcome(
              eventId: event.id,
              acceptedBy: const {'wss://a'},
              rejectedBy: const {},
              noResponseFrom: const {},
            );
          }
          final isForV1 = event.tags.any(
            (t) => t.length >= 2 && t[0] == 'e' && t[1] == 'v1',
          );
          if (isForV1 && call <= 3) {
            return PublishOutcome(
              eventId: event.id,
              acceptedBy: const {},
              rejectedBy: const {},
              noResponseFrom: const {'wss://a'},
            );
          }
          return PublishOutcome(
            eventId: event.id,
            acceptedBy: const {'wss://a'},
            rejectedBy: const {},
            noResponseFrom: const {},
          );
        });

        final service = AccountDeletionService(
          nostrService: nostr,
          authService: auth,
        );
        final first = await service.deleteAccount();
        expect(first.batch!.failedEventIds, {'v1'});

        final retry = await service.retryFailedDeletions(
          originalEvents: first.fetchedEvents,
          failedEventIds: first.batch!.failedEventIds,
        );
        expect(retry.succeededEventIds, contains('v1'));
        expect(retry.failedEventIds, isEmpty);
      },
    );

    test(
      'progress callback fires monotonically during kind-5 batch',
      () async {
        final events = [
          Event(pubkey, 1, const [], 'a')..id = 'e1',
          Event(pubkey, 7, const [], 'b')..id = 'e2',
          Event(pubkey, 34236, const [], 'c')..id = 'e3',
        ];
        when(
          () => nostr.queryEvents(any()),
        ).thenAnswer((_) async => events);

        when(
          () => nostr.publishEventWithRetry(
            any(),
            policy: any(named: 'policy'),
            targetRelays: any(named: 'targetRelays'),
          ),
        ).thenAnswer(
          (invocation) async => PublishOutcome(
            eventId: (invocation.positionalArguments[0] as Event).id,
            acceptedBy: const {'wss://a'},
            rejectedBy: const {},
            noResponseFrom: const {},
          ),
        );

        final updates = <(int, int)>[];
        final service = AccountDeletionService(
          nostrService: nostr,
          authService: auth,
        );
        await service.deleteAccount(
          onProgress: (c, t) => updates.add((c, t)),
        );

        expect(updates, isNotEmpty);
        expect(updates.last, (3, 3));
        for (var i = 1; i < updates.length; i++) {
          expect(updates[i].$1, greaterThanOrEqualTo(updates[i - 1].$1));
        }
      },
    );
  });
}
