// ABOUTME: Custom exceptions for Keycast operations
// ABOUTME: Provides typed exceptions for session, OAuth, RPC, and key errors

class KeycastException implements Exception {
  KeycastException(this.message);
  final String message;

  @override
  String toString() => 'KeycastException: $message';
}

class SessionExpiredException extends KeycastException {
  SessionExpiredException([String? message])
    : super(message ?? 'Session has expired');
}

class OAuthException extends KeycastException {
  OAuthException(super.message, {this.errorCode});
  final String? errorCode;

  @override
  String toString() => errorCode != null
      ? 'OAuthException [$errorCode]: $message'
      : 'OAuthException: $message';
}

class RpcException extends KeycastException {
  RpcException(super.message, {this.method});
  final String? method;

  @override
  String toString() => method != null
      ? 'RpcException [$method]: $message'
      : 'RpcException: $message';
}

class InvalidKeyException extends KeycastException {
  InvalidKeyException(super.message);
}
