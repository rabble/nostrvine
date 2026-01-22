// ABOUTME: Response models for headless authentication API
// ABOUTME: Supports native login/register flows without browser redirects

/// Result from POST /api/headless/register
class HeadlessRegisterResult {
  final bool success;
  final String pubkey;
  final bool verificationRequired;
  final String? deviceCode;
  final String? email;
  final String? error;

  HeadlessRegisterResult({
    required this.success,
    required this.pubkey,
    required this.verificationRequired,
    this.deviceCode,
    this.email,
    this.error,
  });

  factory HeadlessRegisterResult.fromJson(Map<String, dynamic> json) {
    return HeadlessRegisterResult(
      success: json['success'] as bool? ?? false,
      pubkey: json['pubkey'] as String? ?? '',
      verificationRequired: json['verification_required'] as bool? ?? true,
      deviceCode: json['device_code'] as String?,
      email: json['email'] as String?,
      error: json['error'] as String?,
    );
  }

  factory HeadlessRegisterResult.error(String message) {
    return HeadlessRegisterResult(
      success: false,
      pubkey: '',
      verificationRequired: false,
      error: message,
    );
  }
}

/// Result from POST /api/headless/login
class HeadlessLoginResult {
  final bool success;
  final String? code;
  final String? pubkey;
  final String? state;
  final String? error;
  final String? errorDescription;

  HeadlessLoginResult({
    required this.success,
    this.code,
    this.pubkey,
    this.state,
    this.error,
    this.errorDescription,
  });

  factory HeadlessLoginResult.fromJson(Map<String, dynamic> json) {
    return HeadlessLoginResult(
      success: json['success'] as bool? ?? false,
      code: json['code'] as String?,
      pubkey: json['pubkey'] as String?,
      state: json['state'] as String?,
      error: json['error'] as String?,
      errorDescription: json['error_description'] as String?,
    );
  }

  factory HeadlessLoginResult.error(String message, {String? code}) {
    return HeadlessLoginResult(
      success: false,
      error: code ?? 'client_error',
      errorDescription: message,
    );
  }
}

/// Result from GET /api/oauth/poll
class PollResult {
  final PollStatus status;
  final String? code;
  final String? error;

  PollResult({required this.status, this.code, this.error});

  factory PollResult.pending() => PollResult(status: PollStatus.pending);

  factory PollResult.complete(String code) =>
      PollResult(status: PollStatus.complete, code: code);

  factory PollResult.error(String message) =>
      PollResult(status: PollStatus.error, error: message);
}

enum PollStatus {
  pending, // Still waiting for email verification
  complete, // User verified, code available
  error, // Something went wrong
}

/// Result from POST /api/auth/forgot-password
class ForgotPasswordResult {
  final bool success;
  final String? message;
  final String? error;

  ForgotPasswordResult({required this.success, this.message, this.error});

  factory ForgotPasswordResult.fromJson(Map<String, dynamic> json) {
    return ForgotPasswordResult(
      success: json['success'] as bool? ?? false,
      message: json['message'] as String?,
      error: json['error'] as String?,
    );
  }

  factory ForgotPasswordResult.error(String message) {
    return ForgotPasswordResult(success: false, error: message);
  }
}

class ResetPasswordResult {
  final bool success;
  final String? message;

  ResetPasswordResult({required this.success, this.message});

  factory ResetPasswordResult.fromJson(Map<String, dynamic> json) {
    return ResetPasswordResult(
      success: json['success'] as bool? ?? false,
      message: json['message'] as String?,
    );
  }

  factory ResetPasswordResult.error(String message) {
    return ResetPasswordResult(success: false, message: message);
  }
}

/// Result from DELETE /api/user/account
class DeleteAccountResult {
  final bool success;
  final String? message;
  final String? error;

  DeleteAccountResult({required this.success, this.message, this.error});

  factory DeleteAccountResult.fromJson(Map<String, dynamic> json) {
    return DeleteAccountResult(
      success: json['success'] as bool? ?? false,
      message: json['message'] as String?,
      error: json['error'] as String?,
    );
  }

  factory DeleteAccountResult.error(String message) {
    return DeleteAccountResult(success: false, error: message);
  }
}

/// Result from POST /api/auth/verify-email
class VerifyEmailResult {
  final bool success;
  final String? message;
  final String? error;

  VerifyEmailResult({required this.success, this.message, this.error});

  factory VerifyEmailResult.fromJson(Map<String, dynamic> json) {
    return VerifyEmailResult(
      success: json['success'] as bool? ?? false,
      message: json['message'] as String?,
      error: json['error'] as String?,
    );
  }

  factory VerifyEmailResult.error(String message) {
    return VerifyEmailResult(success: false, error: message);
  }
}
