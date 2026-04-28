// ABOUTME: Widget tests for DeveloperOptionsScreen layout.
// ABOUTME: Verifies settings-menu width stays aligned with other settings screens.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/screens/developer_options_screen.dart';

void main() {
  testWidgets(
    'DeveloperOptionsScreen constrains menu content width on wide screens',
    (
      tester,
    ) async {
      tester.view.physicalSize = const Size(900, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: VineTheme.theme,
            home: const DeveloperOptionsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final listViewWidth = tester.getSize(find.byType(ListView).first).width;
      expect(listViewWidth, moreOrLessEquals(600));
    },
  );
}
