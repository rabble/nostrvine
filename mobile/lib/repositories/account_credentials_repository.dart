// ABOUTME: Reads and updates the Keycast-held email/password of the signed-in
// ABOUTME: account, resolving the bearer token owned by AuthService per call.

import 'package:keycast_flutter/keycast_flutter.dart';

/// The email and password behind a Divine account that was created with
/// email/password (`AuthenticationSource.divineOAuth`).
///
/// Keycast owns both credentials, so every call here needs a bearer token for
/// the signed-in account. [readAccessToken] supplies it and is expected to be
/// owner-bound — a session left behind by another account must not be spent on
/// this one's credentials. A null or empty token means the credential this
/// needs is unavailable, and only signing in again produces one, so it maps to
/// the `needsSignIn` refusal rather than to a transport failure.
///
/// Nothing here is cached: a password is never held, and the account status is
/// re-read per call so a change confirmed elsewhere shows up on the next open.
class AccountCredentialsRepository {
  AccountCredentialsRepository({
    required KeycastOAuth oauthClient,
    required Future<String?> Function() readAccessToken,
  }) : _oauthClient = oauthClient,
       _readAccessToken = readAccessToken;

  final KeycastOAuth _oauthClient;
  final Future<String?> Function() _readAccessToken;

  /// The account Keycast has on file, or null when it could not be read —
  /// no token, a refusal, a transport failure, or an unparseable body. Callers
  /// must treat null as "unknown", never as "no email on file".
  Future<KeycastAccountStatus?> fetchAccountStatus() async {
    try {
      final token = await _readAccessToken();
      if (token == null || token.isEmpty) return null;
      return await _oauthClient.getAccountStatus(token);
    } catch (_) {
      return null;
    }
  }

  /// Change the account password. Keycast verifies [currentPassword] itself.
  Future<ChangePasswordResult> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final token = await _readAccessToken();
      if (token == null || token.isEmpty) {
        return ChangePasswordResult.failure(ChangePasswordFailure.needsSignIn);
      }
      return await _oauthClient.changePassword(
        token: token,
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
    } catch (e) {
      return ChangePasswordResult.failure(
        ChangePasswordFailure.network,
        message: 'Change password failed: $e',
      );
    }
  }

  /// Start an email change. Success means Keycast accepted the request and sent
  /// confirmation links — the address changes only once both inboxes confirm.
  Future<ChangeEmailResult> changeEmail({
    required String newEmail,
    required String password,
  }) async {
    try {
      final token = await _readAccessToken();
      if (token == null || token.isEmpty) {
        return ChangeEmailResult.failure(ChangeEmailFailure.needsSignIn);
      }
      return await _oauthClient.changeEmail(
        token: token,
        newEmail: newEmail,
        password: password,
      );
    } catch (e) {
      return ChangeEmailResult.failure(
        ChangeEmailFailure.network,
        message: 'Change email failed: $e',
      );
    }
  }
}
