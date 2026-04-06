import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nostr_app_bridge_repository/nostr_app_bridge_repository.dart';
import 'package:test/test.dart';

void main() {
  group('NostrAppAuditService', () {
    test('records bridge decisions in a local queue', () {
      final service = NostrAppAuditService(
        workerBaseUri: Uri.parse('https://apps.directory.divine.video'),
        authTokenProvider:
            ({
              required url,
              required method,
              required payload,
            }) async => null,
        httpClient: MockClient(
          (_) async => http.Response('', 200),
        ),
      );

      final event = _auditEvent();
      service.record(event);

      expect(service.queuedEvents, hasLength(1));
      expect(service.queuedEvents.single, equals(event));
    });

    test(
      'uploads sanitized payloads and clears the queue '
      'on success',
      () async {
        final capturedRequests = <http.Request>[];

        final service = NostrAppAuditService(
          workerBaseUri: Uri.parse('https://apps.directory.divine.video'),
          authTokenProvider:
              ({
                required url,
                required method,
                required payload,
              }) async => const AuditAuthToken(
                authorizationHeader: 'Nostr audit-token',
              ),
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

        final uploaded = await service.uploadQueuedEvents();

        expect(uploaded, 1);
        expect(service.queuedEvents, isEmpty);
        expect(capturedRequests, hasLength(1));

        final request = capturedRequests.single;
        expect(
          request.url.toString(),
          'https://apps.directory.divine.video'
          '/v1/audit-events',
        );
        expect(
          request.headers['authorization'],
          'Nostr audit-token',
        );
        expect(
          request.headers['content-type'],
          contains('application/json'),
        );

        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body, containsPair('app_id', 17));
        expect(
          body,
          containsPair('origin', 'https://primal.net'),
        );
        expect(body, containsPair('method', 'signEvent'));
        expect(body, containsPair('event_kind', 1));
        expect(body, containsPair('decision', 'blocked'));
        expect(
          body,
          containsPair('error_code', 'blocked_origin'),
        );
        expect(body.containsKey('user_pubkey'), isFalse);
        expect(body.containsKey('created_at'), isFalse);
      },
    );

    test('keeps queued events when upload fails', () async {
      final service = NostrAppAuditService(
        workerBaseUri: Uri.parse('https://apps.directory.divine.video'),
        authTokenProvider:
            ({
              required url,
              required method,
              required payload,
            }) async => const AuditAuthToken(
              authorizationHeader: 'Nostr audit-token',
            ),
        httpClient: MockClient(
          (_) async => http.Response('Server error', 500),
        ),
      )..record(_auditEvent());

      final uploaded = await service.uploadQueuedEvents();

      expect(uploaded, 0);
      expect(service.queuedEvents, hasLength(1));
    });

    test('coalesces concurrent upload attempts', () async {
      final responseCompleter = Completer<http.Response>();
      var requestCount = 0;
      final service = NostrAppAuditService(
        workerBaseUri: Uri.parse('https://apps.directory.divine.video'),
        authTokenProvider:
            ({
              required url,
              required method,
              required payload,
            }) async => const AuditAuthToken(
              authorizationHeader: 'Nostr audit-token',
            ),
        httpClient: MockClient((_) {
          requestCount += 1;
          return responseCompleter.future;
        }),
      )..record(_auditEvent());

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
