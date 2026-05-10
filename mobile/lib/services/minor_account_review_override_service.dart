// ABOUTME: Developer-only local override service for simulating parental
// ABOUTME: consent / minor-account review states without backend wiring.

import 'dart:convert';

import 'package:openvine/models/minor_account_review_status.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MinorAccountReviewOverrideService {
  MinorAccountReviewOverrideService({
    required SharedPreferences prefs,
  }) : _prefs = prefs;

  static const _prefsKey = 'minor_account_review_override';

  final SharedPreferences _prefs;

  MinorAccountReviewStatus? getOverride() {
    final raw = _prefs.getString(_prefsKey);
    if (raw == null || raw.isEmpty) return null;

    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return MinorAccountReviewStatus.fromJson(decoded);
    } catch (_) {
      return null;
    }
  }

  Future<void> setOverride(MinorAccountReviewStatus status) async {
    final payload = <String, dynamic>{
      'restriction': {
        'status': status.restrictionStatus == AccountRestrictionStatus.active
            ? 'active'
            : 'restricted_minor_review',
      },
      'minorReviewCase': status.currentCase == null
          ? null
          : <String, dynamic>{
              'id': status.currentCase!.id,
              'state': switch (status.currentCase!.state) {
                MinorReviewCaseState.openReported => 'open_reported',
                MinorReviewCaseState.underModeratorReview =>
                  'under_moderator_review',
                MinorReviewCaseState.restrictedPendingUserResponse =>
                  'restricted_pending_user_response',
                MinorReviewCaseState.restrictedPendingParentalConsent =>
                  'restricted_pending_parental_consent',
                MinorReviewCaseState.restrictedPendingSupportEmail =>
                  'restricted_pending_support_email',
                MinorReviewCaseState.submittedForReview =>
                  'submitted_for_review',
                MinorReviewCaseState.needsFollowUp => 'needs_follow_up',
                MinorReviewCaseState.cleared => 'cleared',
                MinorReviewCaseState.deniedClosed => 'denied_closed',
                MinorReviewCaseState.unknown => 'unknown',
              },
              'suspectedAgeBand':
                  switch (status.currentCase!.suspectedAgeBand) {
                    SuspectedAgeBand.under13 => 'under_13',
                    SuspectedAgeBand.age13To15 => 'age_13_15',
                    SuspectedAgeBand.age16PlusClaimed => 'age_16_plus_claimed',
                    SuspectedAgeBand.unknown => 'unknown',
                  },
              'allowedResolution':
                  switch (status.currentCase!.allowedResolution) {
                    MinorReviewResolutionType.supportEmailOnly =>
                      'support_email_only',
                    MinorReviewResolutionType.parentVideoOrEmail =>
                      'parent_video_or_email',
                    MinorReviewResolutionType.supportReviewOnly =>
                      'support_review_only',
                    MinorReviewResolutionType.unknown => 'unknown',
                  },
              'instructions': {
                'title': status.currentCase!.instructions.title,
                'body': status.currentCase!.instructions.body,
              },
              'supportEmail': status.currentCase!.supportEmail,
              'moderationConversationPubkey':
                  status.currentCase!.moderationConversationPubkey,
              'moderationConversationId':
                  status.currentCase!.moderationConversationId,
            },
    };

    await _prefs.setString(_prefsKey, jsonEncode(payload));
  }

  Future<void> clearOverride() async {
    await _prefs.remove(_prefsKey);
  }
}
