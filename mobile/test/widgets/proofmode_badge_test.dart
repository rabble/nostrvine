// ABOUTME: Tests for ProofMode verification badge widgets
// ABOUTME: Validates badge rendering, colors, and display logic for all verification levels

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/widgets/proofmode_badge.dart';

void main() {
  group('ProofModeBadge Widget', () {
    testWidgets('renders Verified Mobile badge correctly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ProofModeBadge(level: VerificationLevel.verifiedMobile),
          ),
        ),
      );

      // Should display verified icon
      expect(find.byIcon(Icons.verified), findsOneWidget);

      // Should display correct text
      expect(find.text('Human Made'), findsOneWidget);

      // Check the badge container exists
      expect(find.byType(Container), findsWidgets);
    });

    testWidgets('renders Verified Web badge correctly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ProofModeBadge(level: VerificationLevel.verifiedWeb),
          ),
        ),
      );

      // Should display verified outlined icon (silver tier)
      expect(find.byIcon(Icons.verified_outlined), findsOneWidget);

      // Should display correct text
      expect(find.text('Human Made'), findsOneWidget);
    });

    testWidgets('renders Basic Proof badge correctly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ProofModeBadge(level: VerificationLevel.basicProof),
          ),
        ),
      );

      // Should display verified outlined icon (bronze tier)
      expect(find.byIcon(Icons.verified_outlined), findsOneWidget);

      // Should display correct text
      expect(find.text('Human Made'), findsOneWidget);
    });

    testWidgets('renders Unverified badge correctly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ProofModeBadge(level: VerificationLevel.unverified),
          ),
        ),
      );

      // Should display shield icon
      expect(find.byIcon(Icons.shield_outlined), findsOneWidget);

      // Should display correct text
      expect(find.text('Unverified'), findsOneWidget);
    });

    testWidgets('renders different badge sizes correctly', (tester) async {
      // Test small size
      await tester.pumpWidget(
        const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ProofModeBadge(level: VerificationLevel.verifiedMobile),
          ),
        ),
      );

      var badge = tester.widget<ProofModeBadge>(find.byType(ProofModeBadge));
      expect(badge.size, BadgeSize.small);

      // Test medium size
      await tester.pumpWidget(
        const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ProofModeBadge(
              level: VerificationLevel.verifiedMobile,
              size: BadgeSize.medium,
            ),
          ),
        ),
      );

      badge = tester.widget<ProofModeBadge>(find.byType(ProofModeBadge));
      expect(badge.size, BadgeSize.medium);

      // Test large size
      await tester.pumpWidget(
        const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ProofModeBadge(
              level: VerificationLevel.verifiedMobile,
              size: BadgeSize.large,
            ),
          ),
        ),
      );

      badge = tester.widget<ProofModeBadge>(find.byType(ProofModeBadge));
      expect(badge.size, BadgeSize.large);
    });

    testWidgets('badge has proper visual structure', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ProofModeBadge(level: VerificationLevel.verifiedMobile),
          ),
        ),
      );

      // Should have Container for styling
      expect(find.byType(Container), findsWidgets);

      // Should have Row for icon + text layout
      expect(find.byType(Row), findsOneWidget);

      // Should have Icon and Text widgets
      expect(find.byType(Icon), findsOneWidget);
      expect(find.byType(Text), findsOneWidget);
    });

    testWidgets(
      'human made badge keeps a neutral shell and uses tier color on the icon',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: ProofModeBadge(level: VerificationLevel.verifiedMobile),
            ),
          ),
        );

        final container = tester.widget<Container>(
          find
              .descendant(
                of: find.byType(ProofModeBadge),
                matching: find.byType(Container),
              )
              .first,
        );
        final decoration = container.decoration! as BoxDecoration;
        final border = decoration.border! as Border;
        final icon = tester.widget<Icon>(find.byType(Icon));
        final text = tester.widget<Text>(find.text('Human Made'));

        expect(decoration.color, const Color(0xFF161A1D));
        expect(border.top.color, const Color(0xFF434A52));
        expect(icon.color, const Color(0xFFFFD700));
        expect(text.style?.color, const Color(0xFFF5F7FA));
      },
    );

    testWidgets('human made tiers share the same badge shell', (tester) async {
      Future<BoxDecoration> pumpAndGetDecoration(
        VerificationLevel level,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: ProofModeBadge(level: level)),
          ),
        );

        final container = tester.widget<Container>(
          find
              .descendant(
                of: find.byType(ProofModeBadge),
                matching: find.byType(Container),
              )
              .first,
        );

        return container.decoration! as BoxDecoration;
      }

      final mobileDecoration = await pumpAndGetDecoration(
        VerificationLevel.verifiedMobile,
      );
      final webDecoration = await pumpAndGetDecoration(
        VerificationLevel.verifiedWeb,
      );
      final basicDecoration = await pumpAndGetDecoration(
        VerificationLevel.basicProof,
      );

      expect(webDecoration.color, mobileDecoration.color);
      expect(
        (webDecoration.border! as Border).top.color,
        (mobileDecoration.border! as Border).top.color,
      );
      expect(basicDecoration.color, mobileDecoration.color);
      expect(
        (basicDecoration.border! as Border).top.color,
        (mobileDecoration.border! as Border).top.color,
      );
    });
  });

  group('OriginalVineBadge Widget', () {
    testWidgets('renders Original Vine badge correctly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: OriginalVineBadge()),
        ),
      );

      // Should display 'V' text
      expect(find.text('V'), findsOneWidget);

      // Should display 'Original' text
      expect(find.text('Original'), findsOneWidget);

      // Check the badge container exists
      expect(find.byType(Container), findsWidgets);
    });

    testWidgets('renders different Vine badge sizes correctly', (tester) async {
      // Test small size
      await tester.pumpWidget(
        const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: OriginalVineBadge()),
        ),
      );

      var badge = tester.widget<OriginalVineBadge>(
        find.byType(OriginalVineBadge),
      );
      expect(badge.size, BadgeSize.small);

      // Test medium size
      await tester.pumpWidget(
        const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: OriginalVineBadge(size: BadgeSize.medium)),
        ),
      );

      badge = tester.widget<OriginalVineBadge>(find.byType(OriginalVineBadge));
      expect(badge.size, BadgeSize.medium);

      // Test large size
      await tester.pumpWidget(
        const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: OriginalVineBadge(size: BadgeSize.large)),
        ),
      );

      badge = tester.widget<OriginalVineBadge>(find.byType(OriginalVineBadge));
      expect(badge.size, BadgeSize.large);
    });

    testWidgets('Vine badge has proper visual structure', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: OriginalVineBadge()),
        ),
      );

      // Should have Container for styling
      expect(find.byType(Container), findsWidgets);

      // Should have Row for V + text layout
      expect(find.byType(Row), findsOneWidget);

      // Should have two Text widgets (V and Original Vine)
      expect(find.byType(Text), findsNWidgets(2));
    });

    testWidgets('Vine badge has teal background color', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: OriginalVineBadge()),
        ),
      );

      final container = tester.widget<Container>(
        find
            .descendant(
              of: find.byType(OriginalVineBadge),
              matching: find.byType(Container),
            )
            .first,
      );

      final decoration = container.decoration! as BoxDecoration;
      expect(decoration.color, const Color(0xFF00BF8F)); // Vine teal
    });
  });

  group('Badge Enum Values', () {
    test('VerificationLevel has all expected values', () {
      expect(VerificationLevel.values, hasLength(5));
      expect(VerificationLevel.values, contains(VerificationLevel.platinum));
      expect(
        VerificationLevel.values,
        contains(VerificationLevel.verifiedMobile),
      );
      expect(VerificationLevel.values, contains(VerificationLevel.verifiedWeb));
      expect(VerificationLevel.values, contains(VerificationLevel.basicProof));
      expect(VerificationLevel.values, contains(VerificationLevel.unverified));
    });

    test('BadgeSize has all expected values', () {
      expect(BadgeSize.values, hasLength(3));
      expect(BadgeSize.values, contains(BadgeSize.small));
      expect(BadgeSize.values, contains(BadgeSize.medium));
      expect(BadgeSize.values, contains(BadgeSize.large));
    });
  });
}
