// ABOUTME: Fetches the authenticated account's enforcement state from Keycast
// ABOUTME: and maps positive restriction signals without claiming all-clear.

import 'package:keycast_flutter/keycast_flutter.dart';
import 'package:openvine/models/account_enforcement_status.dart';

/// Reads `account_status` from Keycast's `GET /api/user/account` (via
/// [KeycastOAuth.getAccountStatus]) and maps it to [AccountEnforcementStatus].
///
/// [readAccessToken] supplies the current Keycast bearer token, through the
/// owner-bound gate, so a session another account left behind cannot answer
/// the enforcement question for this one.
///
/// Every "we could not ask" outcome throws rather than resolving to a status:
/// a missing token (session unbound, or a refresh that has not landed) and a
/// failed read alike. Resolving either would be indistinguishable from a
/// successful "no enforcement" answer and would clear a restriction the user
/// had already been shown.
///
/// Self-custody accounts never reach here: [accountEnforcementStatusProvider]
/// short-circuits them before a request is constructed.
///
/// Keycast reports only the caller's own account: the pubkey is taken from the
/// bearer token and there is no pubkey parameter, so this cannot observe
/// another account's state (s-t-s#200 R-8).
///
/// Note: this issues a second `GET /api/user/account` alongside
/// [ProtectedMinorRepository], which reads `verified_minor` from the same
/// response. Deliberately not shared in this change — rewiring the
/// minor-safety fetch path is out of scope here and carries more risk than the
/// duplicate request. The shared-fetch consolidation remains tracked in #7765.
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
      // Same exit as a failed read below, for the same reason: this is "we
      // could not ask", not "you are unrestricted". Resolving it would
      // overwrite the last good answer and clear a restriction marker the user
      // already earned. Retrying is worthwhile because the owner-bound gate
      // refreshes the session, so a later attempt can genuinely succeed.
      throw const AccountStatusUnavailable();
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
/// This means the lookup itself failed and the previous answer, if any, is
/// still the best one available.
class AccountStatusUnavailable implements Exception {
  const AccountStatusUnavailable();

  @override
  String toString() => 'AccountStatusUnavailable';
}
