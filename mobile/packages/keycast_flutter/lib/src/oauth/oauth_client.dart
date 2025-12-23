// ABOUTME: Keycast OAuth client for authentication flow
// ABOUTME: Handles authorization URL generation, callback parsing, and token exchange

import 'dart:convert';
import 'package:http/http.dart' as http;

import 'oauth_config.dart';
import 'callback_result.dart';
import 'token_response.dart';
import 'pkce.dart';
import '../crypto/key_utils.dart';
import '../models/exceptions.dart';
import '../models/keycast_session.dart';
import '../storage/keycast_storage.dart';

/// Storage key for session credentials
const _storageKeySession = 'keycast_session';

/// Storage key for authorization handle (for silent re-auth when session expires)
const _storageKeyHandle = 'keycast_auth_handle';

class KeycastOAuth {
  final OAuthConfig config;
  final http.Client _client;
  final KeycastStorage _storage;

  KeycastOAuth({
    required this.config,
    http.Client? httpClient,
    KeycastStorage? storage,
  })  : _client = httpClient ?? http.Client(),
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

  /// Clear all session data including authorization handle
  /// Use this when user explicitly logs out - clears everything for security
  Future<void> logout() async {
    await _storage.delete(_storageKeySession);
    await _storage.delete(_storageKeyHandle);
    await _client.post(
      Uri.parse('${config.serverUrl}/api/auth/logout'),
    );
  }

  Future<void> _saveSession(KeycastSession session) async {
    await _storage.write(_storageKeySession, jsonEncode(session.toJson()));
    if (session.authorizationHandle != null) {
      await _storage.write(_storageKeyHandle, session.authorizationHandle!);
    }
  }

  /// Generate authorization URL for OAuth flow
  /// Automatically uses stored authorization handle for silent re-auth if available
  Future<(String url, String verifier)> getAuthorizationUrl({
    String? nsec,
    String scope = 'policy:social',
    bool defaultRegister = true,
    String? authorizationHandle,
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

    // Use provided handle, or auto-load from storage for silent re-authentication
    final handle = authorizationHandle ?? await getAuthorizationHandle();
    if (handle != null) {
      params['authorization_handle'] = handle;
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

    return CallbackError(
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

  void close() {
    _client.close();
  }
}
