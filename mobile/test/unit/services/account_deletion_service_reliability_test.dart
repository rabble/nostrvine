// ABOUTME: Tests that AccountDeletionService uses publishEventWithRetry for
// ABOUTME: NIP-62 with a 5-attempt policy, aborts on NIP-62 failure, and
// ABOUTME: executes the kind-5 batch in parallel with per-event outcome
// ABOUTME: tracking.

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/event_kind.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:openvine/services/account_deletion_service.dart';
import 'package:openvine/services/auth_service.dart';

class _MockNostrClient extends Mock implements NostrClient {}

class _MockAuthService extends Mock implements AuthService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const testPubkey =
      '0000000000000000000000000000000000000000000000000000000000000001';

  setUpAll(() {
    registerFallbackValue(
      Event(testPubkey, EventKind.eventDeletion, const [], '')
        ..id = 'x' * 64
        ..sig = 'sig',
    );
    registerFallbackValue(const RetryPolicy());
    registerFallbackValue(<Filter>[]);
  });

  late _MockNostrClient nostr;
  late _MockAuthService auth;

  PublishOutcome acceptedOutcome(String eventId) => PublishOutcome(
    eventId: eventId,
    acceptedBy: const {'wss://relay.a'},
    rejectedBy: const {},
    noResponseFrom: const {},
  );

  PublishOutcome noResponseOutcome(String eventId) => PublishOutcome(
    eventId: eventId,
    acceptedBy: const {},
    rejectedBy: const {},
    noResponseFrom: const {'wss://relay.a', 'wss://relay.b'},
  );

  PublishOutcome permanentlyRejectedOutcome(String eventId) => PublishOutcome(
    eventId: eventId,
    acceptedBy: const {},
    rejectedBy: const {'wss://relay.a': 'blocked: not allowed'},
    noResponseFrom: const {},
  );

  Event buildUserEvent({required int kind, required String id}) {
    final e = Event(testPubkey, kind, const [], 'content')
      ..id = id
      ..sig = 'sig';
    return e;
  }

  setUp(() {
    nostr = _MockNostrClient();
    auth = _MockAuthService();
    when(() => auth.isAuthenticated).thenReturn(true);
    when(() => auth.currentPublicKeyHex).thenReturn(testPubkey);
    when(
      () => nostr.queryEvents(any()),
    ).thenAnswer((_) async => <Event>[]);
    // Default: signer returns a signed event echoing kind/content/tags.
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
      return Event(testPubkey, kind, tags, content)
        ..id = 'signed_${kind}_${DateTime.now().microsecondsSinceEpoch}'
        ..sig = 'sig';
    });
  });

  group('AccountDeletionService NIP-62 publish', () {
    test(
      'success path: NIP-62 publish succeeds and kind-5 batch runs',
      () async {
        final userVideo = buildUserEvent(kind: 34236, id: 'video_1');
        when(
          () => nostr.queryEvents(any()),
        ).thenAnswer((_) async => [userVideo]);

        when(
          () => nostr.publishEventWithRetry(
            any(),
            policy: any(named: 'policy'),
            targetRelays: any(named: 'targetRelays'),
          ),
        ).thenAnswer(
          (invocation) async =>
              acceptedOutcome((invocation.positionalArguments[0] as Event).id),
        );

        final service = AccountDeletionService(
          nostrService: nostr,
          authService: auth,
        );
        final result = await service.deleteAccount();

        expect(result.success, isTrue);
        expect(result.nip62Outcome, isNotNull);
        expect(result.nip62Outcome!.acceptedByAny, isTrue);
        expect(result.nip62Feedback?.severity, PublishSeverity.success);
        expect(result.batch, isNotNull);
        expect(result.batch!.succeededEventIds, hasLength(1));
        expect(result.batch!.failedEventIds, isEmpty);
        // 2 publish calls: 1 NIP-62 + 1 per-kind batch kind-5 event.
        verify(
          () => nostr.publishEventWithRetry(
            any(),
            policy: any(named: 'policy'),
            targetRelays: any(named: 'targetRelays'),
          ),
        ).called(2);
      },
    );

    test(
      'NIP-62 never lands: aborts before running kind-5 batch',
      () async {
        // Even if the user has events, the batch must not run when NIP-62
        // fails.
        final userVideo = buildUserEvent(kind: 34236, id: 'video_1');
        when(
          () => nostr.queryEvents(any()),
        ).thenAnswer((_) async => [userVideo]);

        when(
          () => nostr.publishEventWithRetry(
            any(),
            policy: any(named: 'policy'),
            targetRelays: any(named: 'targetRelays'),
          ),
        ).thenAnswer(
          (invocation) async => noResponseOutcome(
            (invocation.positionalArguments[0] as Event).id,
          ),
        );

        final service = AccountDeletionService(
          nostrService: nostr,
          authService: auth,
        );
        final result = await service.deleteAccount();

        expect(result.success, isFalse);
        expect(result.failureKind, AccountDeletionFailureKind.nip62Failed);
        expect(result.nip62Outcome, isNotNull);
        expect(result.nip62Feedback?.retryable, isTrue);
        expect(result.batch, isNull);
        // Only the NIP-62 publish was attempted.
        verify(
          () => nostr.publishEventWithRetry(
            any(),
            policy: any(named: 'policy'),
            targetRelays: any(named: 'targetRelays'),
          ),
        ).called(1);
      },
    );

    test(
      'NIP-62 permanent rejection surfaces non-retryable feedback + reason',
      () async {
        when(
          () => nostr.publishEventWithRetry(
            any(),
            policy: any(named: 'policy'),
            targetRelays: any(named: 'targetRelays'),
          ),
        ).thenAnswer(
          (invocation) async => permanentlyRejectedOutcome(
            (invocation.positionalArguments[0] as Event).id,
          ),
        );

        final service = AccountDeletionService(
          nostrService: nostr,
          authService: auth,
        );
        final result = await service.deleteAccount();

        expect(result.success, isFalse);
        expect(result.failureKind, AccountDeletionFailureKind.nip62Failed);
        expect(result.nip62Feedback?.retryable, isFalse);
        expect(
          result.nip62Feedback?.messageKey,
          'publish_rejected_permanent',
        );
        expect(
          result.nip62Feedback?.firstRejectionReason,
          'blocked: not allowed',
        );
        expect(result.batch, isNull);
      },
    );

    test(
      'NIP-62 uses RetryPolicy with maxAttempts = 5',
      () async {
        when(
          () => nostr.publishEventWithRetry(
            any(),
            policy: any(named: 'policy'),
            targetRelays: any(named: 'targetRelays'),
          ),
        ).thenAnswer(
          (invocation) async =>
              acceptedOutcome((invocation.positionalArguments[0] as Event).id),
        );

        final service = AccountDeletionService(
          nostrService: nostr,
          authService: auth,
        );
        await service.deleteAccount();

        final captured = verify(
          () => nostr.publishEventWithRetry(
            any(that: predicate<Event>((e) => e.kind == 62)),
            policy: captureAny(named: 'policy'),
            targetRelays: any(named: 'targetRelays'),
          ),
        ).captured;
        final policy = captured.first as RetryPolicy;
        expect(policy.maxAttempts, 5);
      },
    );
  });

  group('AccountDeletionService batch kind-5', () {
    test(
      'partial failure reports succeeded + failed event IDs and feedbacks',
      () async {
        // Two user events of different kinds → two kind-5 batch events.
        final v1 = buildUserEvent(kind: 34236, id: 'video_a');
        final v2 = buildUserEvent(kind: 7, id: 'react_a');
        when(
          () => nostr.queryEvents(any()),
        ).thenAnswer((_) async => [v1, v2]);

        // Signer returns predictable kind-5 events we can match on. First
        // kind-5 for kind=34236, second for kind=7, third is the NIP-62.
        var signCount = 0;
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
          signCount++;
          return Event(testPubkey, kind, tags, content)
            ..id = 'signed_${kind}_$signCount'
            ..sig = 'sig';
        });

        // NIP-62 accepted, one kind-5 accepted, other kind-5 rejected
        // permanently.
        when(
          () => nostr.publishEventWithRetry(
            any(),
            policy: any(named: 'policy'),
            targetRelays: any(named: 'targetRelays'),
          ),
        ).thenAnswer((invocation) async {
          final event = invocation.positionalArguments[0] as Event;
          if (event.kind == 62) return acceptedOutcome(event.id);
          // kind-5: match on e-tag to decide which fails.
          final isForReact = event.tags.any(
            (t) => t.length >= 2 && t[0] == 'e' && t[1] == 'react_a',
          );
          if (isForReact) return permanentlyRejectedOutcome(event.id);
          return acceptedOutcome(event.id);
        });

        final service = AccountDeletionService(
          nostrService: nostr,
          authService: auth,
        );
        final result = await service.deleteAccount();

        expect(result.success, isTrue); // NIP-62 landed → flow succeeded.
        expect(result.batch, isNotNull);
        expect(result.batch!.succeededEventIds, contains('video_a'));
        expect(result.batch!.failedEventIds, contains('react_a'));
        expect(result.batch!.feedbacks['react_a']?.retryable, isFalse);
      },
    );

    test(
      'progress callback fires with (completed, total) during batch',
      () async {
        final v1 = buildUserEvent(kind: 34236, id: 'v1');
        final v2 = buildUserEvent(kind: 1, id: 'v2');
        final v3 = buildUserEvent(kind: 7, id: 'v3');
        when(
          () => nostr.queryEvents(any()),
        ).thenAnswer((_) async => [v1, v2, v3]);

        when(
          () => nostr.publishEventWithRetry(
            any(),
            policy: any(named: 'policy'),
            targetRelays: any(named: 'targetRelays'),
          ),
        ).thenAnswer(
          (invocation) async =>
              acceptedOutcome((invocation.positionalArguments[0] as Event).id),
        );

        final updates = <({int completed, int total})>[];
        final service = AccountDeletionService(
          nostrService: nostr,
          authService: auth,
        );
        await service.deleteAccount(
          onProgress: (c, t) => updates.add((completed: c, total: t)),
        );

        expect(updates, isNotEmpty);
        // Final update is (3, 3).
        expect(updates.last, (completed: 3, total: 3));
        // Monotonic progress.
        for (var i = 1; i < updates.length; i++) {
          expect(
            updates[i].completed,
            greaterThanOrEqualTo(updates[i - 1].completed),
          );
        }
      },
    );

    test(
      'retryFailedDeletions re-runs only the failed subset',
      () async {
        final v1 = buildUserEvent(kind: 34236, id: 'v1');
        final v2 = buildUserEvent(kind: 1, id: 'v2');
        when(
          () => nostr.queryEvents(any()),
        ).thenAnswer((_) async => [v1, v2]);

        // First pass: NIP-62 ok, v1 fails, v2 ok.
        // Second pass: only v1's kind-5 should be retried; this time ok.
        var callNumber = 0;
        when(
          () => nostr.publishEventWithRetry(
            any(),
            policy: any(named: 'policy'),
            targetRelays: any(named: 'targetRelays'),
          ),
        ).thenAnswer((invocation) async {
          callNumber++;
          final event = invocation.positionalArguments[0] as Event;
          if (event.kind == 62) return acceptedOutcome(event.id);
          final isForV1 = event.tags.any(
            (t) => t.length >= 2 && t[0] == 'e' && t[1] == 'v1',
          );
          if (isForV1 && callNumber <= 3) {
            return noResponseOutcome(event.id);
          }
          return acceptedOutcome(event.id);
        });

        final service = AccountDeletionService(
          nostrService: nostr,
          authService: auth,
        );
        final first = await service.deleteAccount();
        expect(first.batch!.failedEventIds, equals({'v1'}));

        // Now retry only the failed subset.
        final retry = await service.retryFailedDeletions(
          originalEvents: [v1, v2],
          failedEventIds: first.batch!.failedEventIds,
        );
        expect(retry.succeededEventIds, contains('v1'));
        expect(retry.failedEventIds, isEmpty);
      },
    );

    test(
      'cancel mid-batch stops queueing new publishes',
      () async {
        // Many events so we can cancel before they all finish.
        final events = List.generate(
          20,
          (i) => buildUserEvent(kind: 30023 + i, id: 'e$i'),
        );
        when(
          () => nostr.queryEvents(any()),
        ).thenAnswer((_) async => events);

        final token = AccountDeletionCancellationToken();
        var calls = 0;
        when(
          () => nostr.publishEventWithRetry(
            any(),
            policy: any(named: 'policy'),
            targetRelays: any(named: 'targetRelays'),
          ),
        ).thenAnswer((invocation) async {
          final event = invocation.positionalArguments[0] as Event;
          if (event.kind == 62) return acceptedOutcome(event.id);
          calls++;
          // Cancel as soon as the batch starts.
          if (calls == 1) token.cancel();
          // Simulate a slow relay so concurrency matters.
          await Future<void>.delayed(const Duration(milliseconds: 10));
          return acceptedOutcome(event.id);
        });

        final service = AccountDeletionService(
          nostrService: nostr,
          authService: auth,
        );
        final result = await service.deleteAccount(cancellationToken: token);

        // We should NOT have published a kind-5 for every event — the batch
        // was cancelled after the first in-flight publish.
        expect(result.batch, isNotNull);
        final totalTouched =
            result.batch!.succeededEventIds.length +
            result.batch!.failedEventIds.length;
        expect(totalTouched, lessThan(events.length));
      },
    );
  });
}
