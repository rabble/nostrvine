import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/minor_account_review_status.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/screens/minor_account_review_screen.dart';

void main() {
  group('MinorAccountReviewScreen', () {
    testWidgets('shows next step CTA for 13-15 cases', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentMinorAccountReviewStatusProvider.overrideWith((ref) async {
              return const MinorAccountReviewStatus(
                restrictionStatus:
                    AccountRestrictionStatus.restrictedMinorReview,
                currentCase: MinorReviewCase(
                  id: 'case-teen',
                  state: MinorReviewCaseState.restrictedPendingUserResponse,
                  suspectedAgeBand: SuspectedAgeBand.age13To15,
                  allowedResolution:
                      MinorReviewResolutionType.parentVideoOrEmail,
                  instructions: MinorReviewInstructions(
                    title: 'Account review required',
                    body: 'We need parental consent information.',
                  ),
                  supportEmail: 'support@divine.video',
                ),
              );
            }),
          ],
          child: const MaterialApp(home: MinorAccountReviewScreen()),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Account review required'), findsOneWidget);
      expect(find.text('Next step'), findsOneWidget);
      expect(find.text('Continue', skipOffstage: false), findsOneWidget);
    });

    testWidgets('shows review in progress without primary CTA after submission', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentMinorAccountReviewStatusProvider.overrideWith((ref) async {
              return const MinorAccountReviewStatus(
                restrictionStatus:
                    AccountRestrictionStatus.restrictedMinorReview,
                currentCase: MinorReviewCase(
                  id: 'case-reviewing',
                  state: MinorReviewCaseState.submittedForReview,
                  suspectedAgeBand: SuspectedAgeBand.age13To15,
                  allowedResolution:
                      MinorReviewResolutionType.parentVideoOrEmail,
                  instructions: MinorReviewInstructions(
                    title: 'Submission received',
                    body: 'We are reviewing this case.',
                  ),
                  supportEmail: 'support@divine.video',
                ),
              );
            }),
          ],
          child: const MaterialApp(home: MinorAccountReviewScreen()),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Review in progress'), findsOneWidget);
      expect(find.text('Continue', skipOffstage: false), findsNothing);
      expect(
        find.text('Parent Support Instructions', skipOffstage: false),
        findsNothing,
      );
      expect(find.text('Open Support Center'), findsOneWidget);
    });
  });
}
