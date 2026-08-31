import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/minor_account_review_status.dart';

void main() {
  group('MinorAccountReviewStatus', () {
    test('parses active status with no case', () {
      final status = MinorAccountReviewStatus.fromJson({
        'restriction': {'status': 'active'},
        'minorReviewCase': null,
      });

      expect(status.restrictionStatus, AccountRestrictionStatus.active);
      expect(status.currentCase, isNull);
      expect(status.isRestricted, isFalse);
    });

    test('parses restricted status with under-13 case', () {
      final status = MinorAccountReviewStatus.fromJson({
        'restriction': {'status': 'restricted_minor_review'},
        'minorReviewCase': {
          'id': 'mar_123',
          'state': 'restricted_pending_support_email',
          'suspectedAgeBand': 'under_13',
          'allowedResolution': 'support_email_only',
          'supportEmail': 'support@divine.video',
          'moderationConversationPubkey': 'abc123',
          'instructions': {
            'title': 'Account review required',
            'body': 'Please have a parent contact support.',
          },
        },
      });

      expect(
        status.restrictionStatus,
        AccountRestrictionStatus.restrictedMinorReview,
      );
      expect(status.isRestricted, isTrue);
      expect(status.currentCase, isNotNull);
      expect(status.currentCase!.id, 'mar_123');
      expect(
        status.currentCase!.state,
        MinorReviewCaseState.restrictedPendingSupportEmail,
      );
      expect(status.currentCase!.suspectedAgeBand, SuspectedAgeBand.under13);
      expect(
        status.currentCase!.allowedResolution,
        MinorReviewResolutionType.supportEmailOnly,
      );
      expect(status.currentCase!.isUnder13Path, isTrue);
    });
  });

  group('responseDeadline', () {
    const serverNow = '2026-08-26T14:30:00.000Z';
    const deadlineAt = '2026-09-10T14:30:00.000Z';

    Map<String, dynamic> caseWith(Map<String, dynamic> deadline) => {
      'id': 'case-1',
      'state': 'restricted_pending_user_response',
      'suspectedAgeBand': 'age_13_15',
      'allowedResolution': 'parent_video_or_email',
      'instructions': <String, dynamic>{},
      'responseDeadline': deadline,
    };

    test('parses running and computes from serverNow', () {
      final reviewCase = MinorReviewCase.fromJson(
        caseWith({
          'clock': 'running',
          'serverNow': serverNow,
          'deadlineAt': deadlineAt,
        }),
      );

      expect(
        reviewCase.responseDeadline.clock,
        MinorReviewResponseClock.running,
      );
      expect(reviewCase.responseDeadline.remaining, const Duration(days: 15));
    });

    test('parses paused, expired, and not applicable states', () {
      final paused = MinorReviewResponseDeadline.fromJson({
        'clock': 'paused',
        'pausedAt': serverNow,
        'remainingDaysWhenPaused': 7.5,
      });
      final expired = MinorReviewResponseDeadline.fromJson({
        'clock': 'expired',
        'serverNow': serverNow,
        'deadlineAt': deadlineAt,
      });
      final notApplicable = MinorReviewResponseDeadline.fromJson({
        'clock': 'not_applicable',
      });

      expect(paused.clock, MinorReviewResponseClock.paused);
      expect(paused.remainingDaysWhenPaused, 7.5);
      expect(expired.clock, MinorReviewResponseClock.expired);
      expect(notApplicable.clock, MinorReviewResponseClock.notApplicable);
    });

    test(
      'downgrades missing, malformed, and negative values to unavailable',
      () {
        final invalid = [
          null,
          {'clock': 'running', 'serverNow': serverNow},
          {
            'clock': 'running',
            'serverNow': 'not-a-date',
            'deadlineAt': deadlineAt,
          },
          {'clock': 'paused', 'remainingDaysWhenPaused': 7.5},
          {
            'clock': 'paused',
            'pausedAt': serverNow,
            'remainingDaysWhenPaused': -1,
          },
          {'clock': 42},
          {
            'clock': 'paused',
            'pausedAt': serverNow,
            'remainingDaysWhenPaused': '7.5',
          },
          {'clock': 'unknown'},
        ];

        for (final json in invalid) {
          expect(
            MinorReviewResponseDeadline.fromJson(json),
            isA<MinorReviewResponseDeadline>().having(
              (value) => value.clock,
              'clock',
              MinorReviewResponseClock.unavailable,
            ),
          );
        }
      },
    );

    test('treats a non-map responseDeadline as unavailable', () {
      final reviewCase = MinorReviewCase.fromJson({
        'id': 'case-1',
        'state': 'restricted_pending_user_response',
        'suspectedAgeBand': 'age_13_15',
        'allowedResolution': 'parent_video_or_email',
        'instructions': <String, dynamic>{},
        'responseDeadline': 'malformed',
      });

      expect(
        reviewCase.responseDeadline.clock,
        MinorReviewResponseClock.unavailable,
      );
    });

    test(
      'clamps a running deadline that has passed without using device time',
      () {
        final deadline = MinorReviewResponseDeadline.fromJson({
          'clock': 'running',
          'serverNow': deadlineAt,
          'deadlineAt': serverNow,
        });

        expect(deadline.remaining, Duration.zero);
      },
    );
  });
}
