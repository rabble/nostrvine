// ABOUTME: Tests that ContentBlocklistService uses publishEventWithRetry
// ABOUTME: and gates runtime blocklist on relay acceptance of the kind 30000 event.

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/content_blocklist_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockNostrClient extends Mock implements NostrClient {}

class _MockAuthService extends Mock implements AuthService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const ourPubkey =
      '0000000000000000000000000000000000000000000000000000000000000001';
  const targetPubkey =
      '0000000000000000000000000000000000000000000000000000000000000002';

  setUpAll(() {
    registerFallbackValue(
      Event(ourPubkey, 30000, const [], '')
        ..id = 'a' * 64
        ..sig = 'sig',
    );
    registerFallbackValue(const RetryPolicy());
  });

  late _MockNostrClient nostr;
  late _MockAuthService auth;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    nostr = _MockNostrClient();
    auth = _MockAuthService();
    when(() => nostr.isInitialized).thenReturn(true);
    when(() => nostr.publicKey).thenReturn(ourPubkey);
    when(() => auth.isAuthenticated).thenReturn(true);
    when(() => auth.currentPublicKeyHex).thenReturn(ourPubkey);
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
      return Event(ourPubkey, kind, tags, content)
        ..id = 'b' * 64
        ..sig = 'sig';
    });
  });

  Future<ContentBlocklistService> buildService() async {
    final prefs = await SharedPreferences.getInstance();
    final service = ContentBlocklistService(prefs: prefs);
    await service.attachNostrServices(
      nostrClient: nostr,
      authService: auth,
      ourPubkey: ourPubkey,
    );
    return service;
  }

  group('ContentBlocklistService reliability', () {
    test(
      'success path: relay accepts → pubkey added + success feedback',
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

        final result = await service.blockUser(
          targetPubkey,
          ourPubkey: ourPubkey,
        );

        expect(result.success, isTrue);
        expect(result.outcome!.acceptedBy, {'wss://a'});
        expect(result.feedback?.severity, PublishSeverity.success);
        expect(result.feedback?.retryable, isFalse);
        expect(service.isBlocked(targetPubkey), isTrue);
        // Severed-follower tracking commits with the block.
        expect(service.isFollowSevered(targetPubkey), isTrue);
      },
    );

    test(
      'transient failure: rollback + retryable feedback, pubkey NOT added',
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
            noResponseFrom: const {'wss://a'},
          ),
        );

        final service = await buildService();

        final result = await service.blockUser(
          targetPubkey,
          ourPubkey: ourPubkey,
        );

        expect(result.success, isFalse);
        expect(result.feedback?.retryable, isTrue);
        expect(result.feedback?.messageKey, 'publish_no_relay_response');
        // Silent-divergence fix: blocklist must NOT commit when no relay
        // accepted — otherwise on reinstall the relay has no record and the
        // user sees content from the supposedly-blocked pubkey.
        expect(service.isBlocked(targetPubkey), isFalse);
        expect(service.isFollowSevered(targetPubkey), isFalse);
      },
    );

    test(
      'permanent rejection: non-retryable feedback with reason + rollback',
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
            rejectedBy: const {'wss://a': 'blocked: spam'},
            noResponseFrom: const {},
          ),
        );

        final service = await buildService();

        final result = await service.blockUser(
          targetPubkey,
          ourPubkey: ourPubkey,
        );

        expect(result.success, isFalse);
        expect(result.feedback?.retryable, isFalse);
        expect(result.feedback?.messageKey, 'publish_rejected_permanent');
        expect(result.feedback?.firstRejectionReason, 'blocked: spam');
        expect(service.isBlocked(targetPubkey), isFalse);
      },
    );

    test(
      'unblock: rollback keeps user blocked when relay rejects',
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
        final blockResult = await service.blockUser(
          targetPubkey,
          ourPubkey: ourPubkey,
        );
        expect(blockResult.success, isTrue);
        expect(service.isBlocked(targetPubkey), isTrue);

        // Fail the unblock.
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

        final unblockResult = await service.unblockUser(targetPubkey);
        expect(unblockResult.success, isFalse);
        expect(unblockResult.feedback?.retryable, isTrue);
        expect(
          service.isBlocked(targetPubkey),
          isTrue,
          reason:
              'Unblock must not commit locally when the relay did not '
              'accept the updated kind 30000 event.',
        );
      },
    );

    test(
      'blocking an already-blocked user is a no-op success (no relay call)',
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
        await service.blockUser(targetPubkey, ourPubkey: ourPubkey);

        final result = await service.blockUser(
          targetPubkey,
          ourPubkey: ourPubkey,
        );
        expect(result.success, isTrue);
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
      'self-block is rejected as a pre-publish failure — no relay call',
      () async {
        final service = await buildService();

        final result = await service.blockUser(
          ourPubkey,
          ourPubkey: ourPubkey,
        );

        expect(result.success, isFalse);
        expect(service.isBlocked(ourPubkey), isFalse);
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
