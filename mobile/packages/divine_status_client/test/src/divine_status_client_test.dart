// ABOUTME: Tests the Divine status page client.
// ABOUTME: Pins that nothing but a real status document reads as an opinion.

import 'dart:convert';

import 'package:divine_status_client/divine_status_client.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

class _MockHttpClient extends Mock implements http.Client {}

/// The single-page-app shell every non-API path on the status host returns.
const _spaShell = '<!doctype html><html><body>Operational</body></html>';

String _statusBody({
  String apiStatus = 'operational',
  String relayStatus = 'operational',
  Object? incident,
}) {
  return jsonEncode({
    'updatedAt': '2026-08-17T03:18:41.874Z',
    'components': {
      'api': {
        'id': 'api',
        'label': 'API',
        'status': apiStatus,
        'message': 'api-readyz passed',
      },
      'relay': {'id': 'relay', 'label': 'Relay', 'status': relayStatus},
    },
    'incident': incident,
  });
}

void main() {
  group(DivineStatusClient, () {
    late _MockHttpClient httpClient;
    late DivineStatusClient client;
    final endpoint = Uri.parse('https://status.example/api/status');

    setUp(() {
      httpClient = _MockHttpClient();
      client = DivineStatusClient(httpClient: httpClient, endpoint: endpoint);
    });

    void stubResponse(String body, {int statusCode = 200}) {
      when(
        () => httpClient.get(endpoint, headers: any(named: 'headers')),
      ).thenAnswer(
        (_) async => http.Response(
          body,
          statusCode,
          headers: const {'content-type': 'application/json; charset=utf-8'},
        ),
      );
    }

    group('fetchStatus', () {
      test('reads component health from a status document', () async {
        stubResponse(_statusBody(apiStatus: 'degraded'));

        final status = await client.fetchStatus();

        expect(status, isNotNull);
        expect(
          status!.healthOf(DivineStatusComponents.api),
          equals(ComponentHealth.impaired),
        );
        expect(
          status.healthOf(DivineStatusComponents.relay),
          equals(ComponentHealth.operational),
        );
        expect(status.components['api']?.label, equals('API'));
      });

      test('returns null for the SPA shell served on non-API paths', () async {
        // A 200 with HTML is the shape a wrong path or a captive portal
        // produces. Reading it as "all operational" would quietly disable
        // outage messaging, so it has to be no-opinion instead.
        stubResponse(_spaShell);

        expect(await client.fetchStatus(), isNull);
      });

      test('returns null for a non-200 response', () async {
        stubResponse(_statusBody(), statusCode: 503);

        expect(await client.fetchStatus(), isNull);
      });

      test('returns null for malformed JSON', () async {
        stubResponse('{"components":');

        expect(await client.fetchStatus(), isNull);
      });

      test('returns null when the document carries no components', () async {
        stubResponse(jsonEncode({'updatedAt': '2026-08-17T03:18:41.874Z'}));

        expect(await client.fetchStatus(), isNull);
      });

      test('ignores non-string optional fields rather than throwing', () async {
        stubResponse(
          jsonEncode({
            'updatedAt': {'value': '2026-08-17T03:18:41.874Z'},
            'components': {
              'api': {
                'id': 'api',
                'label': {'text': 'API'},
                'status': 'operational',
                'message': {'text': 'ready'},
              },
            },
          }),
        );

        final status = await client.fetchStatus();

        expect(status, isNotNull);
        expect(status!.updatedAt, isNull);
        expect(status.components['api']?.label, isNull);
        expect(status.components['api']?.message, isNull);
      });

      test(
        'returns null rather than throwing when the request fails',
        () async {
          when(
            () => httpClient.get(endpoint, headers: any(named: 'headers')),
          ).thenThrow(http.ClientException('offline'));

          expect(await client.fetchStatus(), isNull);
        },
      );

      test('surfaces an operator incident message', () async {
        stubResponse(
          _statusBody(
            apiStatus: 'down',
            incident: {'message': 'Uploads degraded, fix rolling out.'},
          ),
        );

        final status = await client.fetchStatus();

        expect(
          status!.incidentMessage,
          equals('Uploads degraded, fix rolling out.'),
        );
      });

      test('reads a bare-string incident', () async {
        stubResponse(_statusBody(incident: 'Investigating elevated errors.'));

        final status = await client.fetchStatus();

        expect(
          status!.incidentMessage,
          equals('Investigating elevated errors.'),
        );
      });

      test('ignores an incident with no readable message', () async {
        stubResponse(_statusBody(incident: {'startedAt': 'now'}));

        expect((await client.fetchStatus())!.incidentMessage, isNull);
      });

      test('has no incident message outside an incident', () async {
        stubResponse(_statusBody());

        expect((await client.fetchStatus())!.incidentMessage, isNull);
      });

      test('parses updatedAt', () async {
        stubResponse(_statusBody());

        expect(
          (await client.fetchStatus())!.updatedAt,
          equals(DateTime.parse('2026-08-17T03:18:41.874Z')),
        );
      });

      test('tolerates non-string updatedAt, label, and message', () async {
        // The status page owns the payload shape. A numeric epoch or a
        // non-string label must degrade to null — a bare cast would throw a
        // TypeError (an Error, not an Exception) past the on-Exception guard
        // and collapse the whole document instead of one field.
        stubResponse(
          jsonEncode({
            'updatedAt': 1723800000,
            'components': {
              'api': {
                'id': 'api',
                'status': 'down',
                'label': 3,
                'message': false,
              },
            },
          }),
        );

        final status = await client.fetchStatus();

        expect(status, isNotNull);
        expect(status!.updatedAt, isNull);
        expect(status.components['api']?.label, isNull);
        expect(status.components['api']?.message, isNull);
        expect(
          status.healthOf(DivineStatusComponents.api),
          equals(ComponentHealth.impaired),
        );
      });

      test('defaults to the status host, which is not the API host', () {
        // Hosting the status page away from the services it reports on is
        // the whole reason asking it during an outage is worth anything.
        // Repointing it at api.divine.video would silently neuter this.
        expect(
          DivineStatusClient.defaultEndpoint,
          equals(Uri.parse('https://status.divine.video/api/status')),
        );
        expect(
          DivineStatusClient.defaultEndpoint.host,
          isNot('api.divine.video'),
        );

        // Constructing without injection must not throw.
        DivineStatusClient().close();
      });

      test('closes the underlying client', () {
        when(() => httpClient.close()).thenAnswer((_) {});

        client.close();

        verify(() => httpClient.close()).called(1);
      });
    });

    group('anyImpaired', () {
      test('reports an impaired component', () async {
        stubResponse(_statusBody(relayStatus: 'down'));
        final status = await client.fetchStatus();

        expect(status!.anyImpaired(const ['api', 'relay']), isTrue);
      });

      test('does not treat an unknown component as corroboration', () async {
        stubResponse(_statusBody(apiStatus: 'unknown'));
        final status = await client.fetchStatus();

        expect(status!.anyImpaired(const ['api']), isFalse);
      });

      test('does not treat a missing component as corroboration', () async {
        stubResponse(_statusBody());
        final status = await client.fetchStatus();

        expect(status!.anyImpaired(const ['uploads']), isFalse);
      });

      test('reports healthy when everything is operational', () async {
        stubResponse(_statusBody());
        final status = await client.fetchStatus();

        expect(status!.anyImpaired(const ['api', 'relay']), isFalse);
      });
    });

    group('equality', () {
      // Callers cache a status snapshot and compare against the next one to
      // decide whether anything changed, so value equality has to be real.
      test('$StatusComponent compares by value', () {
        const a = StatusComponent(
          id: 'api',
          health: ComponentHealth.operational,
          label: 'API',
          message: 'passed',
        );
        const same = StatusComponent(
          id: 'api',
          health: ComponentHealth.operational,
          label: 'API',
          message: 'passed',
        );
        const differentHealth = StatusComponent(
          id: 'api',
          health: ComponentHealth.impaired,
          label: 'API',
          message: 'passed',
        );

        expect(a, equals(same));
        expect(a, isNot(equals(differentHealth)));
      });

      test('$DivineStatus compares by value', () async {
        stubResponse(_statusBody());
        final first = await client.fetchStatus();
        final second = await client.fetchStatus();

        expect(first, equals(second));

        stubResponse(_statusBody(apiStatus: 'down'));
        expect(await client.fetchStatus(), isNot(equals(first)));
      });
    });

    group(ComponentHealth, () {
      test('treats only "operational" as healthy', () {
        expect(
          ComponentHealth.parse('operational'),
          equals(ComponentHealth.operational),
        );
        expect(
          ComponentHealth.parse('OPERATIONAL'),
          equals(ComponentHealth.operational),
        );
      });

      test('treats an unfamiliar failure word as impaired', () {
        // The status page owns this vocabulary and may extend it. An
        // unanticipated word must still read as trouble, or the app goes
        // quiet during exactly the outage it exists to explain.
        for (final raw in const [
          'degraded',
          'down',
          'partial_outage',
          'major_outage',
          'maintenance',
          'something_new',
        ]) {
          expect(
            ComponentHealth.parse(raw),
            equals(ComponentHealth.impaired),
            reason: '$raw should read as impaired',
          );
        }
      });

      test('treats an absent or unusable value as unknown', () {
        for (final raw in [null, '', '  ', 'unknown', 42]) {
          expect(
            ComponentHealth.parse(raw),
            equals(ComponentHealth.unknown),
            reason: '$raw should read as unknown',
          );
        }
      });
    });
  });
}
