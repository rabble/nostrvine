// ABOUTME: OAuth error model for Keycast authentication errors
// ABOUTME: Represents structured OAuth errors from server responses

class OAuthError {
  final String error;
  final String? errorDescription;

  const OAuthError({required this.error, this.errorDescription});

  factory OAuthError.fromJson(Map<String, dynamic> json) {
    return OAuthError(
      error: json['error'] as String,
      errorDescription: json['error_description'] as String?,
    );
  }

  factory OAuthError.fromQueryParams(Map<String, String> params) {
    return OAuthError(
      error: params['error'] ?? 'unknown_error',
      errorDescription: params['error_description'],
    );
  }

  @override
  String toString() => errorDescription != null
      ? 'OAuthError: $error - $errorDescription'
      : 'OAuthError: $error';
}
