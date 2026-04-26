import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/l10n/resolve_app_ui_locale.dart';

void main() {
  group('AppLocalizations', () {
    testWidgets('provides English localizations by default', (tester) async {
      late AppLocalizations l10n;

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          localeListResolutionCallback: resolveAppUiLocale,
          home: Builder(
            builder: (context) {
              l10n = context.l10n;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(l10n.appTitle, equals('Divine'));
      expect(l10n.settingsTitle, equals('Settings'));
    });

    testWidgets('supports Spanish locale', (tester) async {
      late AppLocalizations l10n;

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('es'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) {
              l10n = context.l10n;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(l10n.settingsTitle, equals('Ajustes'));
    });

    testWidgets('falls back to English for unsupported locale', (tester) async {
      late AppLocalizations l10n;

      // Chinese is not a supported locale. We force the resolution
      // callback to return English, verifying the app gracefully
      // falls back to the English ARB strings.
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          localeListResolutionCallback: resolveAppUiLocale,
          home: Builder(
            builder: (context) {
              l10n = context.l10n;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(l10n.settingsTitle, equals('Settings'));
    });

    testWidgets('parameterized string works for version', (tester) async {
      late AppLocalizations l10n;

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          localeListResolutionCallback: resolveAppUiLocale,
          home: Builder(
            builder: (context) {
              l10n = context.l10n;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(l10n.settingsVersion('1.0.0+42'), equals('Version 1.0.0+42'));
    });

    testWidgets('plural string works for drafts message', (tester) async {
      late AppLocalizations l10n;

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          localeListResolutionCallback: resolveAppUiLocale,
          home: Builder(
            builder: (context) {
              l10n = context.l10n;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      final singleDraft = l10n.settingsUnsavedDraftsMessage(1);
      expect(singleDraft, contains('1 unsaved draft'));
      expect(singleDraft, contains('it'));

      final multipleDrafts = l10n.settingsUnsavedDraftsMessage(3);
      expect(multipleDrafts, contains('3 unsaved drafts'));
      expect(multipleDrafts, contains('them'));
    });

    testWidgets('plural string works for developer mode taps remaining', (
      tester,
    ) async {
      late AppLocalizations l10n;

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          localeListResolutionCallback: resolveAppUiLocale,
          home: Builder(
            builder: (context) {
              l10n = context.l10n;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(
        l10n.settingsDeveloperModeTapsRemaining(3),
        equals('3 more taps to enable developer mode'),
      );
    });

    testWidgets('plural string works for done count', (tester) async {
      late AppLocalizations l10n;

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          localeListResolutionCallback: resolveAppUiLocale,
          home: Builder(
            builder: (context) {
              l10n = context.l10n;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(l10n.contentPreferencesDoneCount(2), equals('Done (2 selected)'));
    });
  });
}
