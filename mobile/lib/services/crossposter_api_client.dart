// ABOUTME: HTTP client for crossposter.divine.video manual crossposting
// ABOUTME: Lists connected platforms and creates/polls per-video crosspost jobs

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:keycast_flutter/keycast_flutter.dart';
import 'package:openvine/models/crosspost_models.dart';

export 'package:openvine/models/crosspost_models.dart';

/// Client for the crossposter service (`crossposter.divine.video`).
///
/// Authenticates with the app's Keycast OAuth bearer token, the same
/// token used by [ApiService]-style Divine backends.
class CrossposterApiClient {
  CrossposterApiClient({
    required KeycastOAuth oauthClient,
    this.baseUrl = defaultBaseUrl,
    http.Client? httpClient,
  }) : _oauthClient = oauthClient,
       _httpClient = httpClient ?? http.Client();

  /// Production crossposter endpoint.
  static const String defaultBaseUrl = CrossposterUrls.base;

  static const _timeout = Duration(seconds: 20);

  final KeycastOAuth _oauthClient;
  final String baseUrl;
  final http.Client _httpClient;

  Future<Map<String, String>> _authHeaders() async {
    final session = await _oauthClient.getSession();
    final token = session?.accessToken;
    if (token == null) {
      throw const CrossposterApiException(
        'Not authenticated',
        statusCode: 401,
        code: 'unauthorized',
      );
    }
    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
  }

  /// Fetch the caller's platform connections (all statuses).
  ///
  /// Throws [CrossposterApiException] when unauthenticated or on a
  /// non-200 response.
  Future<List<CrossposterConnection>> getConnections() async {
    final response = await _httpClient
        .get(Uri.parse('$baseUrl/connections'), headers: await _authHeaders())
        .timeout(_timeout);
    final json = _decodeOrThrow(response, 'Failed to fetch connections');
    final connections = json['connections'] as List<dynamic>? ?? [];
    return connections
        .whereType<Map<String, dynamic>>()
        .map(CrossposterConnection.fromJson)
        .toList();
  }

  /// Trigger crossposts of the video [eventId] to [platforms].
  ///
  /// Idempotent server-side: repeat calls return the existing jobs
  /// rather than double-posting.
  ///
  /// Throws [CrossposterApiException] on failure; the `code` field
  /// carries server codes such as `not_owner`, `not_eligible`, and
  /// `not_connected`.
  Future<List<CrosspostJob>> createCrossposts({
    required String eventId,
    required List<String> platforms,
  }) async {
    final response = await _httpClient
        .post(
          Uri.parse('$baseUrl/videos/$eventId/crossposts'),
          headers: await _authHeaders(),
          body: jsonEncode({'platforms': platforms}),
        )
        .timeout(_timeout);
    final json = _decodeOrThrow(response, 'Failed to create crossposts');
    return _parseJobs(json);
  }

  /// Fetch the current crosspost jobs for the video [eventId].
  ///
  /// Throws [CrossposterApiException] when unauthenticated or on a
  /// non-200 response.
  Future<List<CrosspostJob>> getCrossposts({required String eventId}) async {
    final response = await _httpClient
        .get(
          Uri.parse('$baseUrl/videos/$eventId/crossposts'),
          headers: await _authHeaders(),
        )
        .timeout(_timeout);
    final json = _decodeOrThrow(response, 'Failed to fetch crossposts');
    return _parseJobs(json);
  }

  List<CrosspostJob> _parseJobs(Map<String, dynamic> json) {
    final jobs = json['jobs'] as List<dynamic>? ?? [];
    return jobs
        .whereType<Map<String, dynamic>>()
        .map(CrosspostJob.fromJson)
        .toList();
  }

  Map<String, dynamic> _decodeOrThrow(
    http.Response response,
    String fallbackMessage,
  ) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) return decoded;
      throw CrossposterApiException(
        fallbackMessage,
        statusCode: response.statusCode,
      );
    }
    String? code;
    String? message;
    try {
      final decoded = jsonDecode(response.body);
      final error = decoded is Map<String, dynamic> ? decoded['error'] : null;
      if (error is Map<String, dynamic>) {
        final rawCode = error['code'];
        final rawMessage = error['message'];
        if (rawCode is String) code = rawCode;
        if (rawMessage is String) message = rawMessage;
      }
    } on FormatException {
      // Non-JSON error body — fall through to the generic message.
    }
    throw CrossposterApiException(
      message ?? fallbackMessage,
      statusCode: response.statusCode,
      code: code,
    );
  }
}
