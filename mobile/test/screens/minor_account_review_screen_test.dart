import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/models/minor_account_review_status.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/screens/minor_account_review_parent_consent_screen.dart';
import 'package:openvine/screens/minor_account_review_screen.dart';
import 'package:openvine/screens/minor_account_review_under13_screen.dart';

void main() {
  group('MinorAccountReviewScreen', () {
    testWidgets('shows the original welcome-entry family guidance copy', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: MinorAccountReviewScreen(
            entryPoint: MinorAccountReviewEntryPoint.welcome,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Family guide'), findsOneWidget);
      expect(find.text("Not 16 yet? That's OK."), findsOneWidget);
    });

    testWidgets('welcome-entry back button pops to the previous screen', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const MinorAccountReviewScreen(
                          entryPoint: MinorAccountReviewEntryPoint.welcome,
                        ),
                      ),
                    );
                  },
                  child: const Text('Open family guide'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open family guide'));
      await tester.pumpAndSettle();

      expect(find.text('Family guide'), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(find.text('Open family guide'), findsOneWidget);
      expect(find.text('Family guide'), findsNothing);
    });

    testWidgets('shows the public under-13 support screen copy', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ProviderScope(child: MinorAccountReviewUnder13Screen()),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Under-13 accounts'), findsOneWidget);
      expect(find.text('Email Divine support'), findsAtLeastNWidgets(1));
      expect(
        find.text('What the parent or guardian should include'),
        findsOneWidget,
      );
    });

    testWidgets('shows the public parent-consent screen copy', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ProviderScope(child: MinorAccountReviewParentConsentScreen()),
        ),
      );

      await tester.pumpAndSettle();

      expect(
        find.text('If the account belongs to someone 13 to 15'),
        findsOneWidget,
      );
      expect(find.text('What to include'), findsOneWidget);
      expect(find.text('What happens next'), findsOneWidget);
      expect(
        find.text('Email Divine support', skipOffstage: false),
        findsOneWidget,
      );
    });

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
                  supportEmail: 'contact@divine.video',
                ),
              );
            }),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: MinorAccountReviewScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Account review required'), findsOneWidget);
      expect(find.text('Next step'), findsOneWidget);
      expect(find.text('Continue', skipOffstage: false), findsOneWidget);
    });

    testWidgets(
      'shows review in progress without primary CTA after submission',
      (tester) async {
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
                    supportEmail: 'contact@divine.video',
                  ),
                );
              }),
            ],
            child: const MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: MinorAccountReviewScreen(),
            ),
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
      },
    );
  });
}
