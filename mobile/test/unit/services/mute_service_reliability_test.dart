// ABOUTME: Tests that MuteService uses publishEventWithRetry and gates
// ABOUTME: in-memory mute state on relay acceptance (fixes silent-divergence bug).

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/mute_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockNostrClient extends Mock implements NostrClient {}

class _MockAuthService extends Mock implements AuthService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const testPubkey =
      '0000000000000000000000000000000000000000000000000000000000000001';
  const targetPubkey =
      '0000000000000000000000000000000000000000000000000000000000000002';

  setUpAll(() {
    registerFallbackValue(
      Event(testPubkey, 10000, const [], '')
        ..id = 'a' * 64
        ..sig = 'sig',
    );
    registerFallbackValue(const RetryPolicy());
  });

  late _MockNostrClient nostr;
  late _MockAuthService auth;

  setUp(() async {
    nostr = _MockNostrClient();
    auth = _MockAuthService();
    SharedPreferences.setMockInitialValues({});
    when(() => nostr.isInitialized).thenReturn(true);
    when(() => nostr.publicKey).thenReturn(testPubkey);
    when(() => auth.isAuthenticated).thenReturn(true);
    when(() => auth.currentPublicKeyHex).thenReturn(testPubkey);
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
        ..id = 'b' * 64
        ..sig = 'sig';
    });
  });

  Future<MuteService> buildService() async {
    final prefs = await SharedPreferences.getInstance();
    final service = MuteService(
      nostrService: nostr,
      authService: auth,
      prefs: prefs,
    );
    await service.initialize();
    return service;
  }

  group('MuteService reliability', () {
    test(
      'success path: relay accepts → item committed + success feedback',
      () async {
        when(
          () => nostr.publishEventWithRetry(
            any(),
            policy: any(named: 'policy'),
            targetRelays: any(named: 'targetRelays'),
          ),
        ).thenAnswer(
          (_) async => PublishOutcome(
            eventId: 'b' * 64,
            acceptedBy: const {'wss://a'},
            rejectedBy: const {},
            noResponseFrom: const {},
          ),
        );

        final service = await buildService();

        final result = await service.muteUser(targetPubkey);

        expect(result.success, isTrue);
        expect(result.outcome, isNotNull);
        expect(result.outcome!.acceptedBy, {'wss://a'});
        expect(result.feedback?.severity, PublishSeverity.success);
        expect(result.feedback?.retryable, isFalse);
        expect(service.isUserMuted(targetPubkey), isTrue);
      },
    );

    test(
      'transient failure: all-no-response → rollback + retryable feedback',
      () async {
        when(
          () => nostr.publishEventWithRetry(
            any(),
            policy: any(named: 'policy'),
            targetRelays: any(named: 'targetRelays'),
          ),
        ).thenAnswer(
          (_) async => PublishOutcome(
            eventId: 'b' * 64,
            acceptedBy: const {},
            rejectedBy: const {},
            noResponseFrom: const {'wss://a', 'wss://b'},
          ),
        );

        final service = await buildService();

        final result = await service.muteUser(targetPubkey);

        expect(result.success, isFalse);
        expect(result.feedback?.retryable, isTrue);
        expect(result.feedback?.messageKey, 'publish_no_relay_response');
        // Critical: the silent-divergence fix — in-memory mute set must NOT
        // commit when no relay accepted.
        expect(
          service.isUserMuted(targetPubkey),
          isFalse,
          reason:
              'Mute set must roll back when no relay accepted — otherwise '
              'the user believes the pubkey is muted but no relay stored it.',
        );
      },
    );

    test(
      'permanent rejection surfaces non-retryable feedback with reason + rollback',
      () async {
        when(
          () => nostr.publishEventWithRetry(
            any(),
            policy: any(named: 'policy'),
            targetRelays: any(named: 'targetRelays'),
          ),
        ).thenAnswer(
          (_) async => PublishOutcome(
            eventId: 'b' * 64,
            acceptedBy: const {},
            rejectedBy: const {'wss://a': 'blocked: not allowed'},
            noResponseFrom: const {},
          ),
        );

        final service = await buildService();

        final result = await service.muteUser(targetPubkey);

        expect(result.success, isFalse);
        expect(result.feedback?.retryable, isFalse);
        expect(result.feedback?.messageKey, 'publish_rejected_permanent');
        expect(result.feedback?.firstRejectionReason, 'blocked: not allowed');
        expect(service.isUserMuted(targetPubkey), isFalse);
      },
    );

    test(
      'unmute: rollback restores muted state when relay rejects',
      () async {
        // First, successful mute
        when(
          () => nostr.publishEventWithRetry(
            any(),
            policy: any(named: 'policy'),
            targetRelays: any(named: 'targetRelays'),
          ),
        ).thenAnswer(
          (_) async => PublishOutcome(
            eventId: 'b' * 64,
            acceptedBy: const {'wss://a'},
            rejectedBy: const {},
            noResponseFrom: const {},
          ),
        );
        final service = await buildService();
        final mutedResult = await service.muteUser(targetPubkey);
        expect(mutedResult.success, isTrue);
        expect(service.isUserMuted(targetPubkey), isTrue);

        // Now fail the unmute publish — the user must still be muted.
        when(
          () => nostr.publishEventWithRetry(
            any(),
            policy: any(named: 'policy'),
            targetRelays: any(named: 'targetRelays'),
          ),
        ).thenAnswer(
          (_) async => PublishOutcome(
            eventId: 'b' * 64,
            acceptedBy: const {},
            rejectedBy: const {},
            noResponseFrom: const {'wss://a'},
          ),
        );
        final unmutedResult = await service.unmuteUser(targetPubkey);
        expect(unmutedResult.success, isFalse);
        expect(unmutedResult.feedback?.retryable, isTrue);
        expect(
          service.isUserMuted(targetPubkey),
          isTrue,
          reason:
              'Unmute rollback: user must remain muted when relay did not '
              'accept the updated mute list.',
        );
      },
    );

    test(
      'muting an already-muted item is a no-op success (no relay call)',
      () async {
        when(
          () => nostr.publishEventWithRetry(
            any(),
            policy: any(named: 'policy'),
            targetRelays: any(named: 'targetRelays'),
          ),
        ).thenAnswer(
          (_) async => PublishOutcome(
            eventId: 'b' * 64,
            acceptedBy: const {'wss://a'},
            rejectedBy: const {},
            noResponseFrom: const {},
          ),
        );
        final service = await buildService();
        await service.muteUser(targetPubkey);

        // Second call: already muted, must not republish.
        final result = await service.muteUser(targetPubkey);
        expect(result.success, isTrue);
        // One call for the first mute — second is short-circuited.
        verify(
          () => nostr.publishEventWithRetry(
            any(),
            policy: any(named: 'policy'),
            targetRelays: any(named: 'targetRelays'),
          ),
        ).called(1);
      },
    );
  });
}
