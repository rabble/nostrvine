import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/features/appearance/bloc/appearance_cubit.dart';
import 'package:openvine/features/appearance/models/appearance_mode.dart';
import 'package:openvine/features/appearance/repositories/appearance_repository.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/screens/settings/appearance_settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/accessibility_guidelines.dart';

void main() {
  testWidgets('renders appearance modes and persists a selected mode', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final cubit = AppearanceCubit(AppearanceRepository(preferences));
    addTearDown(cubit.close);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: VineTheme.theme,
        home: BlocProvider.value(
          value: cubit,
          child: const AppearanceSettingsScreen(),
        ),
      ),
    );

    expect(find.text('Appearance'), findsOneWidget);
    expect(find.text('System default'), findsOneWidget);
    expect(find.text('Light'), findsOneWidget);
    expect(find.text('Dark'), findsOneWidget);

    await tester.tap(find.text('Light'));
    await tester.pump();

    expect(cubit.state, AppearanceMode.light);
    expect(
      await AppearanceRepository(preferences).load(),
      AppearanceMode.light,
    );
  });

  testWidgets('renders with a MaterialApp theme that has no Vine extension', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final cubit = AppearanceCubit(
      AppearanceRepository(await SharedPreferences.getInstance()),
    );
    addTearDown(cubit.close);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BlocProvider.value(
          value: cubit,
          child: const AppearanceSettingsScreen(),
        ),
      ),
    );

    expect(find.text('Appearance'), findsOneWidget);
  });

  testWidgets('meets the accessibility guidelines in both appearances', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final cubit = AppearanceCubit(
      AppearanceRepository(await SharedPreferences.getInstance()),
    );
    addTearDown(cubit.close);

    await expectMeetsAccessibilityGuidelinesInBothAppearances(
      tester,
      (theme) => MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: theme,
        home: BlocProvider.value(
          value: cubit,
          child: const AppearanceSettingsScreen(),
        ),
      ),
    );
  });
}
