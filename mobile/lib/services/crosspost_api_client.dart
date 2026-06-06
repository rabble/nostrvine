// ABOUTME: HTTP client for Bluesky crosspost settings via keycast API
// ABOUTME: Fetches status and toggles crossposting for a user's account link

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:keycast_flutter/keycast_flutter.dart';

/// Response model for crosspost status from keycast's `AtprotoStatusResponse`.
class CrosspostStatus {
  const CrosspostStatus({
    required this.crosspostEnabled,
    this.handle,
    this.provisioningState,
    this.did,
  });

  /// Builds a status from keycast's `AtprotoStatusResponse` JSON shape:
  /// `{enabled, state, did, username}`.
  ///
  /// `username` is the bare local part; the displayable Bluesky handle is
  /// `<username>.divine.video`.
  factory CrosspostStatus.fromJson(Map<String, dynamic> json) {
    final username = json['username'] as String?;
    return CrosspostStatus(
      crosspostEnabled: json['enabled'] as bool? ?? false,
      handle: username == null ? null : '$username.$_handleDomain',
      provisioningState: json['state'] as String?,
      did: json['did'] as String?,
    );
  }

  static const _handleDomain = 'divine.video';

  final bool crosspostEnabled;
  final String? handle;
  final String? provisioningState;
  final String? did;
}

/// Client for keycast crosspost API endpoints.
class CrosspostApiClient {
  CrosspostApiClient({
    required KeycastOAuth oauthClient,
    required String serverUrl,
    http.Client? httpClient,
  }) : _oauthClient = oauthClient,
       _serverUrl = serverUrl,
       _httpClient = httpClient ?? http.Client();

  final KeycastOAuth _oauthClient;
  final String _serverUrl;
  final http.Client _httpClient;

  Future<Map<String, String>> _authHeaders() async {
    final session = await _oauthClient.getSession();
    final token = session?.accessToken;
    if (token == null) {
      throw const CrosspostApiException('Not authenticated', statusCode: 401);
    }
    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
  }

  /// Fetch the current crosspost status for the authenticated user.
  ///
  /// The bearer token identifies the user, so no pubkey is part of the path.
  /// keycast returns 200 for any authenticated user (no account link yields
  /// `enabled:false, state:null`); the 404 branch is a tolerant fallback
  /// rather than the expected "no account" signal.
  ///
  /// Throws [CrosspostApiException] when unauthenticated or on a non-200,
  /// non-404 response.
  Future<CrosspostStatus> getStatus() async {
    final headers = await _authHeaders();
    final uri = Uri.parse('$_serverUrl/api/user/atproto/status');
    final response = await _httpClient.get(uri, headers: headers);

    if (response.statusCode == 404) {
      // No account link exists — return disabled default
      return const CrosspostStatus(crosspostEnabled: false);
    }

    if (response.statusCode != 200) {
      throw CrosspostApiException(
        'Failed to fetch crosspost status',
        statusCode: response.statusCode,
      );
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return CrosspostStatus.fromJson(json);
  }

  /// Toggle crossposting for [pubkey].
  Future<CrosspostStatus> setCrosspost({
    required String pubkey,
    required bool enabled,
  }) async {
    final headers = await _authHeaders();
    final uri = Uri.parse('$_serverUrl/api/account/$pubkey/crosspost');
    final response = await _httpClient.put(
      uri,
      headers: headers,
      body: jsonEncode({'enabled': enabled}),
    );

    if (response.statusCode != 200) {
      throw CrosspostApiException(
        'Failed to update crosspost setting',
        statusCode: response.statusCode,
      );
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return CrosspostStatus.fromJson(json);
  }
}

class CrosspostApiException implements Exception {
  const CrosspostApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() =>
      'CrosspostApiException: $message (${statusCode ?? 'no status'})';
}
