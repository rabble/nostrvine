import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/screens/minor_account_review_parent_consent_screen.dart';

void main() {
  group('MinorAccountReviewParentConsentScreen', () {
    testWidgets('opens support email with prepared subject and body', (
      tester,
    ) async {
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
        find.text('Email Divine support'),
        200,
        scrollable: find.byType(Scrollable),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Email Divine support'));
      await tester.pumpAndSettle();

      expect(sentToEmail, 'support@divine.video');
      expect(sentSubject, '13-15 account review help');
      expect(sentBody, contains('I have attached a short private video'));
      expect(sentBody, contains('Country/ies of residence:'));
    });
  });
}
