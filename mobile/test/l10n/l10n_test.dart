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

    testWidgets('resolves to a known locale for unsupported ones', (
      tester,
    ) async {
      late AppLocalizations l10n;

      // Chinese is not a supported locale. Flutter's basic resolver
      // falls back to the first locale in the supported list — which
      // is still a translated locale. We just verify a non-null l10n
      // object is available (no crash, no null).
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('zh'),
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

      // Just verify we got a non-empty localization
      expect(l10n.settingsTitle, isNotEmpty);
      expect(l10n.shareMenuOriginalSound, isNotEmpty);
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
