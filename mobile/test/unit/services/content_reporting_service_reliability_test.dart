// ABOUTME: Tests that ContentReportingService uses publishEventWithRetry,
// ABOUTME: preserves moderation relay targeting through retries, and only
// ABOUTME: commits report history on relay acceptance.

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/event_kind.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/content_moderation_service.dart';
import 'package:openvine/services/content_reporting_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockNostrClient extends Mock implements NostrClient {}

class _MockAuthService extends Mock implements AuthService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const testPubkey =
      '0000000000000000000000000000000000000000000000000000000000000001';
  const authorPubkey =
      '0000000000000000000000000000000000000000000000000000000000000002';

  setUpAll(() {
    registerFallbackValue(
      Event(testPubkey, EventKind.report, const [], '')
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

  Future<ContentReportingService> buildService() async {
    final prefs = await SharedPreferences.getInstance();
    final service = ContentReportingService(
      nostrService: nostr,
      authService: auth,
      prefs: prefs,
    );
    await service.initialize();
    return service;
  }

  group('ContentReportingService reliability', () {
    test(
      'success: targetRelays is [moderationRelayUrl], history committed, '
      'feedback success',
      () async {
        List<String>? capturedTargets;
        when(
          () => nostr.publishEventWithRetry(
            any(),
            policy: any(named: 'policy'),
            targetRelays: any(named: 'targetRelays'),
          ),
        ).thenAnswer((invocation) async {
          capturedTargets =
              invocation.namedArguments[#targetRelays] as List<String>?;
          return PublishOutcome(
            eventId: 'b' * 64,
            acceptedBy: const {'wss://relay.divine.video'},
            rejectedBy: const {},
            noResponseFrom: const {},
          );
        });

        final service = await buildService();

        final result = await service.reportContent(
          eventId: 'evt_1',
          authorPubkey: authorPubkey,
          reason: ContentFilterReason.spam,
          details: 'spam',
        );

        expect(result.success, isTrue);
        expect(result.outcome, isNotNull);
        expect(result.feedback?.severity, PublishSeverity.success);
        expect(result.reportId, isNotNull);
        expect(service.reportHistory, hasLength(1));
        expect(
          capturedTargets,
          equals([ContentReportingService.moderationRelayUrl]),
          reason:
              'Reports must be published to the moderation relay only — '
              'preserve targetRelays through the retry path.',
        );
      },
    );

    test(
      'transient failure: NO history entry, retryable feedback',
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
            noResponseFrom: const {'wss://relay.divine.video'},
          ),
        );

        final service = await buildService();

        final result = await service.reportContent(
          eventId: 'evt_1',
          authorPubkey: authorPubkey,
          reason: ContentFilterReason.spam,
          details: 'spam',
        );

        expect(result.success, isFalse);
        expect(result.feedback?.retryable, isTrue);
        expect(result.feedback?.messageKey, 'publish_no_relay_response');
        // No history commit — previous "save locally even on failure" was
        // a silent-failure bug for reports: user saw "Report submitted"
        // while no moderation relay ever received the kind 1984.
        expect(service.reportHistory, isEmpty);
      },
    );

    test(
      'permanent rejection: history NOT committed, reason surfaced',
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
            rejectedBy: const {
              'wss://relay.divine.video': 'blocked: invalid report',
            },
            noResponseFrom: const {},
          ),
        );

        final service = await buildService();

        final result = await service.reportContent(
          eventId: 'evt_1',
          authorPubkey: authorPubkey,
          reason: ContentFilterReason.spam,
          details: 'spam',
        );

        expect(result.success, isFalse);
        expect(result.feedback?.retryable, isFalse);
        expect(result.feedback?.messageKey, 'publish_rejected_permanent');
        expect(
          result.feedback?.firstRejectionReason,
          'blocked: invalid report',
        );
        expect(service.reportHistory, isEmpty);
      },
    );

    test('not-authenticated surfaces pre-publish failure', () async {
      when(() => auth.isAuthenticated).thenReturn(false);
      final service = await buildService();

      final result = await service.reportContent(
        eventId: 'evt_1',
        authorPubkey: authorPubkey,
        reason: ContentFilterReason.spam,
        details: 'spam',
      );

      expect(result.success, isFalse);
      expect(result.outcome, isNull);
      expect(result.feedback, isNull);
      expect(result.error, contains('Not authenticated'));
      verifyNever(
        () => nostr.publishEventWithRetry(
          any(),
          policy: any(named: 'policy'),
          targetRelays: any(named: 'targetRelays'),
        ),
      );
    });
  });
}
