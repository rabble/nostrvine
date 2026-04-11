import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/l10n/l10n.dart';

void main() {
  group('AppLocalizations', () {
    testWidgets('provides English localizations by default', (tester) async {
      late AppLocalizations l10n;

      await tester.pumpWidget(
        MaterialApp(
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

    testWidgets('falls back to English for missing translations', (
      tester,
    ) async {
      late AppLocalizations l10n;

      // Arabic is a partial translation (~34% coverage). Any key not in
      // app_ar.arb falls back through the l10n chain to English.
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('ar'),
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

      // Arabic has settingsTitle translated.
      expect(l10n.settingsTitle, equals('الإعدادات'));
      // shareMenuOriginalSound is not in the ar ARB, so it falls back to
      // English.
      expect(l10n.shareMenuOriginalSound, equals('Original sound'));
    });

    testWidgets('parameterized string works for version', (tester) async {
      late AppLocalizations l10n;

      await tester.pumpWidget(
        MaterialApp(
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

      expect(l10n.settingsVersion('1.0.0+42'), equals('Version 1.0.0+42'));
    });

    testWidgets('plural string works for drafts message', (tester) async {
      late AppLocalizations l10n;

      await tester.pumpWidget(
        MaterialApp(
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
          home: Builder(
            builder: (context) {
              l10n = context.l10n;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(
        l10n.contentPreferencesDoneCount(2),
        equals('Done (2 selected)'),
      );
    });
  });
}
