// ABOUTME: Server-backed restriction and case models for parental consent /
// ABOUTME: minor-account review. Used by router gating and restricted UX.

import 'package:openvine/constants/app_constants.dart';

enum AccountRestrictionStatus {
  active,
  restrictedMinorReview
  ;

  static AccountRestrictionStatus fromJsonValue(String? value) {
    return switch (value) {
      'restricted_minor_review' => restrictedMinorReview,
      _ => active,
    };
  }
}

enum MinorReviewCaseState {
  openReported,
  underModeratorReview,
  restrictedPendingUserResponse,
  restrictedPendingParentalConsent,
  restrictedPendingSupportEmail,
  submittedForReview,
  needsFollowUp,
  cleared,
  deniedClosed,
  unknown
  ;

  static MinorReviewCaseState fromJsonValue(String? value) {
    return switch (value) {
      'open_reported' => openReported,
      'under_moderator_review' => underModeratorReview,
      'restricted_pending_user_response' => restrictedPendingUserResponse,
      'restricted_pending_parental_consent' => restrictedPendingParentalConsent,
      'restricted_pending_support_email' => restrictedPendingSupportEmail,
      'submitted_for_review' => submittedForReview,
      'needs_follow_up' => needsFollowUp,
      'cleared' => cleared,
      'denied_closed' => deniedClosed,
      _ => unknown,
    };
  }
}

enum SuspectedAgeBand {
  under13,
  age13To15,
  age16PlusClaimed,
  unknown
  ;

  static SuspectedAgeBand fromJsonValue(String? value) {
    return switch (value) {
      'under_13' => under13,
      'age_13_15' => age13To15,
      'age_16_plus_claimed' => age16PlusClaimed,
      _ => unknown,
    };
  }
}

enum MinorReviewResolutionType {
  supportEmailOnly,
  parentVideoOrEmail,
  supportReviewOnly,
  unknown
  ;

  static MinorReviewResolutionType fromJsonValue(String? value) {
    return switch (value) {
      'support_email_only' => supportEmailOnly,
      'parent_video_or_email' => parentVideoOrEmail,
      'support_review_only' => supportReviewOnly,
      _ => unknown,
    };
  }
}

class MinorReviewInstructions {
  const MinorReviewInstructions({required this.title, required this.body});

  factory MinorReviewInstructions.fromJson(Map<String, dynamic>? json) {
    return MinorReviewInstructions(
      title: json?['title'] as String? ?? '',
      body: json?['body'] as String? ?? '',
    );
  }

  final String title;
  final String body;

  MinorReviewInstructions copyWith({String? title, String? body}) {
    return MinorReviewInstructions(
      title: title ?? this.title,
      body: body ?? this.body,
    );
  }
}

class MinorReviewCase {
  const MinorReviewCase({
    required this.id,
    required this.state,
    required this.suspectedAgeBand,
    required this.allowedResolution,
    required this.instructions,
    required this.supportEmail,
    this.moderationConversationPubkey,
    this.moderationConversationId,
  });

  factory MinorReviewCase.fromJson(Map<String, dynamic> json) {
    return MinorReviewCase(
      id: json['id'] as String? ?? '',
      state: MinorReviewCaseState.fromJsonValue(json['state'] as String?),
      suspectedAgeBand: SuspectedAgeBand.fromJsonValue(
        json['suspectedAgeBand'] as String?,
      ),
      allowedResolution: MinorReviewResolutionType.fromJsonValue(
        json['allowedResolution'] as String?,
      ),
      instructions: MinorReviewInstructions.fromJson(
        json['instructions'] as Map<String, dynamic>?,
      ),
      supportEmail:
          json['supportEmail'] as String? ?? AppConstants.supportEmail,
      moderationConversationPubkey:
          json['moderationConversationPubkey'] as String?,
      moderationConversationId: json['moderationConversationId'] as String?,
    );
  }

  final String id;
  final MinorReviewCaseState state;
  final SuspectedAgeBand suspectedAgeBand;
  final MinorReviewResolutionType allowedResolution;
  final MinorReviewInstructions instructions;
  final String supportEmail;
  final String? moderationConversationPubkey;
  final String? moderationConversationId;

  bool get isUnder13Path =>
      suspectedAgeBand == SuspectedAgeBand.under13 ||
      allowedResolution == MinorReviewResolutionType.supportEmailOnly;

  bool get allowsParentVideoOrEmail =>
      allowedResolution == MinorReviewResolutionType.parentVideoOrEmail &&
      !isUnder13Path;

  bool get isAwaitingModeratorDecision =>
      state == MinorReviewCaseState.underModeratorReview ||
      state == MinorReviewCaseState.submittedForReview;

  bool get needsUserAction =>
      state == MinorReviewCaseState.restrictedPendingUserResponse ||
      state == MinorReviewCaseState.restrictedPendingParentalConsent ||
      state == MinorReviewCaseState.restrictedPendingSupportEmail ||
      state == MinorReviewCaseState.needsFollowUp;

  MinorReviewCase copyWith({
    String? id,
    MinorReviewCaseState? state,
    SuspectedAgeBand? suspectedAgeBand,
    MinorReviewResolutionType? allowedResolution,
    MinorReviewInstructions? instructions,
    String? supportEmail,
    String? moderationConversationPubkey,
    String? moderationConversationId,
  }) {
    return MinorReviewCase(
      id: id ?? this.id,
      state: state ?? this.state,
      suspectedAgeBand: suspectedAgeBand ?? this.suspectedAgeBand,
      allowedResolution: allowedResolution ?? this.allowedResolution,
      instructions: instructions ?? this.instructions,
      supportEmail: supportEmail ?? this.supportEmail,
      moderationConversationPubkey:
          moderationConversationPubkey ?? this.moderationConversationPubkey,
      moderationConversationId:
          moderationConversationId ?? this.moderationConversationId,
    );
  }
}

class MinorAccountReviewStatus {
  const MinorAccountReviewStatus({
    required this.restrictionStatus,
    this.currentCase,
  });

  factory MinorAccountReviewStatus.active() {
    return const MinorAccountReviewStatus(
      restrictionStatus: AccountRestrictionStatus.active,
    );
  }

  factory MinorAccountReviewStatus.fromJson(Map<String, dynamic> json) {
    final restriction =
        json['restriction'] as Map<String, dynamic>? ?? const {};
    final currentCaseJson = json['minorReviewCase'] as Map<String, dynamic>?;

    return MinorAccountReviewStatus(
      restrictionStatus: AccountRestrictionStatus.fromJsonValue(
        restriction['status'] as String?,
      ),
      currentCase: currentCaseJson == null
          ? null
          : MinorReviewCase.fromJson(currentCaseJson),
    );
  }

  final AccountRestrictionStatus restrictionStatus;
  final MinorReviewCase? currentCase;

  bool get isRestricted =>
      restrictionStatus == AccountRestrictionStatus.restrictedMinorReview;

  MinorAccountReviewStatus copyWith({
    AccountRestrictionStatus? restrictionStatus,
    MinorReviewCase? currentCase,
  }) {
    return MinorAccountReviewStatus(
      restrictionStatus: restrictionStatus ?? this.restrictionStatus,
      currentCase: currentCase ?? this.currentCase,
    );
  }
}
