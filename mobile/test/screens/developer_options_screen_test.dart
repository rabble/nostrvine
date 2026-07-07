// ABOUTME: Widget tests for DeveloperOptionsScreen layout and debug simulations.
// ABOUTME: Covers settings-menu width and the protected-minor override toggles (#5721).

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/screens/developer_options_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<SharedPreferences> mockPrefs() async {
  SharedPreferences.setMockInitialValues({});
  return SharedPreferences.getInstance();
}

Future<void> pumpScreen(WidgetTester tester, SharedPreferences prefs) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: VineTheme.theme,
        home: const DeveloperOptionsScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> tapTile(WidgetTester tester, String title) async {
  // Tap the whole ListTile (not just the text) and ensure it is fully in view
  // first: scrollUntilVisible can leave the row clipped at a viewport edge, so
  // a tap on the text's centre lands off-target on some layouts (this is what
  // failed on Linux CI but passed on macOS). hitTestWarningShouldBeFatal
  // (set in main) turns any such miss into a hard failure so it can't pass
  // locally again.
  final tile = find.widgetWithText(ListTile, title);
  await tester.scrollUntilVisible(tile, 300);
  await tester.pumpAndSettle();
  await tester.ensureVisible(tile);
  await tester.pumpAndSettle();
  await tester.tap(tile);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'DeveloperOptionsScreen constrains menu content width on wide screens',
    (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(900, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await pumpScreen(tester, await mockPrefs());

      final listViewWidth = tester.getSize(find.byType(ListView).first).width;
      expect(listViewWidth, moreOrLessEquals(600));
    },
  );

  group('protected-minor simulation (#5721)', () {
    late bool previousHitTestWarningShouldBeFatal;

    setUp(() {
      previousHitTestWarningShouldBeFatal =
          WidgetController.hitTestWarningShouldBeFatal;
      // Make a tap that misses its target a hard failure for these tests, so
      // the clipped-tile geometry flake (which passed on macOS and failed on
      // Linux CI) cannot slip through a local run again.
      WidgetController.hitTestWarningShouldBeFatal = true;
    });

    tearDown(() {
      WidgetController.hitTestWarningShouldBeFatal =
          previousHitTestWarningShouldBeFatal;
    });

    testWidgets('simulate protected minor sets the override to true', (
      tester,
    ) async {
      final prefs = await mockPrefs();
      await pumpScreen(tester, prefs);

      await tapTile(tester, 'Simulate protected minor (13-15)');

      expect(
        ProtectedMinorOverrideServiceReader(prefs).value,
        isTrue,
        reason: 'tapping simulate must force the override on',
      );
    });

    testWidgets('simulate non-minor sets the override to false', (
      tester,
    ) async {
      final prefs = await mockPrefs();
      await pumpScreen(tester, prefs);

      await tapTile(tester, 'Simulate non-minor');

      expect(ProtectedMinorOverrideServiceReader(prefs).value, isFalse);
    });

    testWidgets('clear override removes the stored override', (tester) async {
      final prefs = await mockPrefs();
      await prefs.setBool('protected_minor_override', true);
      await pumpScreen(tester, prefs);

      await tapTile(tester, 'Clear override');

      expect(ProtectedMinorOverrideServiceReader(prefs).value, isNull);
    });

    testWidgets('current-state row reflects a forced-protected override', (
      tester,
    ) async {
      final prefs = await mockPrefs();
      await prefs.setBool('protected_minor_override', true);
      await pumpScreen(tester, prefs);

      final stateRow = find.textContaining('Override: forced protected');
      await tester.scrollUntilVisible(stateRow, 300);
      expect(stateRow, findsOneWidget);
    });
  });
}

/// Reads the override the way the service stores it, without reaching into
/// the service's private key from multiple places.
class ProtectedMinorOverrideServiceReader {
  ProtectedMinorOverrideServiceReader(this.prefs);
  final SharedPreferences prefs;
  bool? get value => prefs.getBool('protected_minor_override');
}
