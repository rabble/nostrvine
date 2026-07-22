// ABOUTME: Unit tests for the router-refresh gate that keeps a resume/background
// ABOUTME: review-status refetch from tearing down a reel pushed on top mid-init.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/minor_account_review_status.dart';
import 'package:openvine/router/app_router.dart';

void main() {
  group('minorAccountReviewStatusAffectsRouting', () {
    final active = MinorAccountReviewStatus.active();
    const restricted = MinorAccountReviewStatus(
      restrictionStatus: AccountRestrictionStatus.restrictedMinorReview,
    );
    const restrictedWithConversation = MinorAccountReviewStatus(
      restrictionStatus: AccountRestrictionStatus.restrictedMinorReview,
      currentCase: MinorReviewCase(
        id: 'case-1',
        state: MinorReviewCaseState.underModeratorReview,
        suspectedAgeBand: SuspectedAgeBand.unknown,
        allowedResolution: MinorReviewResolutionType.unknown,
        instructions: MinorReviewInstructions(title: '', body: ''),
        supportEmail: 'support@divine.video',
        moderationConversationId: 'conversation-1',
      ),
    );

    test('does not refresh when a refetch resolves to the same status', () {
      // The resume scenario: the provider re-emits a fresh-but-equal active
      // value. The instances differ by identity, so the pre-fix code refreshed;
      // the routing signature is unchanged, so the gate must skip it.
      expect(
        minorAccountReviewStatusAffectsRouting(
          AsyncData(active),
          AsyncData(MinorAccountReviewStatus.active()),
        ),
        isFalse,
      );
    });

    test('refreshes when the restriction decision flips', () {
      expect(
        minorAccountReviewStatusAffectsRouting(
          AsyncData(active),
          const AsyncData(restricted),
        ),
        isTrue,
      );
    });

    test('refreshes when a cold load resolves to a value', () {
      expect(
        minorAccountReviewStatusAffectsRouting(
          const AsyncLoading<MinorAccountReviewStatus>(),
          AsyncData(active),
        ),
        isTrue,
      );
    });

    test('refreshes when a moderation conversation appears on the case', () {
      expect(
        minorAccountReviewStatusAffectsRouting(
          const AsyncData(restricted),
          const AsyncData(restrictedWithConversation),
        ),
        isTrue,
      );
    });

    test('first emission refreshes only when it can gate routing', () {
      // A first unrestricted value needs no refresh — GoRouter evaluates the
      // redirect on the next navigation anyway, and there is nothing to gate.
      expect(
        minorAccountReviewStatusAffectsRouting(null, AsyncData(active)),
        isFalse,
      );
      // A first restricted value, or a first cold-load without a value, must
      // refresh so the gate fires.
      expect(
        minorAccountReviewStatusAffectsRouting(
          null,
          const AsyncData(restricted),
        ),
        isTrue,
      );
      expect(
        minorAccountReviewStatusAffectsRouting(
          null,
          const AsyncLoading<MinorAccountReviewStatus>(),
        ),
        isTrue,
      );
    });
  });
}
