// ABOUTME: NIP-98 client for durable immediate-account-deletion attempts.
// ABOUTME: Prepares, submits, resumes, and cancels cross-service deletion work.

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:openvine/models/account_deletion_attempt.dart';
import 'package:openvine/services/nip98_auth_service.dart';

class AccountDeletionRecoveryException implements Exception {
  const AccountDeletionRecoveryException(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() =>
      'AccountDeletionRecoveryException($message, code: $code)';
}

class AccountDeletionRecoveryRepository {
  AccountDeletionRecoveryRepository({
    required String baseUrl,
    required String nameServerBaseUrl,
    required http.Client httpClient,
    required Nip98AuthService nip98AuthService,
    required String? Function() currentPubkey,
    Duration timeout = const Duration(seconds: 15),
    Duration retryBaseDelay = const Duration(milliseconds: 500),
    Future<void> Function(Duration) delay = Future<void>.delayed,
  }) : _baseUrl = baseUrl.endsWith('/')
           ? baseUrl.substring(0, baseUrl.length - 1)
           : baseUrl,
       _httpClient = httpClient,
       _nameServerBaseUrl = nameServerBaseUrl.endsWith('/')
           ? nameServerBaseUrl.substring(0, nameServerBaseUrl.length - 1)
           : nameServerBaseUrl,
       _nip98AuthService = nip98AuthService,
       _currentPubkey = currentPubkey,
       _timeout = timeout,
       _retryBaseDelay = retryBaseDelay,
       _delay = delay;

  static const _attemptsPath = '/api/account-deletion/attempts';

  final String _baseUrl;
  final http.Client _httpClient;
  final String _nameServerBaseUrl;
  final Nip98AuthService _nip98AuthService;
  final String? Function() _currentPubkey;
  final Duration _timeout;
  final Duration _retryBaseDelay;
  final Future<void> Function(Duration) _delay;

  static const _maxAttempts = 3;

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
    return resumePreparation(attempt);
  }

  /// Completes the username handshake for an existing preparing attempt.
  ///
  /// Recovery must preserve the coordinator's attempt id. Creating another
  /// attempt here would rely on an undocumented POST idempotency contract and
  /// could orphan the attempt returned by `fetchCurrent`.
  Future<AccountDeletionAttempt> resumePreparation(
    AccountDeletionAttempt attempt,
  ) async {
    final username = attempt.username;
    if (username == null) {
      throw const AccountDeletionRecoveryException(
        'Preparing username attempt did not include a username',
      );
    }
    if (attempt.status == AccountDeletionAttemptStatus.recoverable) {
      return attempt;
    }
    if (attempt.isCancellationInFlight) {
      throw const AccountDeletionRecoveryException(
        'Username preparation cannot resume during cancellation',
        code: 'illegal_transition',
      );
    }
    if (attempt.status != AccountDeletionAttemptStatus.preparing) {
      throw AccountDeletionRecoveryException(
        'Coordinator prepare returned ${attempt.status.name}',
      );
    }

    final nameBody = jsonEncode({'name': username, 'attempt_id': attempt.id});
    final nameHeaders = await _authHeaders(
      uri: _namePrepareUri,
      method: HttpMethod.post,
      payload: nameBody,
    );
    final http.Response nameResponse;
    try {
      nameResponse = await _sendWithRetry(
        () => _httpClient
            .post(_namePrepareUri, headers: nameHeaders, body: nameBody)
            .timeout(_timeout),
      );
    } on TimeoutException {
      throw const AccountDeletionRecoveryException(
        'Username preparation timed out',
      );
    }
    if (nameResponse.statusCode != 200) {
      throw _exceptionFromResponse(
        nameResponse,
        'Username preparation failed',
      );
    }
    final Map<String, dynamic> nameJson;
    try {
      nameJson = jsonDecode(nameResponse.body) as Map<String, dynamic>;
    } on Object {
      throw const AccountDeletionRecoveryException(
        'Username preparation returned an invalid response',
      );
    }
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
      final response = await _sendWithRetry(
        () => _httpClient.get(uri, headers: headers).timeout(_timeout),
      );
      if (response.statusCode == 404) return null;
      if (response.statusCode != 200) {
        throw _exceptionFromResponse(response, 'Status lookup failed');
      }
      return _decodeAttempt(response.body);
    } on TimeoutException {
      throw const AccountDeletionRecoveryException('Status lookup timed out');
    }
  }

  Stream<AccountDeletionAttempt?> watchCurrent({
    Duration pollInterval = const Duration(seconds: 2),
  }) async* {
    var attempt = await fetchCurrent();
    yield attempt;
    while (attempt?.needsPolling ?? false) {
      await _delay(pollInterval);
      attempt = await fetchCurrent();
      yield attempt;
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
      acceptedStatusCodes: const {200, 202},
    );
  }

  Future<AccountDeletionAttempt> cancelAndWait({
    required String attemptId,
  }) async {
    final cancellation = await cancel(attemptId: attemptId);
    if (cancellation.status == AccountDeletionAttemptStatus.cancelled) {
      return cancellation;
    }
    if (!cancellation.isCancellationInFlight) {
      throw const AccountDeletionRecoveryException(
        'Server did not start account deletion cancellation',
      );
    }
    await for (final current in watchCurrent()) {
      if (current == null || current.id != attemptId) {
        throw const AccountDeletionRecoveryException(
          'Cancellation status did not match the account deletion attempt',
        );
      }
      if (current.status == AccountDeletionAttemptStatus.cancelled) {
        return current;
      }
      if (!current.isCancellationInFlight) {
        throw const AccountDeletionRecoveryException(
          'Account deletion cancellation ended in an invalid state',
        );
      }
    }
    throw const AccountDeletionRecoveryException(
      'Account deletion cancellation ended without a terminal state',
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
      final response = await _sendWithRetry(
        () => _httpClient
            .post(uri, headers: headers, body: body)
            .timeout(_timeout),
      );
      if (!acceptedStatusCodes.contains(response.statusCode)) {
        throw _exceptionFromResponse(
          response,
          'Deletion attempt request failed',
        );
      }
      return _decodeAttempt(response.body);
    } on TimeoutException {
      throw const AccountDeletionRecoveryException(
        'Deletion attempt request timed out',
      );
    }
  }

  Future<http.Response> _sendWithRetry(
    Future<http.Response> Function() send,
  ) async {
    for (var attempt = 1; attempt <= _maxAttempts; attempt++) {
      final response = await send();
      if (!_isRetryable(response.statusCode) || attempt == _maxAttempts) {
        return response;
      }
      await _delay(_retryBaseDelay * (1 << (attempt - 1)));
    }
    throw StateError('Retry loop completed without a response');
  }

  bool _isRetryable(int statusCode) =>
      statusCode == 429 || (statusCode >= 500 && statusCode <= 599);

  AccountDeletionRecoveryException _exceptionFromResponse(
    http.Response response,
    String fallback,
  ) {
    String? code;
    try {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      code = (json['failure_code'] ?? json['code']) as String?;
    } on Object {
      // The status code and localized client fallback remain authoritative.
    }
    return AccountDeletionRecoveryException(
      '$fallback (${response.statusCode})',
      code: code,
    );
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
