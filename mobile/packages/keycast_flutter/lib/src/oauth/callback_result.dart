// ABOUTME: OAuth callback result types (sealed class)
// ABOUTME: Represents success (code) or error from OAuth redirect

sealed class CallbackResult {
  const CallbackResult();
}

class CallbackSuccess extends CallbackResult {
  const CallbackSuccess({required this.code});
  final String code;
}

class CallbackError extends CallbackResult {
  const CallbackError({required this.error, this.description});
  final String error;
  final String? description;

  @override
  String toString() => description != null
      ? 'CallbackError: $error - $description'
      : 'CallbackError: $error';
}
