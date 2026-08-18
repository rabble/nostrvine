// ABOUTME: Fetches the authenticated account's enforcement state from Keycast
// ABOUTME: and maps it to AccountEnforcementStatus, failing to unknown.

import 'package:keycast_flutter/keycast_flutter.dart';
import 'package:openvine/models/account_enforcement_status.dart';

/// Reads `account_status` from Keycast's `GET /api/user/account` (via
/// [KeycastOAuth.getAccountStatus]) and maps it to [AccountEnforcementStatus].
///
/// [readAccessToken] supplies the current Keycast bearer token. A null/empty
/// token yields unknown, NOT "in good standing".
///
/// Self-custody accounts never reach here: [accountEnforcementStatusProvider]
/// short-circuits them to `noAccountState` before constructing a request. So
/// the null-token branch means a *divineOAuth* account whose session is
/// expired, unrefreshable, or bound to a different pubkey — a real and live
/// path, not dead code. Unknown is the honest answer there: the account may
/// well be restricted and we simply could not ask.
///
/// Keycast reports only the caller's own account: the pubkey is taken from the
/// bearer token and there is no pubkey parameter, so this cannot observe
/// another account's state (s-t-s#200 R-8).
///
/// Note: this issues a second `GET /api/user/account` alongside
/// [ProtectedMinorRepository], which reads `verified_minor` from the same
/// response. Deliberately not shared in this change — rewiring the
/// minor-safety fetch path is out of scope here and carries more risk than the
/// duplicate request. Worth collapsing into one cached fetch later.
class AccountEnforcementRepository {
  AccountEnforcementRepository({
    required KeycastOAuth oauthClient,
    required Future<String?> Function() readAccessToken,
  }) : _oauthClient = oauthClient,
       _readAccessToken = readAccessToken;

  final KeycastOAuth _oauthClient;
  final Future<String?> Function() _readAccessToken;

  Future<AccountEnforcementStatus> fetchCurrentStatus() async {
    final token = await _readAccessToken();
    if (token == null || token.isEmpty) {
      return AccountEnforcementStatus.unknown();
    }
    final status = await _oauthClient.getAccountStatus(token);
    if (status == null) {
      // A failed read is an ERROR, not a status. Returning `unknown` here would
      // be indistinguishable from a successful "no enforcement" read to any
      // consumer reading the resolved value, which would let an offline refresh
      // silently clear a restriction marker the user had already earned.
      // Surfacing it lets Riverpod retain the last good value instead.
      throw const AccountStatusUnavailable();
    }
    return AccountEnforcementStatus.fromKeycast(status);
  }
}

/// Thrown when the account status could not be read at all.
///
/// Distinct from [AccountEnforcementKind.unknown], which is a resolved "we hold
/// no signal for you". This means the lookup itself failed and the previous
/// answer, if any, is still the best one available.
class AccountStatusUnavailable implements Exception {
  const AccountStatusUnavailable();

  @override
  String toString() => 'AccountStatusUnavailable';
}
