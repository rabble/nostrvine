// ABOUTME: Models for the invite gate, waitlist, and onboarding mode

enum OnboardingMode { open, waitlistOnly, inviteCodeRequired }

OnboardingMode parseOnboardingMode(String? rawValue) {
  final normalized = rawValue?.trim().toLowerCase().replaceAll('-', '_');
  switch (normalized) {
    case 'waitlist_only':
      return OnboardingMode.waitlistOnly;
    case 'invite_code_required':
      return OnboardingMode.inviteCodeRequired;
    case 'open':
    default:
      return OnboardingMode.open;
  }
}

class InviteClientConfig {
  const InviteClientConfig({
    required this.mode,
    required this.supportEmail,
  });

  factory InviteClientConfig.fromJson(Map<String, dynamic> json) {
    final rawMode =
        json['onboardingMode'] ??
        json['onboarding_mode'] ??
        json['mode'] ??
        json['inviteMode'] ??
        json['invite_mode'];

    final supportEmail =
        json['supportEmail'] ?? json['support_email'] ?? 'support@divine.video';

    return InviteClientConfig(
      mode: parseOnboardingMode(rawMode as String?),
      supportEmail: supportEmail as String,
    );
  }

  final OnboardingMode mode;
  final String supportEmail;
}

class InviteValidationResult {
  const InviteValidationResult({
    required this.valid,
    required this.used,
    this.code,
  });

  factory InviteValidationResult.fromJson(Map<String, dynamic> json) {
    return InviteValidationResult(
      valid: json['valid'] == true,
      used: json['used'] == true,
      code: json['code'] as String?,
    );
  }

  final bool valid;
  final bool used;
  final String? code;

  bool get canContinue => valid && !used;
}

class WaitlistJoinResult {
  const WaitlistJoinResult({
    required this.id,
    required this.message,
  });

  factory WaitlistJoinResult.fromJson(Map<String, dynamic> json) {
    return WaitlistJoinResult(
      id: json['id'] as String? ?? '',
      message: json['message'] as String? ?? '',
    );
  }

  final String id;
  final String message;
}

class InviteConsumeResult {
  const InviteConsumeResult({
    required this.message,
    required this.codesAllocated,
  });

  factory InviteConsumeResult.fromJson(Map<String, dynamic> json) {
    return InviteConsumeResult(
      message: json['message'] as String? ?? '',
      codesAllocated:
          (json['codesAllocated'] ?? json['codes_allocated'] ?? 0) as int,
    );
  }

  final String message;
  final int codesAllocated;
}

class InviteAccessGrant {
  const InviteAccessGrant({
    required this.code,
    required this.validatedAt,
  });

  final String code;
  final DateTime validatedAt;
}
