// ABOUTME: Tests Funnelcake enforcement mapping and unavailable request handling.
// ABOUTME: Transport failures remain distinct from successful unrestricted responses.

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:openvine/models/account_enforcement_status.dart';
import 'package:openvine/repositories/account_enforcement_repository.dart';
import 'package:openvine/services/account_status_api_client.dart';

const _pubkey =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

AccountEnforcementRepository _repository(String body, {int statusCode = 200}) {
  return AccountEnforcementRepository(
    apiClient: AccountStatusApiClient(
      baseUri: Uri.parse('https://api.divine.video'),
      authHeaderProvider: ({required url, required method}) async =>
          'Nostr token',
      httpClient: MockClient((_) async => http.Response(body, statusCode)),
    ),
  );
}

void main() {
  test(
    'maps active, suspended, banned, and unknown successful values',
    () async {
      for (final entry in {
        'active': AccountEnforcementKind.noRestrictionReported,
        'suspended': AccountEnforcementKind.suspended,
        'banned': AccountEnforcementKind.banned,
        'future_restriction': AccountEnforcementKind.unknownRestriction,
      }.entries) {
        final repository = _repository(
          '{"pubkey":"$_pubkey","status":"${entry.key}"}',
        );
        final result = await repository.fetchCurrentStatus(pubkey: _pubkey);
        expect(result.kind, entry.value);
      }
    },
  );

  test('maps request and response failures to unavailable', () async {
    for (final repository in [
      _repository('{}'),
      _repository('unavailable', statusCode: 503),
    ]) {
      await expectLater(
        repository.fetchCurrentStatus(pubkey: _pubkey),
        throwsA(isA<AccountStatusUnavailable>()),
      );
    }
  });
}
