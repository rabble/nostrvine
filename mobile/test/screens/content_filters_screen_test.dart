// ABOUTME: Widget tests for ContentFiltersScreen — verifies the loaded
// ABOUTME: category controls, the age-gate banner, and that tapping a segment
// ABOUTME: persists the preference through ContentFilterService.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/models/content_label.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/screens/content_filters_screen.dart';
import 'package:openvine/services/age_verification_service.dart';
import 'package:openvine/services/content_filter_service.dart';

import '../helpers/test_provider_overrides.dart';

class _MockContentFilterService extends Mock implements ContentFilterService {}

class _MockAgeVerificationService extends Mock
    implements AgeVerificationService {}

void main() {
  setUpAll(() {
    registerFallbackValue(ContentLabel.nudity);
    registerFallbackValue(ContentFilterPreference.show);
  });

  group(ContentFiltersScreen, () {
    late _MockContentFilterService filterService;
    late _MockAgeVerificationService ageService;

    setUp(() {
      filterService = _MockContentFilterService();
      ageService = _MockAgeVerificationService();
      when(filterService.initialize).thenAnswer((_) async {});
      when(
        () => filterService.getPreference(any()),
      ).thenReturn(ContentFilterPreference.show);
      when(
        () => filterService.setPreference(any(), any()),
      ).thenAnswer((_) async {});
      when(ageService.initialize).thenAnswer((_) async {});
      when(() => ageService.isAdultContentVerified).thenReturn(false);
    });

    Widget buildSubject() => testMaterialApp(
      additionalOverrides: [
        contentFilterServiceProvider.overrideWithValue(filterService),
        ageVerificationServiceProvider.overrideWithValue(ageService),
      ],
      home: const ContentFiltersScreen(),
    );

    AppLocalizations l10nOf(WidgetTester tester) =>
        AppLocalizations.of(tester.element(find.byType(ContentFiltersScreen)));

    testWidgets('renders the category groups once loaded', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      final l10n = l10nOf(tester);
      expect(find.text(l10n.contentFiltersAdultContent), findsOneWidget);
      expect(find.text(l10n.contentFiltersViolenceGore), findsOneWidget);
      expect(find.text(l10n.contentFiltersSubstances), findsOneWidget);
    });

    testWidgets('renders the full supported Other label set', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      final l10n = l10nOf(tester);
      await tester.scrollUntilVisible(
        find.text(l10n.contentLabelDeepfake),
        200,
      );
      await tester.pumpAndSettle();
      expect(find.text(l10n.contentLabelDeepfake), findsOneWidget);
      expect(find.text(l10n.contentLabelSpam), findsOneWidget);
      expect(find.text(l10n.contentLabelScam), findsOneWidget);
    });

    testWidgets('shows the age-gate banner when not verified', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(
        find.text(l10nOf(tester).contentFiltersAgeGateMessage),
        findsOneWidget,
      );
    });

    testWidgets('hides the age-gate banner when verified', (tester) async {
      when(() => ageService.isAdultContentVerified).thenReturn(true);

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(
        find.text(l10nOf(tester).contentFiltersAgeGateMessage),
        findsNothing,
      );
    });

    testWidgets('tapping a segment persists the preference via the service', (
      tester,
    ) async {
      when(() => ageService.isAdultContentVerified).thenReturn(true);

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      await tester.tap(find.text(l10nOf(tester).contentFiltersWarn).first);
      await tester.pump();

      verify(
        () => filterService.setPreference(any(), ContentFilterPreference.warn),
      ).called(1);
    });
  });
}
