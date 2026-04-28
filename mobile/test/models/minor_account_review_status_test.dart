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
}
