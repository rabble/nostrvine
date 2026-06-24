import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/screens/minor_account_review_parent_consent_screen.dart';

void main() {
  group('MinorAccountReviewParentConsentScreen', () {
    testWidgets('opens support email with prepared subject and body', (
      tester,
    ) async {
      final l10n = lookupAppLocalizations(const Locale('en'));
      String? sentToEmail;
      String? sentSubject;
      String? sentBody;

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: MinorAccountReviewParentConsentScreen(
            composeEmail:
                ({
                  required String toEmail,
                  required String subject,
                  required String body,
                }) async {
                  sentToEmail = toEmail;
                  sentSubject = subject;
                  sentBody = body;
                },
          ),
        ),
      );

      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text(l10n.minorAccountReviewParentConsentEmailCta),
        200,
        scrollable: find.byType(Scrollable),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.minorAccountReviewParentConsentEmailCta));
      await tester.pumpAndSettle();

      expect(sentToEmail, 'support@divine.video');
      expect(sentSubject, l10n.minorAccountReviewParentConsentEmailSubject);
      expect(sentBody, l10n.minorAccountReviewParentConsentEmailBody);
      expect(sentSubject, contains('Divine Greenlight'));
      expect(sentBody, contains('Divine Greenlight'));
    });
  });
}
