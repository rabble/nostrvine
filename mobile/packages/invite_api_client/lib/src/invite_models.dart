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
  const InviteClientConfig({required this.mode, required this.supportEmail});

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
    this.available,
    this.code,
    this.errorCode,
    this.creatorSlug,
    this.creatorDisplayName,
    this.remaining,
  });

  factory InviteValidationResult.fromJson(Map<String, dynamic> json) {
    return InviteValidationResult(
      valid: json['valid'] == true,
      used: json['used'] == true,
      available: json['available'] as bool?,
      code: json['code'] as String?,
      errorCode:
          json['errorCode'] as String? ??
          json['error_code'] as String? ??
          json['code_name'] as String?,
      creatorSlug:
          json['creatorSlug'] as String? ?? json['creator_slug'] as String?,
      creatorDisplayName:
          json['creatorDisplayName'] as String? ??
          json['creator_display_name'] as String?,
      remaining: json['remaining'] as int?,
    );
  }

  final bool valid;
  final bool used;
  final bool? available;
  final String? code;
  final String? errorCode;
  final String? creatorSlug;
  final String? creatorDisplayName;
  final int? remaining;

  bool get canContinue => valid && (available ?? !used);
}

class WaitlistJoinResult {
  const WaitlistJoinResult({required this.id, required this.message});

  factory WaitlistJoinResult.fromJson(Map<String, dynamic> json) {
    return WaitlistJoinResult(
      id: json['id'] as String? ?? '',
      message: json['message'] as String? ?? '',
    );
  }

  final String id;
  final String message;
}

enum InviteConsumeStatus {
  consumed,
  alreadyConsumed,
  userAlreadyJoined,
  unknown,
}

InviteConsumeStatus parseInviteConsumeStatus(String? rawValue) {
  switch (rawValue?.trim().toLowerCase()) {
    case 'consumed':
      return InviteConsumeStatus.consumed;
    case 'already_consumed':
      return InviteConsumeStatus.alreadyConsumed;
    case 'user_already_joined':
      return InviteConsumeStatus.userAlreadyJoined;
    default:
      return InviteConsumeStatus.unknown;
  }
}

class InviteConsumeResult {
  const InviteConsumeResult({
    required this.message,
    required this.codesAllocated,
    this.result = InviteConsumeStatus.consumed,
    this.code,
    this.creatorSlug,
    this.creatorDisplayName,
  });

  factory InviteConsumeResult.fromJson(Map<String, dynamic> json) {
    return InviteConsumeResult(
      message: json['message'] as String? ?? '',
      codesAllocated:
          (json['codesAllocated'] ?? json['codes_allocated'] ?? 0) as int,
      result: parseInviteConsumeStatus(json['result'] as String?),
      code: json['code'] as String?,
      creatorSlug:
          json['creatorSlug'] as String? ?? json['creator_slug'] as String?,
      creatorDisplayName:
          json['creatorDisplayName'] as String? ??
          json['creator_display_name'] as String?,
    );
  }

  final String message;
  final int codesAllocated;
  final InviteConsumeStatus result;
  final String? code;
  final String? creatorSlug;
  final String? creatorDisplayName;

  bool get isSuccess =>
      result == InviteConsumeStatus.consumed ||
      result == InviteConsumeStatus.alreadyConsumed ||
      result == InviteConsumeStatus.userAlreadyJoined;
}

class InviteAccessGrant {
  const InviteAccessGrant({
    required this.code,
    required this.validatedAt,
    this.creatorSlug,
    this.creatorDisplayName,
    this.remaining,
  });

  final String code;
  final DateTime validatedAt;
  final String? creatorSlug;
  final String? creatorDisplayName;
  final int? remaining;
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

  List<InviteCode> get claimedCodes => codes.where((c) => c.claimed).toList();

  bool get hasUnclaimedCodes => unclaimedCodes.isNotEmpty;

  @override
  List<Object?> get props => [canInvite, remaining, total, codes];
}

class GenerateInviteResult extends Equatable {
  const GenerateInviteResult({required this.code, required this.remaining});

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
