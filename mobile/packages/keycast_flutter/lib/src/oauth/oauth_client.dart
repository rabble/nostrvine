// ABOUTME: Keycast OAuth client for authentication flow
// ABOUTME: Handles authorization URL generation, callback parsing, token
// exchange, and headless auth

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:keycast_flutter/src/crypto/key_utils.dart';
import 'package:keycast_flutter/src/models/exceptions.dart';
import 'package:keycast_flutter/src/models/keycast_session.dart';
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

class KeycastOAuth {
  final OAuthConfig config;
  final http.Client _client;
  final KeycastStorage _storage;

  KeycastOAuth({
    required this.config,
    http.Client? httpClient,
    KeycastStorage? storage,
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
    await _storage.delete(_storageKeySession);
    await _storage.delete(_storageKeyHandle);
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
  Future<TokenResponse> exchangeCode({
    required String code,
    required String verifier,
  }) async {
    final response = await _client.post(
      Uri.parse(config.tokenUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'grant_type': 'authorization_code',
        'code': code,
        'client_id': config.clientId,
        'redirect_uri': config.redirectUri,
        'code_verifier': verifier,
      }),
    );

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

      final response = await _client.post(
        Uri.parse('${config.serverUrl}/api/headless/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

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

      final response = await _client.post(
        Uri.parse('${config.serverUrl}/api/headless/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

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
      final response = await _client.get(
        Uri.parse(
          '${config.serverUrl}/api/oauth/poll',
        ).replace(queryParameters: {'device_code': deviceCode}),
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
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
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final error = json['error'] as String? ?? 'poll_failed';
        final description =
            json['error_description'] as String? ?? 'Polling failed';
        return PollResult.error('$error: $description');
      } catch (_) {
        return PollResult.error('HTTP ${response.statusCode}');
      }
    } catch (e) {
      return PollResult.error('Network error: $e');
    }
  }

  /// Send a password reset link to the provided email address
  Future<ForgotPasswordResult> sendPasswordResetEmail(String email) async {
    try {
      final response = await _client.post(
        Uri.parse('${config.serverUrl}/api/auth/forgot-password'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email}),
      );

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
      final response = await _client.post(
        Uri.parse('${config.serverUrl}/api/auth/reset-password'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'token': token, 'new_password': newPassword}),
      );

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
      final response = await _client.post(
        Uri.parse('${config.serverUrl}/api/auth/verify-email'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'token': token}),
      );

      final json = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 || response.statusCode == 201) {
        return VerifyEmailResult.fromJson(json);
      }

      // Handle server-side errors
      final message = json['message']?.toString() ?? 'Failed to verify email';
      return VerifyEmailResult.error(message);
    } catch (e) {
      return VerifyEmailResult.error('Network error: $e');
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
