// ABOUTME: OAuth callback result types (sealed class)
// ABOUTME: Represents success (code) or error from OAuth redirect

sealed class CallbackResult {
  const CallbackResult();
}

class CallbackSuccess extends CallbackResult {
  final String code;

  const CallbackSuccess({required this.code});
}

class CallbackError extends CallbackResult {
  final String error;
  final String? description;

  const CallbackError({
    required this.error,
    this.description,
  });

  @override
  String toString() => description != null
      ? 'CallbackError: $error - $description'
      : 'CallbackError: $error';
}
