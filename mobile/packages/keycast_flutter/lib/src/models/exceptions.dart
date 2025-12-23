// ABOUTME: Custom exceptions for Keycast operations
// ABOUTME: Provides typed exceptions for session, OAuth, RPC, and key errors

class KeycastException implements Exception {
  final String message;

  KeycastException(this.message);

  @override
  String toString() => 'KeycastException: $message';
}

class SessionExpiredException extends KeycastException {
  SessionExpiredException([String? message])
    : super(message ?? 'Session has expired');
}

class OAuthException extends KeycastException {
  final String? errorCode;

  OAuthException(super.message, {this.errorCode});

  @override
  String toString() => errorCode != null
      ? 'OAuthException [$errorCode]: $message'
      : 'OAuthException: $message';
}

class RpcException extends KeycastException {
  final String? method;

  RpcException(super.message, {this.method});

  @override
  String toString() => method != null
      ? 'RpcException [$method]: $message'
      : 'RpcException: $message';
}

class InvalidKeyException extends KeycastException {
  InvalidKeyException(super.message);
}
