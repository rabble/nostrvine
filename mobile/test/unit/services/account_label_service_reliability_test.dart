// ABOUTME: Tests that AccountLabelService uses publishEventWithRetry for
// ABOUTME: kind 1985 self-label publishes and gates local commit on
// ABOUTME: acceptedByAny.

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:openvine/models/content_label.dart';
import 'package:openvine/services/account_label_service.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockNostrClient extends Mock implements NostrClient {}

class _MockAuthService extends Mock implements AuthService {}

const _testPubkey =
    '0000000000000000000000000000000000000000000000000000000000000001';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(
      Event(_testPubkey, 1985, const [], '')
        ..id = 'e' * 64
        ..sig = 'sig',
    );
    registerFallbackValue(const RetryPolicy());
  });

  late _MockNostrClient nostr;
  late _MockAuthService auth;

  Event signed({required int kind, required List<List<String>> tags}) {
    return Event(_testPubkey, kind, tags, '')
      ..id = 'e' * 64
      ..sig = 'sig';
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    nostr = _MockNostrClient();
    auth = _MockAuthService();

    when(() => auth.isAuthenticated).thenReturn(true);
    when(() => auth.currentPublicKeyHex).thenReturn(_testPubkey);
    when(
      () => auth.createAndSignEvent(
        kind: any(named: 'kind'),
        content: any(named: 'content'),
        tags: any(named: 'tags'),
      ),
    ).thenAnswer((invocation) async {
      final kind = invocation.namedArguments[#kind] as int;
      final tags = invocation.namedArguments[#tags] as List<List<String>>;
      return signed(kind: kind, tags: tags);
    });
  });

  PublishOutcome acceptedOutcome() => PublishOutcome(
    eventId: 'e' * 64,
    acceptedBy: const {'wss://a'},
    rejectedBy: const {},
    noResponseFrom: const {},
  );

  PublishOutcome transientOutcome() => PublishOutcome(
    eventId: 'e' * 64,
    acceptedBy: const {},
    rejectedBy: const {},
    noResponseFrom: const {'wss://a'},
  );

  PublishOutcome rejectedOutcome() => PublishOutcome(
    eventId: 'e' * 64,
    acceptedBy: const {},
    rejectedBy: const {'wss://a': 'blocked: not allowed'},
    noResponseFrom: const {},
  );

  group('AccountLabelService reliability (kind 1985)', () {
    test(
      'success: accepted-by-any commits local labels and reports success',
      () async {
        when(
          () => nostr.publishEventWithRetry(
            any(),
            policy: any(named: 'policy'),
            targetRelays: any(named: 'targetRelays'),
          ),
        ).thenAnswer((_) async => acceptedOutcome());

        final service = AccountLabelService(
          authService: auth,
          nostrClient: nostr,
        );
        await service.initialize();

        final result = await service.setAccountLabels(
          {ContentLabel.nudity},
        );

        expect(result.success, isTrue);
        expect(result.feedback?.severity, PublishSeverity.success);
        expect(service.accountLabels, {ContentLabel.nudity});
      },
    );

    test(
      'transient failure: retryable feedback, rollback to previous labels',
      () async {
        when(
          () => nostr.publishEventWithRetry(
            any(),
            policy: any(named: 'policy'),
            targetRelays: any(named: 'targetRelays'),
          ),
        ).thenAnswer((_) async => acceptedOutcome());

        // Seed with an initial label accepted by the relay.
        final service = AccountLabelService(
          authService: auth,
          nostrClient: nostr,
        );
        await service.initialize();
        await service.setAccountLabels({ContentLabel.violence});
        expect(service.accountLabels, {ContentLabel.violence});

        // Now change the labels under a transient failure.
        when(
          () => nostr.publishEventWithRetry(
            any(),
            policy: any(named: 'policy'),
            targetRelays: any(named: 'targetRelays'),
          ),
        ).thenAnswer((_) async => transientOutcome());

        final result = await service.setAccountLabels(
          {ContentLabel.nudity},
        );

        expect(result.success, isFalse);
        expect(result.feedback?.retryable, isTrue);
        // Rollback: previous labels intact.
        expect(service.accountLabels, {ContentLabel.violence});
      },
    );

    test(
      'permanent rejection: non-retryable feedback with reason, rollback',
      () async {
        when(
          () => nostr.publishEventWithRetry(
            any(),
            policy: any(named: 'policy'),
            targetRelays: any(named: 'targetRelays'),
          ),
        ).thenAnswer((_) async => rejectedOutcome());

        final service = AccountLabelService(
          authService: auth,
          nostrClient: nostr,
        );
        await service.initialize();

        final result = await service.setAccountLabels(
          {ContentLabel.nudity},
        );

        expect(result.success, isFalse);
        expect(result.feedback?.retryable, isFalse);
        expect(result.feedback?.firstRejectionReason, 'blocked: not allowed');
        expect(service.accountLabels, isEmpty);
      },
    );

    test(
      'missing pubkey failure rolls back optimistic local labels',
      () async {
        when(
          () => nostr.publishEventWithRetry(
            any(),
            policy: any(named: 'policy'),
            targetRelays: any(named: 'targetRelays'),
          ),
        ).thenAnswer((_) async => acceptedOutcome());

        final service = AccountLabelService(
          authService: auth,
          nostrClient: nostr,
        );
        await service.initialize();
        await service.setAccountLabels({ContentLabel.violence});
        expect(service.accountLabels, {ContentLabel.violence});

        when(() => auth.currentPublicKeyHex).thenReturn(null);

        final result = await service.setAccountLabels(
          {ContentLabel.nudity},
        );
        final prefs = await SharedPreferences.getInstance();

        expect(result.success, isFalse);
        expect(service.accountLabels, {ContentLabel.violence});
        expect(
          ContentLabel.fromCsv(prefs.getString('account_content_label')),
          {ContentLabel.violence},
        );
      },
    );

    test(
      'clear labels (empty set): no publish attempted, local commit wins',
      () async {
        // Starting with empty labels, clearing should be a no-op success
        // that never hits the relay.
        final service = AccountLabelService(
          authService: auth,
          nostrClient: nostr,
        );
        await service.initialize();

        final result = await service.setAccountLabels(const {});

        expect(result.success, isTrue);
        expect(service.accountLabels, isEmpty);
        verifyNever(
          () => nostr.publishEventWithRetry(
            any(),
            policy: any(named: 'policy'),
            targetRelays: any(named: 'targetRelays'),
          ),
        );
      },
    );
  });
}
