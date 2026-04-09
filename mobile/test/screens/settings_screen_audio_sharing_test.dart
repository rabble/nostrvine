// ABOUTME: Tests for audio sharing preference toggle in content preferences
// ABOUTME: Verifies toggle displays and persists user preference

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/screens/settings/content_preferences_screen.dart';
import 'package:openvine/services/account_label_service.dart';
import 'package:openvine/services/audio_sharing_preference_service.dart';
import 'package:openvine/services/language_preference_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockAudioSharingPreferenceService extends Mock
    implements AudioSharingPreferenceService {}

class _MockLanguagePreferenceService extends Mock
    implements LanguagePreferenceService {}

class _MockAccountLabelService extends Mock implements AccountLabelService {}

void main() {
  group('ContentPreferencesScreen Audio Sharing Toggle', () {
    late _MockAudioSharingPreferenceService mockAudioSharingService;
    late _MockLanguagePreferenceService mockLanguageService;
    late _MockAccountLabelService mockAccountLabelService;
    late SharedPreferences sharedPreferences;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      sharedPreferences = await SharedPreferences.getInstance();
      mockAudioSharingService = _MockAudioSharingPreferenceService();
      mockLanguageService = _MockLanguagePreferenceService();
      mockAccountLabelService = _MockAccountLabelService();

      when(
        () => mockAudioSharingService.isAudioSharingEnabled,
      ).thenReturn(false);
      when(() => mockLanguageService.contentLanguage).thenReturn('en');
      when(() => mockLanguageService.isCustomLanguageSet).thenReturn(false);
      when(
        () => mockAccountLabelService.accountLabels,
      ).thenReturn({});
      when(
        () => mockAccountLabelService.initialized,
      ).thenAnswer((_) async {});
    });

    Widget createTestWidget() {
      return ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(sharedPreferences),
          audioSharingPreferenceServiceProvider.overrideWithValue(
            mockAudioSharingService,
          ),
          languagePreferenceServiceProvider.overrideWithValue(
            mockLanguageService,
          ),
          accountLabelServiceProvider.overrideWithValue(
            mockAccountLabelService,
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: VineTheme.theme,
          home: const ContentPreferencesScreen(),
        ),
      );
    }

    testWidgets('displays audio sharing toggle', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Make my audio available for reuse'), findsOneWidget);
      expect(
        find.text('When enabled, others can use audio from your videos'),
        findsOneWidget,
      );

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets('toggle shows correct initial state (OFF)', (tester) async {
      when(
        () => mockAudioSharingService.isAudioSharingEnabled,
      ).thenReturn(false);

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      final switchFinder = find.byWidgetPredicate(
        (widget) =>
            widget is SwitchListTile &&
            widget.title is Text &&
            (widget.title! as Text).data ==
                'Make my audio available for reuse' &&
            !widget.value,
      );
      expect(switchFinder, findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets('toggle shows correct initial state (ON)', (tester) async {
      when(
        () => mockAudioSharingService.isAudioSharingEnabled,
      ).thenReturn(true);

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      final switchFinder = find.byWidgetPredicate(
        (widget) =>
            widget is SwitchListTile &&
            widget.title is Text &&
            (widget.title! as Text).data ==
                'Make my audio available for reuse' &&
            widget.value,
      );
      expect(switchFinder, findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets('tapping toggle calls setAudioSharingEnabled', (
      tester,
    ) async {
      when(
        () => mockAudioSharingService.isAudioSharingEnabled,
      ).thenReturn(false);
      when(
        () => mockAudioSharingService.setAudioSharingEnabled(any()),
      ).thenAnswer((_) async {});

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      final switchFinder = find.byWidgetPredicate(
        (widget) =>
            widget is SwitchListTile &&
            widget.title is Text &&
            (widget.title! as Text).data == 'Make my audio available for reuse',
      );

      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      verify(
        () => mockAudioSharingService.setAudioSharingEnabled(true),
      ).called(1);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets('uses correct VineTheme colors', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      final switchFinder = find.byWidgetPredicate(
        (widget) =>
            widget is SwitchListTile &&
            widget.title is Text &&
            (widget.title! as Text).data ==
                'Make my audio available for reuse' &&
            widget.activeThumbColor == VineTheme.vineGreen,
      );
      expect(switchFinder, findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });
  });
}
