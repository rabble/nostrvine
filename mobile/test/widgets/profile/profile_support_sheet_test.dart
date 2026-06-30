import 'package:analytics/analytics.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:openvine/features/monetization/monetization_storefront_policy.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/widgets/profile/profile_support_sheet.dart';

void main() {
  tearDown(() {
    debugUsesAppleAppStoreTipPolicyOverride = null;
  });

  testWidgets('uses tip-only copy and links on iOS storefronts', (
    tester,
  ) async {
    debugUsesAppleAppStoreTipPolicyOverride = true;

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: VineTheme.theme,
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return TextButton(
                onPressed: () => showProfileSupportSheet(
                  context: context,
                  links: [
                    const MonetizationLink(
                      provider: MonetizationLinkProvider.cashApp,
                      category: MonetizationLinkCategory.tip,
                      url: r'https://cash.app/$creator',
                      enabled: true,
                    ),
                    const MonetizationLink(
                      provider: MonetizationLinkProvider.patreon,
                      category: MonetizationLinkCategory.subscription,
                      url: 'https://www.patreon.com/creator',
                      enabled: true,
                    ),
                  ],
                  analytics: const NoOpAnalyticsEventSink(),
                ),
                child: const Text('Open'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Tip this creator'), findsOneWidget);
    expect(
      find.text(
        'Tips open outside Divine. They are optional and do not unlock content, subscriptions, features, or access in Divine.',
      ),
      findsOneWidget,
    );
    expect(find.text('Cash App'), findsOneWidget);
    expect(find.text('Patreon'), findsNothing);
    expect(find.text('Subscribe / support'), findsNothing);
  });
}
