// ABOUTME: Verifies SocialService.publishRightToBeForgotten surfaces
// ABOUTME: PublishOutcome-driven failure.

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/social_service.dart';

class _MockNostrClient extends Mock implements NostrClient {}

class _MockAuthService extends Mock implements AuthService {}

const _testPubkey =
    '82341f882b6eabcd2ba7f1ef90aad961cf074af15b9ef44a09f9d2a8fbfbe6a2';

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

Event _buildSignedEvent({required int kind}) =>
    Event(
        _testPubkey,
        kind,
        const [],
        'content',
      )
      ..id = 'a' * 64
      ..sig = 'sig';

void main() {
  late _MockNostrClient nostr;
  late _MockAuthService auth;
  late SocialService service;

  setUpAll(() {
    registerFallbackValue(_buildSignedEvent(kind: 30000));
    registerFallbackValue(const RetryPolicy());
  });

  setUp(() {
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
      return _buildSignedEvent(kind: kind);
    });
    service = SocialService(nostr, auth);
  });

  group('SocialService.publishRightToBeForgotten', () {
    test('accepts on acceptedByAny and does not throw', () async {
      when(
        () => nostr.publishEventWithRetry(
          any(),
          policy: any(named: 'policy'),
          targetRelays: any(named: 'targetRelays'),
        ),
      ).thenAnswer((_) async => _accepted('a' * 64));

      await service.publishRightToBeForgotten();

      verify(
        () => nostr.publishEventWithRetry(
          any(),
          policy: any(named: 'policy'),
          targetRelays: any(named: 'targetRelays'),
        ),
      ).called(1);
    });

    test(
      'throws when no relay accepts — caller learns about the failure',
      () async {
        when(
          () => nostr.publishEventWithRetry(
            any(),
            policy: any(named: 'policy'),
            targetRelays: any(named: 'targetRelays'),
          ),
        ).thenAnswer((_) async => _transient('a' * 64));

        expect(
          () => service.publishRightToBeForgotten(),
          throwsA(isA<Exception>()),
        );
      },
    );
  });
}
