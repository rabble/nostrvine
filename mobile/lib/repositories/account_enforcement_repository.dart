// ABOUTME: Fetches the authenticated account's enforcement state from Keycast
// ABOUTME: and maps it to AccountEnforcementStatus, failing to unknown.

import 'package:keycast_flutter/keycast_flutter.dart';
import 'package:openvine/models/account_enforcement_status.dart';

/// Reads `account_status` from Keycast's `GET /api/user/account` (via
/// [KeycastOAuth.getAccountStatus]) and maps it to [AccountEnforcementStatus].
///
/// [readAccessToken] supplies the current Keycast bearer token. A null/empty
/// token means there is no Keycast session at all — a self-custody signer —
/// and yields unknown, NOT "in good standing". Keycast holds no state for a
/// self-custody account, so its enforcement signal is the relay's rejection
/// reason on publish, not this endpoint.
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
    try {
      final token = await _readAccessToken();
      if (token == null || token.isEmpty) {
        return AccountEnforcementStatus.unknown();
      }
      final status = await _oauthClient.getAccountStatus(token);
      return AccountEnforcementStatus.fromKeycast(status);
    } catch (_) {
      return AccountEnforcementStatus.unknown();
    }
  }
}
