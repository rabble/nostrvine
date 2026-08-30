import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/minor_account_review_status.dart';
import 'package:openvine/services/minor_account_review_override_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('MinorAccountReviewOverrideService', () {
    late SharedPreferences prefs;
    late MinorAccountReviewOverrideService service;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      service = MinorAccountReviewOverrideService(prefs: prefs);
    });

    test('returns null when no override exists', () {
      expect(service.getOverride(), isNull);
    });

    test('stores and reloads a restricted override', () async {
      const status = MinorAccountReviewStatus(
        restrictionStatus: AccountRestrictionStatus.restrictedMinorReview,
        currentCase: MinorReviewCase(
          id: 'sim-teen-review',
          state: MinorReviewCaseState.restrictedPendingUserResponse,
          suspectedAgeBand: SuspectedAgeBand.age13To15,
          allowedResolution: MinorReviewResolutionType.parentVideoOrEmail,
          instructions: MinorReviewInstructions(
            title: 'Account review required',
            body: 'Parental consent is required.',
          ),
          supportEmail: 'support@divine.video',
          moderationConversationPubkey: 'abc123',
        ),
      );

      await service.setOverride(status);
      final loaded = service.getOverride();

      expect(loaded, isNotNull);
      expect(loaded!.isRestricted, isTrue);
      expect(loaded.currentCase!.id, 'sim-teen-review');
      expect(
        loaded.currentCase!.allowedResolution,
        MinorReviewResolutionType.parentVideoOrEmail,
      );
    });

    test('clears an existing override', () async {
      await service.setOverride(
        const MinorAccountReviewStatus(
          restrictionStatus: AccountRestrictionStatus.restrictedMinorReview,
          currentCase: MinorReviewCase(
            id: 'sim-under13-review',
            state: MinorReviewCaseState.restrictedPendingSupportEmail,
            suspectedAgeBand: SuspectedAgeBand.under13,
            allowedResolution: MinorReviewResolutionType.supportEmailOnly,
            instructions: MinorReviewInstructions(
              title: 'Parent support required',
              body: 'A parent must contact support.',
            ),
            supportEmail: 'support@divine.video',
          ),
        ),
      );

      await service.clearOverride();

      expect(service.getOverride(), isNull);
    });

    test('round-trips each response clock state', () async {
      final deadlines = [
        MinorReviewResponseDeadline(
          clock: MinorReviewResponseClock.running,
          serverNow: DateTime.utc(2026, 8, 26),
          deadlineAt: DateTime.utc(2026, 9, 10),
        ),
        MinorReviewResponseDeadline(
          clock: MinorReviewResponseClock.paused,
          pausedAt: DateTime.utc(2026, 8, 26),
          remainingDaysWhenPaused: 7.5,
        ),
        MinorReviewResponseDeadline(
          clock: MinorReviewResponseClock.expired,
          serverNow: DateTime.utc(2026, 9, 11),
          deadlineAt: DateTime.utc(2026, 9, 10),
        ),
        const MinorReviewResponseDeadline(
          clock: MinorReviewResponseClock.notApplicable,
        ),
        const MinorReviewResponseDeadline.unavailable(),
      ];

      for (final deadline in deadlines) {
        await service.setOverride(
          MinorAccountReviewStatus(
            restrictionStatus: AccountRestrictionStatus.restrictedMinorReview,
            currentCase: MinorReviewCase(
              id: 'clock-case',
              state: MinorReviewCaseState.restrictedPendingUserResponse,
              suspectedAgeBand: SuspectedAgeBand.age13To15,
              allowedResolution: MinorReviewResolutionType.parentVideoOrEmail,
              instructions: const MinorReviewInstructions(title: '', body: ''),
              supportEmail: 'support@divine.video',
              responseDeadline: deadline,
            ),
          ),
        );

        expect(
          service.getOverride()!.currentCase!.responseDeadline.clock,
          deadline.clock,
        );
      }
    });
  });
}
