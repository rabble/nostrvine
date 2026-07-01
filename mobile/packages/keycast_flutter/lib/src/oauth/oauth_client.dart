// ABOUTME: Keycast OAuth client for authentication flow
// ABOUTME: Handles authorization URL generation, callback parsing, token
// exchange, and headless auth

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:keycast_flutter/src/crypto/key_utils.dart';
import 'package:keycast_flutter/src/models/exceptions.dart';
import 'package:keycast_flutter/src/models/keycast_session.dart';
import 'package:keycast_flutter/src/oauth/account_status.dart';
import 'package:keycast_flutter/src/oauth/callback_result.dart';
import 'package:keycast_flutter/src/oauth/headless_models.dart';
import 'package:keycast_flutter/src/oauth/oauth_config.dart';
import 'package:keycast_flutter/src/oauth/pkce.dart';
import 'package:keycast_flutter/src/oauth/token_response.dart';
import 'package:keycast_flutter/src/storage/keycast_storage.dart';

/// Storage key for session credentials
const _storageKeySession = 'keycast_session';

/// Storage key for authorization handle (for silent re-auth when session
/// expires)
const _storageKeyHandle = 'keycast_auth_handle';

/// Storage key for refresh token (stored separately so it survives session
/// clear)
const _storageKeyRefreshToken = 'keycast_refresh_token';

Map<String, dynamic> _decodeJsonObject(String body) {
  final decoded = jsonDecode(body);
  if (decoded is Map<String, dynamic>) {
    return decoded;
  }
  throw const FormatException('Expected a JSON object');
}

String _responseErrorCode(Map<String, dynamic> json, String fallback) =>
    json['code']?.toString() ?? json['error']?.toString() ?? fallback;

String _responseErrorMessage(Map<String, dynamic> json, String fallback) =>
    json['message']?.toString() ??
    json['error_description']?.toString() ??
    json['error']?.toString() ??
    fallback;

KeycastAuthFailure _failureForStatusCode(int statusCode) {
  if (statusCode == 409) {
    return KeycastAuthFailure.emailAlreadyRegistered;
  }
  if (statusCode == 401 || statusCode == 404) {
    return KeycastAuthFailure.expiredVerification;
  }
  if (statusCode == 408 || statusCode == 429 || statusCode >= 500) {
    return KeycastAuthFailure.temporary;
  }
  return KeycastAuthFailure.unknown;
}

class KeycastOAuth {
  /// Default timeout applied to every Keycast HTTP request.
  ///
  /// Without a bound, a dead socket (e.g. Android Doze killing the
  /// connection while backgrounded) hangs the request forever and wedges
  /// every caller awaiting it.
  static const Duration defaultRequestTimeout = Duration(seconds: 30);

  final OAuthConfig config;
  final http.Client _client;
  final KeycastStorage _storage;

  /// Maximum time to wait for any single HTTP request before failing
  /// with a [TimeoutException].
  final Duration requestTimeout;

  // Invalidates in-flight refresh saves after logout clears credential storage.
  int _storageEpoch = 0;

  KeycastOAuth({
    required this.config,
    http.Client? httpClient,
    KeycastStorage? storage,
    this.requestTimeout = defaultRequestTimeout,
  }) : _client = httpClient ?? http.Client(),
       _storage = storage ?? MemoryKeycastStorage();

  /// Get stored session from storage
  /// Returns null if no session or session is expired
  Future<KeycastSession?> getSession() async {
    final json = await _storage.read(_storageKeySession);
    if (json == null) return null;

    try {
      final data = jsonDecode(json) as Map<String, dynamic>;
      final session = KeycastSession.fromJson(data);
      if (session.isExpired) {
        return null;
      }
      return session;
    } catch (_) {
      return null;
    }
  }

  /// Get stored authorization handle (for silent re-auth when session expires)
  Future<String?> getAuthorizationHandle() async {
    return _storage.read(_storageKeyHandle);
  }

  /// Clear local session and POST to server logout (keeps authorization_handle)
  ///
  /// Server-side logout has a 2-second timeout - if it fails or times out,
  /// we still complete the local logout. The server will eventually expire
  /// the token anyway.
  Future<void> logout() async {
    _storageEpoch++;
    await _storage.delete(_storageKeySession);
    await _storage.delete(_storageKeyHandle);
    await _storage.delete(_storageKeyRefreshToken);
    // Fire-and-forget server logout with short timeout
    // Local logout is complete, server notification is best-effort
    try {
      unawaited(
        _client
            .post(Uri.parse('${config.serverUrl}/api/auth/logout'))
            .timeout(const Duration(seconds: 2)),
      );
    } catch (_) {
      // Ignore timeout or network errors - local logout is complete
    }
  }

  Future<void> _saveSession(KeycastSession session) async {
    await _storage.write(_storageKeySession, jsonEncode(session.toJson()));
    if (session.authorizationHandle != null) {
      await _storage.write(_storageKeyHandle, session.authorizationHandle!);
    }
    if (session.refreshToken != null) {
      await _storage.write(_storageKeyRefreshToken, session.refreshToken!);
    }
  }

  /// Attempt to refresh the session using a stored refresh token.
  ///
  /// Returns the new [KeycastSession] on success, or `null` if refresh
  /// is not possible (no refresh token) or fails.
  ///
  /// [userPubkey] is attached to the session before it is persisted so
  /// the saved session is always owner-bound.
  ///
  /// On HTTP error the consumed refresh token is cleared (server may have
  /// rotated it). On network error or timeout the token is preserved since
  /// the server may not have consumed it.
  Future<KeycastSession?> refreshSession({String? userPubkey}) async {
    final refreshEpoch = _storageEpoch;
    final refreshToken = await _storage.read(_storageKeyRefreshToken);
    if (refreshToken == null) return null;

    try {
      final response = await _client
          .post(
            Uri.parse(config.tokenUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'grant_type': 'refresh_token',
              'refresh_token': refreshToken,
              'client_id': config.clientId,
            }),
          )
          .timeout(requestTimeout);

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final tokenResponse = TokenResponse.fromJson(json);
        var session = KeycastSession.fromTokenResponse(tokenResponse);
        if (userPubkey != null && userPubkey.isNotEmpty) {
          session = session.copyWith(userPubkey: userPubkey);
        }
        if (refreshEpoch != _storageEpoch) {
          return null;
        }
        await _saveSession(session);
        return session;
      }

      // HTTP error — server consumed the token, clear it
      await _storage.delete(_storageKeyRefreshToken);
      return null;
    } catch (_) {
      // Network error or timeout — server may not have consumed the
      // token, keep it so the next attempt can retry the refresh
      return null;
    }
  }

  /// Get an active session, refreshing if the current one is expired.
  ///
  /// Tries [getSession] first. If that returns `null` (no session stored or
  /// token expired), falls back to [refreshSession] to obtain a fresh token.
  /// Returns `null` only when no session can be recovered at all.
  ///
  /// [userPubkey] is forwarded to [refreshSession] so the saved session
  /// is owner-bound when a refresh is needed.
  Future<KeycastSession?> getSessionOrRefresh({String? userPubkey}) async {
    final session = await getSession();
    if (session != null) return session;
    return refreshSession(userPubkey: userPubkey);
  }

  /// Generate authorization URL for OAuth flow
  /// Automatically uses stored authorization handle for silent re-auth if available
  ///
  /// [prompt] - OAuth 2.0 prompt parameter:
  ///   - 'login': Force fresh login (ignore existing session)
  ///   - 'consent': Force consent screen even if previously approved
  ///   - 'none': Silent auth only, fail if interaction required
  Future<(String url, String verifier)> getAuthorizationUrl({
    String? nsec,
    String scope = 'policy:social',
    bool defaultRegister = true,
    String? authorizationHandle,
    String? prompt,
  }) async {
    String? byokPubkey;
    if (nsec != null) {
      byokPubkey = KeyUtils.derivePublicKeyFromNsec(nsec);
      if (byokPubkey == null) {
        return ('', '');
      }
    }

    final verifier = Pkce.generateVerifier(nsec: nsec);
    final challenge = Pkce.generateChallenge(verifier);

    final params = <String, String>{
      'client_id': config.clientId,
      'redirect_uri': config.redirectUri,
      'scope': scope,
      'code_challenge': challenge,
      'code_challenge_method': 'S256',
      'default_register': defaultRegister.toString(),
    };

    if (byokPubkey != null) {
      params['byok_pubkey'] = byokPubkey;
    }

    final handle = authorizationHandle ?? await getAuthorizationHandle();
    if (handle != null) {
      params['authorization_handle'] = handle;
    }

    if (prompt != null) {
      params['prompt'] = prompt;
    }

    final uri = Uri.parse(config.authorizeUrl).replace(queryParameters: params);
    return (uri.toString(), verifier);
  }

  /// Parse callback URL and extract authorization code
  /// PKCE provides security - state parameter is not required
  CallbackResult parseCallback(String url) {
    final uri = Uri.parse(url);
    final params = uri.queryParameters;

    if (params.containsKey('error')) {
      return CallbackError(
        error: params['error']!,
        description: params['error_description'],
      );
    }

    if (params.containsKey('code')) {
      return CallbackSuccess(code: params['code']!);
    }

    return const CallbackError(
      error: 'invalid_response',
      description: 'Missing code or error in callback URL',
    );
  }

  /// Exchange authorization code for tokens
  /// Automatically saves session to storage after successful exchange
  ///
  /// Throws [TimeoutException] if the server does not respond within
  /// [requestTimeout].
  Future<TokenResponse> exchangeCode({
    required String code,
    required String verifier,
  }) async {
    final response = await _client
        .post(
          Uri.parse(config.tokenUrl),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'grant_type': 'authorization_code',
            'code': code,
            'client_id': config.clientId,
            'redirect_uri': config.redirectUri,
            'code_verifier': verifier,
          }),
        )
        .timeout(requestTimeout);

    final json = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode != 200) {
      final error = json['error'] as String? ?? 'unknown_error';
      final description = json['error_description'] as String?;
      throw OAuthException(
        description ?? 'Token exchange failed',
        errorCode: error,
      );
    }

    final tokenResponse = TokenResponse.fromJson(json);

    // Auto-save session and authorization handle to storage
    final session = KeycastSession.fromTokenResponse(tokenResponse);
    await _saveSession(session);

    return tokenResponse;
  }

  // ===========================================================================
  // HEADLESS AUTHENTICATION METHODS
  // Native login/register flows without browser redirects
  // ===========================================================================

  /// Register a new user with email and password (headless flow)
  ///
  /// Returns [HeadlessRegisterResult] with device_code for email verification
  /// polling.
  /// After registration, poll [pollForCode] until email is verified, then
  /// [exchangeCode].
  ///
  /// [nsec] - Optional: import existing Nostr key instead of generating new one
  Future<(HeadlessRegisterResult, String verifier)> headlessRegister({
    required String email,
    required String password,
    String scope = 'policy:social',
    String? nsec,
    String? state,
  }) async {
    String? byokPubkey;
    if (nsec != null) {
      byokPubkey = KeyUtils.derivePublicKeyFromNsec(nsec);
    }

    final verifier = Pkce.generateVerifier(nsec: nsec);
    final challenge = Pkce.generateChallenge(verifier);

    try {
      final body = <String, dynamic>{
        'email': email,
        'password': password,
        'client_id': config.clientId,
        'redirect_uri': config.redirectUri,
        'scope': scope,
        'code_challenge': challenge,
        'code_challenge_method': 'S256',
      };

      if (byokPubkey != null) {
        body['nsec'] = nsec;
      }

      if (state != null) {
        body['state'] = state;
      }

      final response = await _client
          .post(
            Uri.parse('${config.serverUrl}/api/headless/register'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(requestTimeout);

      // Check for non-success status codes first
      if (response.statusCode == 404) {
        return (
          HeadlessRegisterResult.error(
            'Registration endpoint not available. Please try again later.',
            code: 'endpoint_not_found',
          ),
          verifier,
        );
      }

      if (response.statusCode >= 500) {
        return (
          HeadlessRegisterResult.error(
            'Server error (${response.statusCode}). Please try again later.',
            code: 'server_error',
          ),
          verifier,
        );
      }

      // Try to parse JSON response
      Map<String, dynamic> json;
      try {
        json = jsonDecode(response.body) as Map<String, dynamic>;
      } catch (e) {
        return (
          HeadlessRegisterResult.error(
            'Invalid server response. Status: ${response.statusCode}',
            code: 'invalid_response',
          ),
          verifier,
        );
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        return (HeadlessRegisterResult.fromJson(json), verifier);
      }

      // Handle error responses - preserve error code for client-side handling
      final String errorCode = json['code'] as String? ?? 'registration_failed';
      final description =
          json['error'] as String? ?? json['message'] as String? ?? errorCode;

      return (
        HeadlessRegisterResult.error(description, code: errorCode),
        verifier,
      );
    } on TimeoutException {
      return (
        HeadlessRegisterResult.error(
          'Request timed out. Check your internet connection and try again.',
          code: 'timeout',
        ),
        verifier,
      );
    } catch (e) {
      if (e.toString().contains('SocketException') ||
          e.toString().contains('Connection refused')) {
        return (
          HeadlessRegisterResult.error(
            'Cannot connect to server. Check your internet connection.',
            code: 'connection_error',
          ),
          verifier,
        );
      }
      return (
        HeadlessRegisterResult.error(
          'Network error: $e',
          code: 'network_error',
        ),
        verifier,
      );
    }
  }

  /// Login existing user with email and password (headless flow)
  ///
  /// Returns [HeadlessLoginResult] with authorization code directly (no polling needed).
  /// After login, call [exchangeCode] with the returned code and verifier.
  Future<(HeadlessLoginResult, String verifier)> headlessLogin({
    required String email,
    required String password,
    String scope = 'policy:social',
    String? state,
  }) async {
    final verifier = Pkce.generateVerifier();
    final challenge = Pkce.generateChallenge(verifier);

    try {
      final body = <String, dynamic>{
        'email': email,
        'password': password,
        'client_id': config.clientId,
        'redirect_uri': config.redirectUri,
        'scope': scope,
        'code_challenge': challenge,
        'code_challenge_method': 'S256',
      };

      if (state != null) {
        body['state'] = state;
      }

      final response = await _client
          .post(
            Uri.parse('${config.serverUrl}/api/headless/login'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(requestTimeout);

      // Check for non-success status codes first
      if (response.statusCode == 404) {
        return (
          HeadlessLoginResult.error(
            'Login endpoint not available. Please try again later.',
            code: 'endpoint_not_found',
          ),
          verifier,
        );
      }

      if (response.statusCode >= 500) {
        return (
          HeadlessLoginResult.error(
            'Server error (${response.statusCode}). Please try again later.',
            code: 'server_error',
          ),
          verifier,
        );
      }

      // Try to parse JSON response
      Map<String, dynamic> json;
      try {
        json = jsonDecode(response.body) as Map<String, dynamic>;
      } catch (e) {
        return (
          HeadlessLoginResult.error(
            'Invalid server response. Status: ${response.statusCode}',
            code: 'invalid_response',
          ),
          verifier,
        );
      }

      if (response.statusCode == 200) {
        return (HeadlessLoginResult.fromJson(json), verifier);
      }

      // Handle specific error codes
      final error = json['error'] as String? ?? 'login_failed';
      final description =
          json['error_description'] as String? ??
          json['message'] as String? ??
          'Login failed';

      return (HeadlessLoginResult.error(description, code: error), verifier);
    } on TimeoutException {
      return (
        HeadlessLoginResult.error(
          'Request timed out. Check your internet connection and try again.',
          code: 'timeout',
        ),
        verifier,
      );
    } catch (e) {
      if (e.toString().contains('SocketException') ||
          e.toString().contains('Connection refused')) {
        return (
          HeadlessLoginResult.error(
            'Cannot connect to server. Check your internet connection.',
            code: 'connection_error',
          ),
          verifier,
        );
      }
      return (HeadlessLoginResult.error('Network error: $e'), verifier);
    }
  }

  /// Poll for email verification completion
  ///
  /// Call this after [headlessRegister] to wait for the user to verify their email.
  /// Returns [PollResult.complete] with authorization code when verified.
  /// Returns [PollResult.pending] if still waiting.
  /// Returns [PollResult.error] if something went wrong.
  Future<PollResult> pollForCode(String deviceCode) async {
    try {
      final response = await _client
          .get(
            Uri.parse(
              '${config.serverUrl}/api/oauth/poll',
            ).replace(queryParameters: {'device_code': deviceCode}),
          )
          .timeout(requestTimeout);

      if (response.statusCode == 200) {
        final json = _decodeJsonObject(response.body);
        final code = json['code'] as String?;
        if (code != null) {
          return PollResult.complete(code);
        }
        return PollResult.pending();
      }

      if (response.statusCode == 202) {
        // Still pending
        return PollResult.pending();
      }

      // Error
      try {
        final json = _decodeJsonObject(response.body);
        final errorCode = _responseErrorCode(json, 'poll_failed');
        final description = _responseErrorMessage(json, 'Polling failed');
        return PollResult.error(
          description,
          errorCode: errorCode,
          statusCode: response.statusCode,
          failure: _failureForStatusCode(response.statusCode),
        );
      } catch (_) {
        return PollResult.error(
          'HTTP ${response.statusCode}',
          statusCode: response.statusCode,
          failure: _failureForStatusCode(response.statusCode),
        );
      }
    } catch (e) {
      return PollResult.error(
        'Network error: $e',
        failure: KeycastAuthFailure.network,
      );
    }
  }

  /// Send a password reset link to the provided email address
  Future<ForgotPasswordResult> sendPasswordResetEmail(String email) async {
    try {
      final response = await _client
          .post(
            Uri.parse('${config.serverUrl}/api/auth/forgot-password'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'email': email}),
          )
          .timeout(requestTimeout);

      final json = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 || response.statusCode == 201) {
        return ForgotPasswordResult.fromJson(json);
      }

      // Handle server-side errors
      final error = json['error'] as String? ?? 'reset_failed';
      final description =
          json['message'] ??
          json['error_description'] ??
          'Failed to send reset email';
      return ForgotPasswordResult.error('$error: $description');
    } catch (e) {
      return ForgotPasswordResult.error('Network error: $e');
    }
  }

  /// Reset password using token from email link
  Future<ResetPasswordResult> resetPassword({
    required String token,
    required String newPassword,
  }) async {
    try {
      final response = await _client
          .post(
            Uri.parse('${config.serverUrl}/api/auth/reset-password'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'token': token, 'new_password': newPassword}),
          )
          .timeout(requestTimeout);

      final json = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 || response.statusCode == 201) {
        return ResetPasswordResult.fromJson(json);
      }

      // Handle server-side errors
      final message = json['message']?.toString() ?? 'Failed to reset password';
      return ResetPasswordResult.error(message);
    } catch (e) {
      return ResetPasswordResult.error('Network error: $e');
    }
  }

  /// Verify email using token from email link
  Future<VerifyEmailResult> verifyEmail({required String token}) async {
    try {
      final response = await _client
          .post(
            Uri.parse('${config.serverUrl}/api/auth/verify-email'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'token': token}),
          )
          .timeout(requestTimeout);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final json = _decodeJsonObject(response.body);
        return VerifyEmailResult.fromJson(
          json,
          statusCode: response.statusCode,
        );
      }

      // Handle server-side errors
      try {
        final json = _decodeJsonObject(response.body);
        final message = _responseErrorMessage(json, 'Failed to verify email');
        return VerifyEmailResult.error(
          message,
          errorCode: _responseErrorCode(json, 'verify_email_failed'),
          statusCode: response.statusCode,
          failure: _failureForStatusCode(response.statusCode),
        );
      } catch (_) {
        return VerifyEmailResult.error(
          'HTTP ${response.statusCode}',
          statusCode: response.statusCode,
          failure: _failureForStatusCode(response.statusCode),
        );
      }
    } on FormatException catch (e) {
      return VerifyEmailResult.error('Invalid server response: $e');
    } catch (e) {
      return VerifyEmailResult.error(
        'Network error: $e',
        failure: KeycastAuthFailure.network,
      );
    }
  }

  /// Fetch the current account status from Keycast, including the durable
  /// approved-minor flag (`verified_minor`, keycast#263).
  ///
  /// Requires an active bearer [token]. Returns the parsed
  /// [KeycastAccountStatus], or null on any non-200 response, timeout, or
  /// network/parse error — callers treat null as "unknown / not a minor".
  Future<KeycastAccountStatus?> getAccountStatus(String token) async {
    try {
      final response = await _client
          .get(
            Uri.parse('${config.serverUrl}/api/user/account'),
            headers: {'Authorization': 'Bearer $token'},
          )
          .timeout(requestTimeout);

      if (response.statusCode != 200) return null;
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return KeycastAccountStatus.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  /// Delete the user's account permanently from Keycast
  ///
  /// Requires an active bearer token from headless login/register flow.
  /// This is a destructive action that cannot be undone.
  ///
  /// Returns [DeleteAccountResult] with success status.
  Future<DeleteAccountResult> deleteAccount(String token) async {
    try {
      final response = await _client.delete(
        Uri.parse('${config.serverUrl}/api/user/account'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        // Clear local session after successful deletion
        await _storage.delete(_storageKeySession);
        await _storage.delete(_storageKeyHandle);
        await _storage.delete(_storageKeyRefreshToken);
        return DeleteAccountResult.fromJson(json);
      }

      if (response.statusCode == 401) {
        return DeleteAccountResult.error(
          'Unauthorized: invalid or expired token',
        );
      }

      if (response.statusCode == 404) {
        return DeleteAccountResult.error('Account not found');
      }

      if (response.statusCode >= 500) {
        return DeleteAccountResult.error(
          'Server error (${response.statusCode}). Please try again later.',
        );
      }

      // Try to parse error response
      try {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final error = json['error'] as String? ?? 'deletion_failed';
        final message = json['message'] as String? ?? 'Account deletion failed';
        return DeleteAccountResult.error('$error: $message');
      } catch (_) {
        return DeleteAccountResult.error('HTTP ${response.statusCode}');
      }
    } catch (e) {
      if (e.toString().contains('SocketException') ||
          e.toString().contains('Connection refused')) {
        return DeleteAccountResult.error(
          'Cannot connect to server. Check your internet connection.',
        );
      }
      return DeleteAccountResult.error('Network error: $e');
    }
  }

  void close() {
    _client.close();
  }
}
