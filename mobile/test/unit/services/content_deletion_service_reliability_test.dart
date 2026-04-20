// ABOUTME: Tests that ContentDeletionService uses publishEventWithRetry
// ABOUTME: and surfaces the outcome via DeleteResult.

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart' hide LogCategory, NIP71VideoKinds;
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/event_kind.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/content_deletion_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    // Stub the auth signing helper that ContentDeletionService uses.
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
        ..id = 'a' * 64
        ..sig = 'sig';
    });
  });

  VideoEvent buildUserVideo() {
    return VideoEvent(
      id: 'b' * 64,
      pubkey: testPubkey,
      createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      content: '',
      timestamp: DateTime.now(),
      title: 'user video',
    );
  }

  group('ContentDeletionService reliability', () {
    test(
      'success path: accepted-by-any → success + outcome + feedback',
      () async {
        when(
          () => nostr.publishEventWithRetry(
            any(),
            policy: any(named: 'policy'),
            targetRelays: any(named: 'targetRelays'),
          ),
        ).thenAnswer(
          (_) async => PublishOutcome(
            eventId: 'a' * 64,
            acceptedBy: const {'wss://a'},
            rejectedBy: const {},
            noResponseFrom: const {},
          ),
        );

        final prefs = await SharedPreferences.getInstance();
        final service = ContentDeletionService(
          nostrService: nostr,
          authService: auth,
          prefs: prefs,
        );
        await service.initialize();

        final result = await service.deleteContent(
          video: buildUserVideo(),
          reason: 'test',
        );

        expect(result.success, isTrue);
        expect(result.outcome, isNotNull);
        expect(result.outcome!.acceptedBy, {'wss://a'});
        expect(result.feedback?.severity, PublishSeverity.success);
        expect(result.feedback?.retryable, isFalse);
        expect(service.deletionHistory, hasLength(1));
      },
    );

    test(
      'transient failure: all-no-response → retryable failure, NO history',
      () async {
        when(
          () => nostr.publishEventWithRetry(
            any(),
            policy: any(named: 'policy'),
            targetRelays: any(named: 'targetRelays'),
          ),
        ).thenAnswer(
          (_) async => PublishOutcome(
            eventId: 'a' * 64,
            acceptedBy: const {},
            rejectedBy: const {},
            noResponseFrom: const {'wss://a', 'wss://b'},
          ),
        );

        final prefs = await SharedPreferences.getInstance();
        final service = ContentDeletionService(
          nostrService: nostr,
          authService: auth,
          prefs: prefs,
        );
        await service.initialize();

        final result = await service.deleteContent(
          video: buildUserVideo(),
          reason: 'test',
        );

        expect(result.success, isFalse);
        expect(result.feedback?.retryable, isTrue);
        expect(result.feedback?.messageKey, 'publish_no_relay_response');
        // Contract change from the old "save locally even on failure"
        // behavior: no history entry until the relay accepts.
        expect(service.deletionHistory, isEmpty);
      },
    );

    test(
      'permanent rejection surfaces non-retryable feedback with reason',
      () async {
        when(
          () => nostr.publishEventWithRetry(
            any(),
            policy: any(named: 'policy'),
            targetRelays: any(named: 'targetRelays'),
          ),
        ).thenAnswer(
          (_) async => PublishOutcome(
            eventId: 'a' * 64,
            acceptedBy: const {},
            rejectedBy: const {'wss://a': 'blocked: not allowed'},
            noResponseFrom: const {},
          ),
        );

        final prefs = await SharedPreferences.getInstance();
        final service = ContentDeletionService(
          nostrService: nostr,
          authService: auth,
          prefs: prefs,
        );
        await service.initialize();

        final result = await service.deleteContent(
          video: buildUserVideo(),
          reason: 'test',
        );

        expect(result.success, isFalse);
        expect(result.feedback?.retryable, isFalse);
        expect(result.feedback?.messageKey, 'publish_rejected_permanent');
        expect(result.feedback?.firstRejectionReason, 'blocked: not allowed');
        expect(service.deletionHistory, isEmpty);
      },
    );
  });
}
