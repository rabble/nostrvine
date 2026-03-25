import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_sdk/event.dart';
import 'package:openvine/models/nostr_app_audit_event.dart';
import 'package:openvine/services/nip98_auth_service.dart';
import 'package:openvine/services/nostr_app_audit_service.dart';

class MockNip98AuthService extends Mock implements Nip98AuthService {}

void main() {
  group('NostrAppAuditService', () {
    late MockNip98AuthService mockNip98AuthService;

    setUp(() {
      mockNip98AuthService = MockNip98AuthService();
    });

    test('records bridge decisions in a local queue', () {
      final service = NostrAppAuditService(
        workerBaseUri: Uri.parse('https://apps.directory.divine.video'),
        nip98AuthService: mockNip98AuthService,
        httpClient: MockClient((_) async => http.Response('', 200)),
      );

      final event = _auditEvent();
      service.record(event);

      expect(service.queuedEvents, hasLength(1));
      expect(service.queuedEvents.single, equals(event));
    });

    test(
      'uploads sanitized payloads and clears the queue on success',
      () async {
        final capturedRequests = <http.Request>[];

        final service = NostrAppAuditService(
          workerBaseUri: Uri.parse('https://apps.directory.divine.video'),
          nip98AuthService: mockNip98AuthService,
          httpClient: MockClient((request) async {
            capturedRequests.add(request);
            return http.Response('{"success":true}', 200);
          }),
        );

        final event = _auditEvent(
          errorCode: 'blocked_origin',
          decision: NostrAppAuditDecision.blocked,
        );
        service.record(event);

        when(
          () => mockNip98AuthService.createAuthToken(
            url: any(named: 'url'),
            method: HttpMethod.post,
            payload: any(named: 'payload'),
          ),
        ).thenAnswer(
          (_) async => Nip98Token(
            token: 'audit-token',
            signedEvent: _createMockEvent(),
            createdAt: DateTime.utc(2026, 3, 25),
            expiresAt: DateTime.utc(
              2026,
              3,
              25,
            ).add(const Duration(minutes: 10)),
          ),
        );

        final uploaded = await service.uploadQueuedEvents();

        expect(uploaded, 1);
        expect(service.queuedEvents, isEmpty);
        expect(capturedRequests, hasLength(1));

        final request = capturedRequests.single;
        expect(
          request.url.toString(),
          'https://apps.directory.divine.video/v1/audit-events',
        );
        expect(request.headers['authorization'], 'Nostr audit-token');
        expect(request.headers['content-type'], contains('application/json'));

        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body, containsPair('app_id', 17));
        expect(body, containsPair('origin', 'https://primal.net'));
        expect(body, containsPair('method', 'signEvent'));
        expect(body, containsPair('event_kind', 1));
        expect(body, containsPair('decision', 'blocked'));
        expect(body, containsPair('error_code', 'blocked_origin'));
        expect(body.containsKey('user_pubkey'), isFalse);
        expect(body.containsKey('created_at'), isFalse);

        verify(
          () => mockNip98AuthService.createAuthToken(
            url: 'https://apps.directory.divine.video/v1/audit-events',
            method: HttpMethod.post,
            payload: request.body,
          ),
        ).called(1);
      },
    );

    test('keeps queued events when upload fails', () async {
      final service = NostrAppAuditService(
        workerBaseUri: Uri.parse('https://apps.directory.divine.video'),
        nip98AuthService: mockNip98AuthService,
        httpClient: MockClient((_) async => http.Response('Server error', 500)),
      );

      service.record(_auditEvent());

      when(
        () => mockNip98AuthService.createAuthToken(
          url: any(named: 'url'),
          method: HttpMethod.post,
          payload: any(named: 'payload'),
        ),
      ).thenAnswer(
        (_) async => Nip98Token(
          token: 'audit-token',
          signedEvent: _createMockEvent(),
          createdAt: DateTime.utc(2026, 3, 25),
          expiresAt: DateTime.utc(2026, 3, 25).add(const Duration(minutes: 10)),
        ),
      );

      final uploaded = await service.uploadQueuedEvents();

      expect(uploaded, 0);
      expect(service.queuedEvents, hasLength(1));
    });

    test('coalesces concurrent upload attempts', () async {
      final responseCompleter = Completer<http.Response>();
      var requestCount = 0;
      final service = NostrAppAuditService(
        workerBaseUri: Uri.parse('https://apps.directory.divine.video'),
        nip98AuthService: mockNip98AuthService,
        httpClient: MockClient((_) {
          requestCount += 1;
          return responseCompleter.future;
        }),
      );

      service.record(_auditEvent());

      when(
        () => mockNip98AuthService.createAuthToken(
          url: any(named: 'url'),
          method: HttpMethod.post,
          payload: any(named: 'payload'),
        ),
      ).thenAnswer(
        (_) async => Nip98Token(
          token: 'audit-token',
          signedEvent: _createMockEvent(),
          createdAt: DateTime.utc(2026, 3, 25),
          expiresAt: DateTime.utc(2026, 3, 25).add(const Duration(minutes: 10)),
        ),
      );

      final firstUpload = service.uploadQueuedEvents();
      await Future<void>.delayed(Duration.zero);
      final secondUpload = service.uploadQueuedEvents();

      expect(requestCount, 1);

      responseCompleter.complete(http.Response('{"success":true}', 200));

      expect(await firstUpload, 1);
      expect(await secondUpload, 1);
      expect(service.queuedEvents, isEmpty);
    });
  });
}

NostrAppAuditEvent _auditEvent({
  NostrAppAuditDecision decision = NostrAppAuditDecision.allowed,
  String? errorCode,
}) {
  return NostrAppAuditEvent(
    appId: 17,
    origin: Uri.parse('https://primal.net'),
    userPubkey: 'f' * 64,
    method: 'signEvent',
    eventKind: 1,
    decision: decision,
    errorCode: errorCode,
    createdAt: DateTime.utc(2026, 3, 25, 8),
  );
}

Event _createMockEvent() {
  return Event.fromJson({
    'id': List.filled(64, 'a').join(),
    'kind': 27235,
    'pubkey': List.filled(64, 'f').join(),
    'created_at': 1_700_000_000,
    'content': '',
    'tags': [
      ['u', 'https://apps.directory.divine.video/v1/audit-events'],
      ['method', 'POST'],
    ],
    'sig': List.filled(128, 'b').join(),
  });
}
