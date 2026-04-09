// ABOUTME: Models for the invite gate, waitlist, onboarding mode, and invite status
// ABOUTME: InviteCode/InviteStatus are Equatable for use in BLoC state

import 'package:equatable/equatable.dart';

enum OnboardingMode { open, inviteCodeRequired }

OnboardingMode parseOnboardingMode(String? rawValue) {
  final normalized = rawValue?.trim().toLowerCase().replaceAll('-', '_');
  switch (normalized) {
    case 'waitlist_only':
    case 'invite_code':
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

class InviteCode extends Equatable {
  const InviteCode({
    required this.code,
    required this.claimed,
    this.claimedAt,
    this.claimedBy,
  });

  factory InviteCode.fromJson(Map<String, dynamic> json) {
    return InviteCode(
      code: json['code'] as String? ?? '',
      claimed: json['claimed'] == true,
      claimedAt: json['claimedAt'] != null
          ? DateTime.tryParse(json['claimedAt'] as String)
          : null,
      claimedBy: json['claimedBy'] as String?,
    );
  }

  final String code;
  final bool claimed;
  final DateTime? claimedAt;
  final String? claimedBy;

  @override
  List<Object?> get props => [code, claimed, claimedAt, claimedBy];
}

class InviteStatus extends Equatable {
  const InviteStatus({
    required this.canInvite,
    required this.remaining,
    required this.total,
    required this.codes,
  });

  factory InviteStatus.fromJson(Map<String, dynamic> json) {
    final rawCodes = json['codes'] as List<dynamic>? ?? [];
    return InviteStatus(
      canInvite: json['canInvite'] == true,
      remaining: (json['remaining'] ?? 0) as int,
      total: (json['total'] ?? 0) as int,
      codes: rawCodes
          .cast<Map<String, dynamic>>()
          .map(InviteCode.fromJson)
          .toList(),
    );
  }

  final bool canInvite;
  final int remaining;
  final int total;
  final List<InviteCode> codes;

  List<InviteCode> get unclaimedCodes =>
      codes.where((c) => !c.claimed).toList();

  bool get hasUnclaimedCodes => codes.any((c) => !c.claimed);

  @override
  List<Object?> get props => [canInvite, remaining, total, codes];
}

class GenerateInviteResult extends Equatable {
  const GenerateInviteResult({
    required this.code,
    required this.remaining,
  });

  factory GenerateInviteResult.fromJson(Map<String, dynamic> json) {
    return GenerateInviteResult(
      code: json['code'] as String? ?? '',
      remaining: (json['remaining'] ?? 0) as int,
    );
  }

  final String code;
  final int remaining;

  @override
  List<Object?> get props => [code, remaining];
}
