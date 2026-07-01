// ABOUTME: Fetches the protected-minor state from Keycast (verified_minor) and
// ABOUTME: maps it to ProtectedMinorStatus, preserving fetch failures as unknown.

import 'package:keycast_flutter/keycast_flutter.dart';
import 'package:openvine/models/protected_minor_status.dart';

/// Reads the durable approved-minor flag from Keycast's `GET /api/user/account`
/// (via [KeycastOAuth.getAccountStatus]) and maps it to [ProtectedMinorStatus].
///
/// [readAccessToken] supplies the current Keycast bearer token; a null/empty
/// token (e.g. a non-OAuth signer session) yields not-protected. Keycast fetch
/// failure yields unknown so #175/#176 can decide their own fail-safe posture
/// when they attach real protections.
class ProtectedMinorRepository {
  ProtectedMinorRepository({
    required KeycastOAuth oauthClient,
    required Future<String?> Function() readAccessToken,
  }) : _oauthClient = oauthClient,
       _readAccessToken = readAccessToken;

  final KeycastOAuth _oauthClient;
  final Future<String?> Function() _readAccessToken;

  Future<ProtectedMinorStatus> fetchCurrentStatus() async {
    try {
      final token = await _readAccessToken();
      if (token == null || token.isEmpty) {
        return ProtectedMinorStatus.notProtected();
      }
      final status = await _oauthClient.getAccountStatus(token);
      return ProtectedMinorStatus.fromKeycast(status);
    } catch (_) {
      return ProtectedMinorStatus.unknown();
    }
  }
}
