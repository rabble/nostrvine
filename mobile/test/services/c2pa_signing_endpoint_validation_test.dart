// ABOUTME: Tests validation of the C2PA signing endpoint dart-define
// ABOUTME: Covers the bare-host misconfiguration that reads as a server outage

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/c2pa_signing_service.dart';

void main() {
  group('describeSigningEndpointProblem', () {
    test('accepts the default endpoint', () {
      expect(
        C2paSigningService.describeSigningEndpointProblem(
          C2paSigningService.defaultSigningServerEndpoint,
        ),
        isNull,
      );
    });

    test('accepts the disabled sentinel', () {
      expect(
        C2paSigningService.describeSigningEndpointProblem(
          C2paSigningService.signingDisabledSentinel,
        ),
        isNull,
      );
    });

    test('rejects an empty endpoint', () {
      final problem = C2paSigningService.describeSigningEndpointProblem('');
      expect(problem, isNotNull);
      expect(problem, contains('is empty'));
    });

    // The reported outage: the endpoint stopped at the host, so appending
    // "?platform=ios" resolved to the service root, which answers HTTP 200 with
    // an HTML landing page.
    test('rejects a bare host with no configuration path', () {
      final problem = C2paSigningService.describeSigningEndpointProblem(
        'https://proofsign.divine.video',
      );
      expect(problem, isNotNull);
      expect(problem, contains('/api/v1/c2pa/configuration'));
    });

    test('rejects a host with a trailing slash only', () {
      expect(
        C2paSigningService.describeSigningEndpointProblem(
          'https://proofsign.divine.video/',
        ),
        isNotNull,
      );
    });

    test('rejects a relative value', () {
      expect(
        C2paSigningService.describeSigningEndpointProblem(
          '/api/v1/c2pa/configuration',
        ),
        isNotNull,
      );
    });

    test('rejects plaintext http', () {
      final problem = C2paSigningService.describeSigningEndpointProblem(
        'http://proofsign.divine.video/api/v1/c2pa/configuration',
      );
      expect(problem, isNotNull);
      expect(problem, contains('https'));
    });

    // The signer appends its own ?platform=, so a pre-existing query string
    // would produce two of them.
    test('rejects an endpoint that already carries a query string', () {
      final problem = C2paSigningService.describeSigningEndpointProblem(
        'https://proofsign.divine.video/api/v1/c2pa/configuration?platform=ios',
      );
      expect(problem, isNotNull);
      expect(problem, contains('query string'));
    });

    test('accepts a well-formed endpoint on another host', () {
      expect(
        C2paSigningService.describeSigningEndpointProblem(
          'https://proofsign.proofmode.org/api/v1/c2pa/configuration',
        ),
        isNull,
      );
    });
  });

  group('assertSigningEndpointValid', () {
    test('passes for the endpoint this build was compiled with', () {
      expect(C2paSigningService.assertSigningEndpointValid, returnsNormally);
    });
  });
}
