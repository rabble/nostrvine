// ABOUTME: Widget test for settings hub screen
// ABOUTME: Verifies account header, auth-state tiles, and navigation structure

import 'package:bloc_test/bloc_test.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/invite_status/invite_status_cubit.dart';
import 'package:openvine/blocs/locale/locale_cubit.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/models/invite_models.dart';
import 'package:openvine/models/known_account.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/screens/apps/apps_directory_screen.dart';
import 'package:openvine/screens/apps/apps_permissions_screen.dart';
import 'package:openvine/screens/badges/badges_screen.dart';
import 'package:openvine/screens/settings/settings_screen.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/draft_storage_service.dart';
import 'package:openvine/widgets/user_avatar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/go_router.dart';

class _MockAuthService extends Mock implements AuthService {}

class _MockDraftStorageService extends Mock implements DraftStorageService {}

class _MockInviteStatusCubit extends MockCubit<InviteStatusState>
    implements InviteStatusCubit {}

class _MockLocaleCubit extends MockCubit<LocaleState> implements LocaleCubit {}

_MockInviteStatusCubit _createMockInviteCubit() {
  final cubit = _MockInviteStatusCubit();
  when(() => cubit.state).thenReturn(const InviteStatusState());
  when(cubit.load).thenAnswer((_) async {});
  return cubit;
}

void main() {
  group(SettingsScreen, () {
    late _MockAuthService mockAuthService;
    late _MockDraftStorageService mockDraftStorageService;
    late _MockLocaleCubit mockLocaleCubit;
    late SharedPreferences sharedPreferences;
    final l10n = lookupAppLocalizations(const Locale('en'));
    final twoAccounts = [
      KnownAccount(
        pubkeyHex:
            'abc123pubkeyabc123pubkeyabc123pubkeyabc123pubkeyabc123pubkeyabc1',
        authSource: AuthenticationSource.automatic,
        addedAt: DateTime(2024),
        lastUsedAt: DateTime(2024),
      ),
      KnownAccount(
        pubkeyHex:
            'def456pubkeydef456pubkeydef456pubkeydef456pubkeydef456pubkeydef4',
        authSource: AuthenticationSource.automatic,
        addedAt: DateTime(2024),
        lastUsedAt: DateTime(2024),
      ),
    ];

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      sharedPreferences = await SharedPreferences.getInstance();
      mockAuthService = _MockAuthService();
      mockDraftStorageService = _MockDraftStorageService();
      mockLocaleCubit = _MockLocaleCubit();
      when(() => mockLocaleCubit.state).thenReturn(const LocaleState());

      when(() => mockAuthService.isAuthenticated).thenReturn(true);
      when(() => mockAuthService.isAnonymous).thenReturn(false);
      when(
        () => mockAuthService.currentPublicKeyHex,
      ).thenReturn('abc123pubkey');
      when(() => mockAuthService.authState).thenReturn(AuthState.authenticated);
      when(
        () => mockAuthService.authStateStream,
      ).thenAnswer((_) => Stream.value(AuthState.authenticated));
      when(() => mockAuthService.hasExpiredOAuthSession).thenReturn(false);
      when(
        () => mockAuthService.getKnownAccounts(),
      ).thenAnswer((_) async => []);
      when(
        () => mockDraftStorageService.getDraftCount(),
      ).thenAnswer((_) async => 0);
    });

    Widget buildSubject({
      AuthState authState = AuthState.authenticated,
      MockGoRouter? goRouter,
      List<KnownAccount> knownAccounts = const [],
      _MockInviteStatusCubit? inviteCubit,
    }) {
      when(
        () => mockAuthService.getKnownAccounts(),
      ).thenAnswer((_) async => knownAccounts);

      final mockInviteCubit = inviteCubit ?? _createMockInviteCubit();

      final app = ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(sharedPreferences),
          authServiceProvider.overrideWithValue(mockAuthService),
          draftStorageServiceProvider.overrideWithValue(
            mockDraftStorageService,
          ),
          currentAuthStateProvider.overrideWith((ref) => authState),
          knownAccountsProvider.overrideWith((ref) async => knownAccounts),
          userProfileReactiveProvider.overrideWith(
            (ref, pubkey) => Stream.value(null),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: MultiBlocProvider(
            providers: [
              BlocProvider<InviteStatusCubit>.value(value: mockInviteCubit),
              BlocProvider<LocaleCubit>.value(value: mockLocaleCubit),
            ],
            child: const SettingsScreen(),
          ),
        ),
      );

      if (goRouter == null) {
        return app;
      }

      return MockGoRouterProvider(goRouter: goRouter, child: app);
    }

    testWidgets('renders app bar with title', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.text('Settings'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets('scaffold has navGreen background', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, equals(VineTheme.navGreen));

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets('renders centered account header when authenticated', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.byType(UserAvatar), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets('loads invite status so profile can show invite access', (
      tester,
    ) async {
      final mockInviteCubit = _createMockInviteCubit();

      await tester.pumpWidget(buildSubject(inviteCubit: mockInviteCubit));
      await tester.pumpAndSettle();

      verify(mockInviteCubit.load).called(1);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets('renders invite shortcut when unclaimed invites exist', (
      tester,
    ) async {
      final mockInviteCubit = _MockInviteStatusCubit();
      when(mockInviteCubit.load).thenAnswer((_) async {});
      when(() => mockInviteCubit.state).thenReturn(
        const InviteStatusState(
          status: InviteStatusLoadingStatus.loaded,
          inviteStatus: InviteStatus(
            canInvite: true,
            remaining: 0,
            total: 1,
            codes: [InviteCode(code: 'AB23-EF7K', claimed: false)],
          ),
        ),
      );

      await tester.pumpWidget(buildSubject(inviteCubit: mockInviteCubit));
      await tester.pumpAndSettle();

      expect(find.text('Invites'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets('renders invite shortcut when invite capacity exists', (
      tester,
    ) async {
      final mockInviteCubit = _MockInviteStatusCubit();
      when(mockInviteCubit.load).thenAnswer((_) async {});
      when(() => mockInviteCubit.state).thenReturn(
        const InviteStatusState(
          status: InviteStatusLoadingStatus.loaded,
          inviteStatus: InviteStatus(
            canInvite: true,
            remaining: 5,
            total: 5,
            codes: [],
          ),
        ),
      );

      await tester.pumpWidget(buildSubject(inviteCubit: mockInviteCubit));
      await tester.pumpAndSettle();

      expect(find.text('Invites'), findsOneWidget);
      expect(find.text('5'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets(
      'hides account action when multiple accounts exist and switching is disabled',
      (tester) async {
        await tester.pumpWidget(buildSubject(knownAccounts: twoAccounts));
        await tester.pumpAndSettle();

        expect(find.text('Switch account'), findsNothing);
        expect(find.text('Add another account'), findsNothing);

        await tester.pumpWidget(const SizedBox());
        await tester.pump();
      },
    );

    testWidgets('renders Switch account button when multiple accounts exist', (
      tester,
    ) async {
      await sharedPreferences.setBool('ff_accountSwitching', true);

      await tester.pumpWidget(buildSubject(knownAccounts: twoAccounts));
      await tester.pumpAndSettle();

      expect(find.text('Switch account'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets('renders navigation tiles', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      final scrollable = find.byType(Scrollable);

      expect(find.text('Creator Analytics'), findsOneWidget);
      expect(find.text('Support Center'), findsOneWidget);

      // Tiles below the centered header may need scrolling
      for (final title in [
        l10n.settingsNotifications,
        l10n.settingsGeneralTitle,
        l10n.settingsContentSafetyTitle,
        l10n.settingsNostrSettings,
      ]) {
        await tester.scrollUntilVisible(
          find.text(title),
          100,
          scrollable: scrollable,
        );
        expect(find.text(title), findsOneWidget);
      }

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets('tapping Integration Permissions opens the permissions route', (
      tester,
    ) async {
      final mockGoRouter = MockGoRouter();
      when(() => mockGoRouter.push(any())).thenAnswer((_) async => null);

      await tester.pumpWidget(buildSubject(goRouter: mockGoRouter));
      await tester.pumpAndSettle();

      final scrollable = find.byType(Scrollable);
      await tester.scrollUntilVisible(
        find.text('Integration Permissions'),
        300,
        scrollable: scrollable,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Integration Permissions'));
      await tester.pumpAndSettle();

      verify(() => mockGoRouter.push(AppsPermissionsScreen.path)).called(1);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets('tapping Integrated Apps opens the directory route', (
      tester,
    ) async {
      final mockGoRouter = MockGoRouter();
      when(() => mockGoRouter.push(any())).thenAnswer((_) async => null);

      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(sharedPreferences),
          authServiceProvider.overrideWithValue(mockAuthService),
          draftStorageServiceProvider.overrideWithValue(
            mockDraftStorageService,
          ),
          currentAuthStateProvider.overrideWith(
            (ref) => AuthState.authenticated,
          ),
          userProfileReactiveProvider.overrideWith(
            (ref, pubkey) => Stream.value(null),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MockGoRouterProvider(
            goRouter: mockGoRouter,
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: MultiBlocProvider(
                providers: [
                  BlocProvider<InviteStatusCubit>.value(
                    value: _createMockInviteCubit(),
                  ),
                  BlocProvider<LocaleCubit>.value(value: mockLocaleCubit),
                ],
                child: const SettingsScreen(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final scrollable = find.byType(Scrollable);
      await tester.scrollUntilVisible(
        find.text(l10n.settingsIntegratedApps),
        200,
        scrollable: scrollable,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.settingsIntegratedApps));
      await tester.pumpAndSettle();

      verify(() => mockGoRouter.push(AppsDirectoryScreen.path)).called(1);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets('tapping Badges opens the badges dashboard', (tester) async {
      final mockGoRouter = MockGoRouter();
      when(() => mockGoRouter.push(any())).thenAnswer((_) async => null);

      await tester.pumpWidget(buildSubject(goRouter: mockGoRouter));
      await tester.pumpAndSettle();

      final scrollable = find.byType(Scrollable);
      await tester.scrollUntilVisible(
        find.text(l10n.settingsBadgesTitle),
        200,
        scrollable: scrollable,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.settingsBadgesTitle));
      await tester.pumpAndSettle();

      verify(() => mockGoRouter.push(BadgesScreen.path)).called(1);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets('renders Secure Your Account tile for anonymous users', (
      tester,
    ) async {
      when(() => mockAuthService.isAnonymous).thenReturn(true);

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.text('Secure Your Account'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets('renders Session Expired tile when session expired', (
      tester,
    ) async {
      when(() => mockAuthService.hasExpiredOAuthSession).thenReturn(true);

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.text('Session Expired'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets(
      'shows secure account tile instead of session expired for anonymous '
      'users',
      (tester) async {
        when(() => mockAuthService.isAnonymous).thenReturn(true);
        when(() => mockAuthService.hasExpiredOAuthSession).thenReturn(true);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sharedPreferencesProvider.overrideWithValue(sharedPreferences),
              authServiceProvider.overrideWithValue(mockAuthService),
              draftStorageServiceProvider.overrideWithValue(
                mockDraftStorageService,
              ),
              currentAuthStateProvider.overrideWithValue(
                AuthState.authenticated,
              ),
            ],
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: MultiBlocProvider(
                providers: [
                  BlocProvider<InviteStatusCubit>.value(
                    value: _createMockInviteCubit(),
                  ),
                  BlocProvider<LocaleCubit>.value(value: mockLocaleCubit),
                ],
                child: const SettingsScreen(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Secure Your Account'), findsOneWidget);
        expect(find.text('Session Expired'), findsNothing);

        await tester.pumpWidget(const SizedBox());
        await tester.pump();
      },
    );

    testWidgets('hides Secure Your Account for non-anonymous users', (
      tester,
    ) async {
      when(() => mockAuthService.isAnonymous).thenReturn(false);

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.text('Secure Your Account'), findsNothing);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets('does not render account section when unauthenticated', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildSubject(authState: AuthState.unauthenticated),
      );
      await tester.pumpAndSettle();

      expect(find.byType(UserAvatar), findsNothing);
      expect(find.text('Switch account'), findsNothing);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets('hides Bluesky Publishing tile when feature flag is off', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.text('Bluesky Publishing'), findsNothing);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets(
      'keeps Bluesky Publishing off the hub when feature flag is on',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sharedPreferencesProvider.overrideWithValue(sharedPreferences),
              authServiceProvider.overrideWithValue(mockAuthService),
              draftStorageServiceProvider.overrideWithValue(
                mockDraftStorageService,
              ),
              currentAuthStateProvider.overrideWith(
                (ref) => AuthState.authenticated,
              ),
              userProfileReactiveProvider.overrideWith(
                (ref, pubkey) => Stream.value(null),
              ),
              isFeatureEnabledProvider(
                FeatureFlag.blueskyPublishing,
              ).overrideWith((ref) => true),
            ],
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: MultiBlocProvider(
                providers: [
                  BlocProvider<InviteStatusCubit>.value(
                    value: _createMockInviteCubit(),
                  ),
                  BlocProvider<LocaleCubit>.value(value: mockLocaleCubit),
                ],
                child: const SettingsScreen(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text(l10n.settingsGeneralTitle), findsOneWidget);
        expect(find.text('Bluesky Publishing'), findsNothing);

        await tester.pumpWidget(const SizedBox());
        await tester.pump();
      },
    );
  });
}
