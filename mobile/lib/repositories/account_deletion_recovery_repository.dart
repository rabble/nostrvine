// ABOUTME: NIP-98 client for durable immediate-account-deletion attempts.
// ABOUTME: Prepares, submits, resumes, and cancels cross-service deletion work.

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:openvine/models/account_deletion_attempt.dart';
import 'package:openvine/services/nip98_auth_service.dart';

class AccountDeletionRecoveryException implements Exception {
  const AccountDeletionRecoveryException(this.message);

  final String message;

  @override
  String toString() => 'AccountDeletionRecoveryException($message)';
}

class AccountDeletionRecoveryRepository {
  AccountDeletionRecoveryRepository({
    required String baseUrl,
    required String nameServerBaseUrl,
    required http.Client httpClient,
    required Nip98AuthService nip98AuthService,
    required String? Function() currentPubkey,
    Duration timeout = const Duration(seconds: 15),
  }) : _baseUrl = baseUrl.endsWith('/')
           ? baseUrl.substring(0, baseUrl.length - 1)
           : baseUrl,
       _httpClient = httpClient,
       _nameServerBaseUrl = nameServerBaseUrl.endsWith('/')
           ? nameServerBaseUrl.substring(0, nameServerBaseUrl.length - 1)
           : nameServerBaseUrl,
       _nip98AuthService = nip98AuthService,
       _currentPubkey = currentPubkey,
       _timeout = timeout;

  static const _attemptsPath = '/api/account-deletion/attempts';

  final String _baseUrl;
  final http.Client _httpClient;
  final String _nameServerBaseUrl;
  final Nip98AuthService _nip98AuthService;
  final String? Function() _currentPubkey;
  final Duration _timeout;

  Uri get _attemptsUri => Uri.parse('$_baseUrl$_attemptsPath');
  Uri get _currentAttemptUri => Uri.parse('$_baseUrl$_attemptsPath/current');
  Uri _submitUri(String id) =>
      Uri.parse('$_baseUrl$_attemptsPath/${Uri.encodeComponent(id)}/submit');
  Uri _cancelUri(String id) =>
      Uri.parse('$_baseUrl$_attemptsPath/${Uri.encodeComponent(id)}/cancel');
  Uri _usernamePreparedUri(String id) => Uri.parse(
    '$_baseUrl$_attemptsPath/${Uri.encodeComponent(id)}/username-prepared',
  );
  Uri get _namePrepareUri =>
      Uri.parse('$_nameServerBaseUrl/api/username/release/prepare');

  Future<AccountDeletionAttempt> prepare({String? username}) async {
    final attempt = await _post(
      uri: _attemptsUri,
      body: jsonEncode({'username': ?username}),
      acceptedStatusCodes: const {200, 201},
    );
    if (username == null) return attempt;
    if (attempt.status == AccountDeletionAttemptStatus.recoverable) {
      return attempt;
    }
    if (attempt.status != AccountDeletionAttemptStatus.preparing) {
      throw AccountDeletionRecoveryException(
        'Coordinator prepare returned ${attempt.status.name}',
      );
    }

    final nameBody = jsonEncode({
      'name': username,
      'attempt_id': attempt.id,
    });
    final nameHeaders = await _authHeaders(
      uri: _namePrepareUri,
      method: HttpMethod.post,
      payload: nameBody,
    );
    final nameResponse = await _httpClient
        .post(_namePrepareUri, headers: nameHeaders, body: nameBody)
        .timeout(_timeout);
    if (nameResponse.statusCode != 200) {
      throw AccountDeletionRecoveryException(
        'Username preparation failed (${nameResponse.statusCode})',
      );
    }
    final nameJson = jsonDecode(nameResponse.body) as Map<String, dynamic>;
    final expiresAt = (nameJson['expires_at'] as num?)?.toInt();
    final returnedAttemptId = nameJson['attempt_id'] as String?;
    if (expiresAt == null || returnedAttemptId != attempt.id) {
      throw const AccountDeletionRecoveryException(
        'Username preparation returned an invalid response',
      );
    }
    return _post(
      uri: _usernamePreparedUri(attempt.id),
      body: jsonEncode({
        'attempt_id': attempt.id,
        'username': username,
        'expires_at': expiresAt,
      }),
      acceptedStatusCodes: const {200},
    );
  }

  Future<AccountDeletionAttempt?> fetchCurrent() async {
    final uri = _currentAttemptUri;
    final headers = await _authHeaders(uri: uri, method: HttpMethod.get);
    try {
      final response = await _httpClient
          .get(uri, headers: headers)
          .timeout(_timeout);
      if (response.statusCode == 404) return null;
      if (response.statusCode != 200) {
        throw AccountDeletionRecoveryException(
          'Status lookup failed (${response.statusCode})',
        );
      }
      return _decodeAttempt(response.body);
    } on TimeoutException {
      throw const AccountDeletionRecoveryException('Status lookup timed out');
    }
  }

  Future<AccountDeletionAttempt> submit({
    required String attemptId,
    required String vanishEventId,
  }) async {
    return _post(
      uri: _submitUri(attemptId),
      body: jsonEncode({'vanish_event_id': vanishEventId}),
      acceptedStatusCodes: const {200, 202},
    );
  }

  Future<AccountDeletionAttempt> cancel({required String attemptId}) async {
    return _post(
      uri: _cancelUri(attemptId),
      body: '{}',
      acceptedStatusCodes: const {200},
    );
  }

  Future<AccountDeletionAttempt> _post({
    required Uri uri,
    required String body,
    required Set<int> acceptedStatusCodes,
  }) async {
    final headers = await _authHeaders(
      uri: uri,
      method: HttpMethod.post,
      payload: body,
    );
    try {
      final response = await _httpClient
          .post(uri, headers: headers, body: body)
          .timeout(_timeout);
      if (!acceptedStatusCodes.contains(response.statusCode)) {
        throw AccountDeletionRecoveryException(
          'Deletion attempt request failed (${response.statusCode})',
        );
      }
      return _decodeAttempt(response.body);
    } on TimeoutException {
      throw const AccountDeletionRecoveryException(
        'Deletion attempt request timed out',
      );
    }
  }

  Future<Map<String, String>> _authHeaders({
    required Uri uri,
    required HttpMethod method,
    String? payload,
  }) async {
    final token = await _nip98AuthService.createAuthToken(
      url: uri.toString(),
      method: method,
      payload: payload,
    );
    if (token == null) {
      throw const AccountDeletionRecoveryException(
        'Could not authorize deletion attempt request',
      );
    }
    final currentPubkey = _currentPubkey();
    if (currentPubkey == null || token.signedEvent.pubkey != currentPubkey) {
      throw const AccountDeletionRecoveryException(
        'Deletion attempt authorization targeted the wrong account',
      );
    }
    return {
      'Accept': 'application/json',
      'Authorization': token.authorizationHeader,
      if (payload != null) 'Content-Type': 'application/json',
    };
  }

  AccountDeletionAttempt _decodeAttempt(String body) {
    try {
      return AccountDeletionAttempt.fromJson(
        jsonDecode(body) as Map<String, dynamic>,
      );
    } on FormatException {
      rethrow;
    } on Object catch (error) {
      throw AccountDeletionRecoveryException(
        'Invalid deletion attempt response: $error',
      );
    }
  }
}
