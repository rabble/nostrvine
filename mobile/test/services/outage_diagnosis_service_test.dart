// ABOUTME: Tests the outage-vs-your-network diagnosis.
// ABOUTME: Pins that we never claim an outage we cannot substantiate.

import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:divine_status_client/divine_status_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:openvine/services/outage_diagnosis_service.dart';

class _MockHttpClient extends Mock implements http.Client {}

String _statusBody({String apiStatus = 'operational', Object? incident}) {
  return jsonEncode({
    'updatedAt': '2026-08-17T03:18:41.874Z',
    'components': {
      'api': {'id': 'api', 'status': apiStatus},
      'relay': {'id': 'relay', 'status': 'operational'},
      'uploads': {'id': 'uploads', 'status': 'down'},
    },
    'incident': incident,
  });
}

void main() {
  group(OutageDiagnosisService, () {
    late _MockHttpClient httpClient;
    final endpoint = Uri.parse('https://status.example/api/status');
    const spaShell = '<!doctype html><html><body>Operational</body></html>';

    setUpAll(() {
      registerFallbackValue(Uri.parse('https://status.example'));
    });

    setUp(() {
      httpClient = _MockHttpClient();
    });

    OutageDiagnosisService buildService({
      List<ConnectivityResult> connectivity = const [ConnectivityResult.wifi],
      DateTime Function()? now,
    }) {
      return OutageDiagnosisService(
        statusClient: DivineStatusClient(
          httpClient: httpClient,
          endpoint: endpoint,
        ),
        connectivityProbe: () async => connectivity,
        now: now,
      );
    }

    void stubStatus(String body, {int statusCode = 200}) {
      when(
        () => httpClient.get(endpoint, headers: any(named: 'headers')),
      ).thenAnswer((_) async => http.Response(body, statusCode));
    }

    test('blames Divine when a feed component is impaired', () async {
      stubStatus(_statusBody(apiStatus: 'down'));

      final diagnosis = await buildService().diagnose();

      expect(diagnosis.verdict, equals(OutageVerdict.divineOutage));
    });

    test('stays indeterminate when the status page reports health', () async {
      // Something failed, but nothing corroborates why. Claiming an outage
      // here is how the message loses its credibility.
      stubStatus(_statusBody());

      final diagnosis = await buildService().diagnose();

      expect(diagnosis.verdict, equals(OutageVerdict.indeterminate));
    });

    test('ignores components the feed does not depend on', () async {
      // `uploads` is down in the fixture. A viewer scrolling videos is not
      // uploading and must not be told about it.
      stubStatus(_statusBody());

      final diagnosis = await buildService().diagnose();

      expect(diagnosis.verdict, equals(OutageVerdict.indeterminate));
    });

    test('keeps verdicts separate per component set', () async {
      // `uploads` is down in the fixture while `api`/`relay` are healthy. A
      // surface asking about uploads must get its own verdict, not the feed's
      // cached one.
      stubStatus(_statusBody());
      final service = buildService();

      final feed = await service.diagnose();
      final uploads = await service.diagnose(
        components: const [DivineStatusComponents.uploads],
      );

      expect(feed.verdict, equals(OutageVerdict.indeterminate));
      expect(uploads.verdict, equals(OutageVerdict.divineOutage));
    });

    test('blames the network when there is no interface', () async {
      stubStatus(_statusBody(apiStatus: 'down'));

      final diagnosis = await buildService(
        connectivity: const [ConnectivityResult.none],
      ).diagnose();

      expect(diagnosis.verdict, equals(OutageVerdict.noConnection));
      // The status page must not even be asked when the radio is off.
      verifyNever(() => httpClient.get(any(), headers: any(named: 'headers')));
    });

    test('stays indeterminate when the status page is unreachable', () async {
      // The client returns null for both transport failure and invalid payloads.
      // Only the connectivity probe may produce a user-network claim.
      when(
        () => httpClient.get(endpoint, headers: any(named: 'headers')),
      ).thenThrow(http.ClientException('unreachable'));

      final diagnosis = await buildService().diagnose();

      expect(diagnosis.verdict, equals(OutageVerdict.indeterminate));
    });

    test('stays indeterminate for a non-status document', () async {
      stubStatus(spaShell);

      final diagnosis = await buildService().diagnose();

      expect(diagnosis.verdict, equals(OutageVerdict.indeterminate));
    });

    test('surfaces the operator message over canned copy', () async {
      stubStatus(
        _statusBody(
          apiStatus: 'down',
          incident: {'message': 'Feed degraded, fix rolling out.'},
        ),
      );

      final diagnosis = await buildService().diagnose();

      expect(
        diagnosis.operatorMessage,
        equals('Feed degraded, fix rolling out.'),
      );
    });

    test('serves a cached verdict rather than re-asking', () async {
      // During an incident every client fails at once; repeated retries must
      // not turn into repeated requests to the page that is explaining it.
      stubStatus(_statusBody(apiStatus: 'down'));
      final service = buildService();

      await service.diagnose();
      await service.diagnose();
      await service.diagnose();

      verify(
        () => httpClient.get(endpoint, headers: any(named: 'headers')),
      ).called(1);
    });

    test('re-asks once the cache expires', () async {
      stubStatus(_statusBody(apiStatus: 'down'));
      var clock = DateTime(2026, 8, 17, 12);
      final service = buildService(now: () => clock);

      await service.diagnose();
      clock = clock.add(OutageDiagnosisService.cacheDuration * 2);
      await service.diagnose();

      verify(
        () => httpClient.get(endpoint, headers: any(named: 'headers')),
      ).called(2);
    });

    test('shares one request between concurrent callers', () async {
      stubStatus(_statusBody(apiStatus: 'down'));
      final service = buildService();

      await Future.wait([service.diagnose(), service.diagnose()]);

      verify(
        () => httpClient.get(endpoint, headers: any(named: 'headers')),
      ).called(1);
    });

    test('caches verdicts by component set', () async {
      stubStatus(_statusBody());
      final service = buildService();

      final feedDiagnosis = await service.diagnose();
      final uploadsDiagnosis = await service.diagnose(
        components: const [DivineStatusComponents.uploads],
      );

      expect(feedDiagnosis.verdict, equals(OutageVerdict.indeterminate));
      expect(uploadsDiagnosis.verdict, equals(OutageVerdict.divineOutage));
      verify(
        () => httpClient.get(endpoint, headers: any(named: 'headers')),
      ).called(2);
    });

    test(
      'falls through to the status check when connectivity throws',
      () async {
        stubStatus(_statusBody(apiStatus: 'down'));
        final service = OutageDiagnosisService(
          statusClient: DivineStatusClient(
            httpClient: httpClient,
            endpoint: endpoint,
          ),
          connectivityProbe: () async => throw Exception('no plugin'),
        );

        expect(
          (await service.diagnose()).verdict,
          equals(OutageVerdict.divineOutage),
        );
      },
    );
  });
}
