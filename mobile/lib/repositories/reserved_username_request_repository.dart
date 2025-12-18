// ABOUTME: Repository for submitting reserved username requests
// ABOUTME: Handles API calls to backend for username reservation system
// ABOUTME: Currently stubbed with simulated API call until backend is ready

import 'package:http/http.dart' as http;

/// Result of a reserved username request submission
class ReservedUsernameRequestResult {
  const ReservedUsernameRequestResult({
    required this.success,
    this.error,
  });

  /// Creates a successful result
  const ReservedUsernameRequestResult.success()
      : success = true,
        error = null;

  /// Creates a failure result with an error message
  const ReservedUsernameRequestResult.failure(String errorMessage)
      : success = false,
        error = errorMessage;

  /// Whether the request was successful
  final bool success;

  /// Error message if the request failed
  final String? error;
}

/// Repository that handles reserved username request operations
///
/// This sits between the notifier and service layers, providing
/// a clean interface for the presentation layer to use.
class ReservedUsernameRequestRepository {
  ReservedUsernameRequestRepository(this._httpClient);

  final http.Client _httpClient;

  /// Submit a request for a reserved username
  ///
  /// Takes the desired [username], requester's [email], and
  /// [justification] for why the username should be reserved.
  ///
  /// Returns [ReservedUsernameRequestResult] indicating success or failure.
  Future<ReservedUsernameRequestResult> submitRequest({
    required String username,
    required String email,
    required String justification,
  }) async {
    // TODO(backend): Replace this stub with actual API call when backend is ready
    // Expected endpoint: POST /api/reserved-usernames/request
    // Body: { "username": "...", "email": "...", "justification": "..." }
    // Response: { "success": true } or { "success": false, "error": "..." }
    //
    // Example implementation:
    // try {
    //   final response = await _httpClient.post(
    //     Uri.parse('https://api.openvine.com/api/reserved-usernames/request'),
    //     headers: {'Content-Type': 'application/json'},
    //     body: jsonEncode({
    //       'username': username,
    //       'email': email,
    //       'justification': justification,
    //     }),
    //   );
    //
    //   if (response.statusCode == 200) {
    //     return const ReservedUsernameRequestResult.success();
    //   } else {
    //     final body = jsonDecode(response.body);
    //     return ReservedUsernameRequestResult.failure(
    //       body['error'] ?? 'Failed to submit request',
    //     );
    //   }
    // } catch (e) {
    //   return ReservedUsernameRequestResult.failure(
    //     'Network error: ${e.toString()}',
    //   );
    // }

    // Simulate API call with 1 second delay
    await Future<void>.delayed(const Duration(seconds: 1));

    // Always return success for now
    return const ReservedUsernameRequestResult.success();
  }
}
