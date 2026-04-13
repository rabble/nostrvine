// ABOUTME: Widget tests for AppLanguageScreen locale picker
// ABOUTME: Verifies all locales render, tap interactions, and radio state

import 'package:bloc_test/bloc_test.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/locale/locale_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/screens/settings/app_language_screen.dart';

class _MockLocaleCubit extends MockCubit<LocaleState> implements LocaleCubit {}

void main() {
  group(AppLanguageScreen, () {
    late _MockLocaleCubit localeCubit;

    setUp(() {
      localeCubit = _MockLocaleCubit();
      when(() => localeCubit.state).thenReturn(const LocaleState());
    });

    Widget buildSubject() {
      return MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: ThemeData(
          scaffoldBackgroundColor: VineTheme.backgroundColor,
        ),
        home: BlocProvider<LocaleCubit>.value(
          value: localeCubit,
          child: const AppLanguageScreen(),
        ),
      );
    }

    testWidgets('renders Device default tile', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.text('Use device language'), findsOneWidget);
    });

    testWidgets('tapping a locale tile calls setLocale with its code', (
      tester,
    ) async {
      when(() => localeCubit.setLocale(any())).thenAnswer((_) async {});

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Español'));
      await tester.pumpAndSettle();

      verify(() => localeCubit.setLocale('es')).called(1);
    });

    testWidgets('tapping Device default tile calls clearLocale', (
      tester,
    ) async {
      when(() => localeCubit.clearLocale()).thenAnswer((_) async {});

      when(() => localeCubit.state).thenReturn(
        const LocaleState(locale: Locale('es')),
      );

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Use device language'));
      await tester.pumpAndSettle();

      verify(() => localeCubit.clearLocale()).called(1);
    });

    testWidgets('shows selected radio for current locale', (tester) async {
      when(() => localeCubit.state).thenReturn(
        const LocaleState(locale: Locale('fr')),
      );

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      final frenchTile = tester.widget<ListTile>(
        find.widgetWithText(ListTile, 'Français'),
      );
      final icon = frenchTile.leading! as Icon;
      expect(icon.icon, equals(Icons.radio_button_checked));
    });

    testWidgets('shows unselected radio for non-current locale', (
      tester,
    ) async {
      when(() => localeCubit.state).thenReturn(
        const LocaleState(locale: Locale('fr')),
      );

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      // Use Deutsch instead of English — English appears twice (device
      // default subtitle + locale list tile), making the finder ambiguous.
      final deutschTile = tester.widget<ListTile>(
        find.widgetWithText(ListTile, 'Deutsch'),
      );
      final icon = deutschTile.leading! as Icon;
      expect(icon.icon, equals(Icons.radio_button_off));
    });

    testWidgets(
      'renders visible locale tiles from supportedLocales',
      (tester) async {
        await tester.pumpWidget(buildSubject());
        await tester.pumpAndSettle();

        // ListView is lazy — only a subset of tiles are built at once.
        // Verify a few visible ones from the top of the list. Full map
        // coverage is asserted in locale_preference_service_test.dart.
        expect(find.text('Deutsch'), findsOneWidget);
        expect(find.text('Español'), findsOneWidget);
        expect(find.text('Français'), findsOneWidget);
      },
    );
  });
}
