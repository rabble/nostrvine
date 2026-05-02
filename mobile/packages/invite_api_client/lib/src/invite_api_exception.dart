abstract final class InviteApiErrorCode {
  const InviteApiErrorCode._();

  // Server-returned codes.
  static const creatorPageFull = 'creator_page_full';
  static const authRequired = 'auth_required';
  static const authInvalid = 'auth_invalid';
  static const authExpired = 'auth_expired';
  static const authInvalidBinding = 'auth_invalid_binding';
  static const inviteNotFound = 'invite_not_found';
  static const inviteInvalidFormat = 'invite_invalid_format';
  static const inviteRevoked = 'invite_revoked';
  static const inviteCodeRotated = 'invite_code_rotated';
  static const creatorPageDisabled = 'creator_page_disabled';
  static const inviteAlreadyUsed = 'invite_already_used';
  static const userAlreadyJoined = 'user_already_joined';
  static const tooManyRequests = 'too_many_requests';
  static const storageError = 'storage_error';
  static const internalError = 'internal_error';

  // Client-synthesized codes.
  static const clientTimeout = 'client_timeout';
  static const clientNetworkError = 'client_network_error';
  static const clientAuthFailed = 'client_auth_failed';
  static const clientError = 'client_error';
}

class InviteApiException implements Exception {
  const InviteApiException(
    this.message, {
    this.statusCode,
    this.responseBody,
    this.code,
    this.creatorSlug,
    this.creatorDisplayName,
  });

  final String message;
  final int? statusCode;
  final String? responseBody;
  final String? code;
  final String? creatorSlug;
  final String? creatorDisplayName;

  @override
  String toString() =>
      'InviteApiException(message: $message, statusCode: $statusCode, '
      'code: $code)';
}
