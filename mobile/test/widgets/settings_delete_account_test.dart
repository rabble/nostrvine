// ABOUTME: Tests for the Delete Account entry on the Settings hub
// ABOUTME: Verifies it appears only when authenticated and reads copy from l10n

import 'package:bloc_test/bloc_test.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/locale/locale_cubit.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/screens/settings/settings_screen.dart';
import 'package:openvine/services/account_deletion_service.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockAccountDeletionService extends Mock
    implements AccountDeletionService {}

class _MockAuthService extends Mock implements AuthService {}

class _MockLocaleCubit extends MockCubit<LocaleState> implements LocaleCubit {}

void main() {
  group('SettingsScreen - Delete Account', () {
    late _MockAccountDeletionService mockDeletionService;
    late _MockAuthService mockAuthService;
    late _MockLocaleCubit mockLocaleCubit;
    late SharedPreferences sharedPreferences;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      sharedPreferences = await SharedPreferences.getInstance();
      mockDeletionService = _MockAccountDeletionService();
      mockAuthService = _MockAuthService();
      mockLocaleCubit = _MockLocaleCubit();
      when(() => mockLocaleCubit.state).thenReturn(const LocaleState());
      when(() => mockAuthService.isAnonymous).thenReturn(false);
      when(() => mockAuthService.hasExpiredOAuthSession).thenReturn(false);
      when(() => mockAuthService.currentProfile).thenReturn(null);
    });

    Future<void> pumpSettings(
      WidgetTester tester, {
      required AuthState authState,
    }) async {
      when(
        () => mockAuthService.isAuthenticated,
      ).thenReturn(authState == AuthState.authenticated);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(sharedPreferences),
            accountDeletionServiceProvider.overrideWithValue(
              mockDeletionService,
            ),
            authServiceProvider.overrideWithValue(mockAuthService),
            currentAuthStateProvider.overrideWithValue(authState),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: BlocProvider<LocaleCubit>.value(
              value: mockLocaleCubit,
              child: const SettingsScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    /// Drags to the end of the settings list.
    ///
    /// The entry sits at the bottom, and a `ListView` only builds its visible
    /// range — so without this, `findsNothing` would pass for a tile that is
    /// merely off-screen and the absence test could never fail.
    Future<void> scrollToEnd(WidgetTester tester) async {
      for (var i = 0; i < 8; i++) {
        await tester.drag(find.byType(ListView), const Offset(0, -600));
        await tester.pumpAndSettle();
      }
    }

    // Deletion used to be reachable only from Settings -> "Nostr Settings" ->
    // Danger Zone, a developer-facing name a user has no reason to open. #6335
    // was filed by someone who could not find it.
    testWidgets('offers deletion when authenticated', (tester) async {
      await pumpSettings(tester, authState: AuthState.authenticated);
      await scrollToEnd(tester);

      final l10n = lookupAppLocalizations(const Locale('en'));
      expect(find.text(l10n.nostrSettingsDeleteAccount), findsOneWidget);
      expect(
        find.text(l10n.nostrSettingsDeleteAccountSubtitle),
        findsOneWidget,
      );

      // Proves the tile reads from l10n rather than a hardcoded English
      // string: the same key in another locale must not be on screen.
      expect(
        find.text(
          lookupAppLocalizations(
            const Locale('de'),
          ).nostrSettingsDeleteAccount,
        ),
        findsNothing,
      );

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets('hides deletion when signed out', (tester) async {
      await pumpSettings(tester, authState: AuthState.unauthenticated);
      await scrollToEnd(tester);

      final l10n = lookupAppLocalizations(const Locale('en'));
      expect(find.text(l10n.nostrSettingsDeleteAccount), findsNothing);

      // Dispose and pump to clear any pending timers from overlay visibility
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    // Destructive entries read in the error colour, matching the Danger Zone
    // tile this one mirrors.
    testWidgets('renders the entry as destructive', (tester) async {
      await pumpSettings(tester, authState: AuthState.authenticated);
      await scrollToEnd(tester);

      final l10n = lookupAppLocalizations(const Locale('en'));
      final tile = find.ancestor(
        of: find.text(l10n.nostrSettingsDeleteAccount),
        matching: find.byType(ListTile),
      );
      expect(tile, findsOneWidget);

      final listTile = tester.widget<ListTile>(tile);
      expect((listTile.title! as Text).style?.color, VineTheme.error);
      expect((listTile.leading! as DivineIcon).color, VineTheme.error);
      expect((listTile.leading! as DivineIcon).icon, DivineIconName.trash);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });
  });
}
