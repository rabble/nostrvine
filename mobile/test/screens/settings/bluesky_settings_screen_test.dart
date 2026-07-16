import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/crosspost_settings/crosspost_settings_cubit.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/screens/settings/bluesky_settings_screen.dart';
import 'package:openvine/screens/settings/nip05_settings_screen.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/crosspost_api_client.dart';

class _MockCrosspostSettingsCubit extends MockCubit<CrosspostSettingsState>
    implements CrosspostSettingsCubit {}

class _MockAuthService extends Mock implements AuthService {}

class _MockCrosspostApiClient extends Mock implements CrosspostApiClient {}

void main() {
  group('BlueskySettingsScreen view', () {
    late _MockCrosspostSettingsCubit cubit;

    setUp(() {
      cubit = _MockCrosspostSettingsCubit();
    });

    Widget buildSubject() {
      return MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: ThemeData.dark(),
        home: BlocProvider<CrosspostSettingsCubit>.value(
          value: cubit,
          child: Scaffold(
            body: BlocConsumer<CrosspostSettingsCubit, CrosspostSettingsState>(
              listener: (context, state) {
                if (state.status == CrosspostSettingsStatus.failure) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Failed to update crosspost setting'),
                    ),
                  );
                }
              },
              builder: (context, state) {
                if (state.status == CrosspostSettingsStatus.loading) {
                  return const Center(child: CircularProgressIndicator());
                }
                return ListView(
                  children: [
                    SwitchListTile(
                      secondary: const Icon(Icons.cloud_upload),
                      title: const Text('Publish videos to Bluesky'),
                      subtitle: Text(
                        state.enabled
                            ? 'Your videos will be published to Bluesky'
                            : 'Your videos will not be published to Bluesky',
                      ),
                      value: state.enabled,
                      onChanged:
                          state.status == CrosspostSettingsStatus.toggling
                          ? null
                          : (value) => context
                                .read<CrosspostSettingsCubit>()
                                .toggleCrosspost(enabled: value),
                    ),
                    if (state.handle != null)
                      ListTile(
                        title: const Text('Bluesky Handle'),
                        subtitle: Text(state.handle!),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      );
    }

    testWidgets('renders loading indicator when status is loading', (
      tester,
    ) async {
      when(() => cubit.state).thenReturn(
        const CrosspostSettingsState(status: CrosspostSettingsStatus.loading),
      );

      await tester.pumpWidget(buildSubject());

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('renders toggle when loaded', (tester) async {
      when(() => cubit.state).thenReturn(
        const CrosspostSettingsState(
          status: CrosspostSettingsStatus.loaded,
          enabled: true,
          handle: 'testuser.divine.video',
          provisioningState: 'ready',
        ),
      );

      await tester.pumpWidget(buildSubject());

      expect(find.byType(SwitchListTile), findsOneWidget);
      expect(find.text('Publish videos to Bluesky'), findsOneWidget);
      expect(
        find.text('Your videos will be published to Bluesky'),
        findsOneWidget,
      );
    });

    testWidgets('renders handle when present', (tester) async {
      when(() => cubit.state).thenReturn(
        const CrosspostSettingsState(
          status: CrosspostSettingsStatus.loaded,
          enabled: true,
          handle: 'testuser.divine.video',
        ),
      );

      await tester.pumpWidget(buildSubject());

      expect(find.text('testuser.divine.video'), findsOneWidget);
    });

    testWidgets('calls toggleCrosspost when switch is tapped', (tester) async {
      when(() => cubit.state).thenReturn(
        const CrosspostSettingsState(
          status: CrosspostSettingsStatus.loaded,
          enabled: true,
          handle: 'testuser.divine.video',
        ),
      );
      when(
        () => cubit.toggleCrosspost(enabled: false),
      ).thenAnswer((_) async {});

      await tester.pumpWidget(buildSubject());
      await tester.tap(find.byType(Switch));
      await tester.pump();

      verify(() => cubit.toggleCrosspost(enabled: false)).called(1);
    });

    testWidgets('shows disabled subtitle when crosspost is off', (
      tester,
    ) async {
      when(() => cubit.state).thenReturn(
        const CrosspostSettingsState(status: CrosspostSettingsStatus.loaded),
      );

      await tester.pumpWidget(buildSubject());

      expect(
        find.text('Your videos will not be published to Bluesky'),
        findsOneWidget,
      );
    });

    testWidgets('shows snackbar on failure', (tester) async {
      whenListen(
        cubit,
        Stream.fromIterable(const [
          CrosspostSettingsState(
            status: CrosspostSettingsStatus.failure,
            enabled: true,
          ),
        ]),
        initialState: const CrosspostSettingsState(
          status: CrosspostSettingsStatus.loaded,
          enabled: true,
        ),
      );

      await tester.pumpWidget(buildSubject());
      await tester.pump();

      expect(find.text('Failed to update crosspost setting'), findsOneWidget);
    });
  });

  group('BlueskySettingsScreen (real widget)', () {
    late _MockAuthService authService;
    late _MockCrosspostApiClient apiClient;

    const claimRouteMarker = 'NIP05 CLAIM ROUTE';

    setUp(() {
      authService = _MockAuthService();
      apiClient = _MockCrosspostApiClient();
      when(() => authService.currentPublicKeyHex).thenReturn('pubkeyhex');
    });

    Widget buildApp() {
      final router = GoRouter(
        initialLocation: BlueskySettingsScreen.path,
        routes: [
          GoRoute(
            path: BlueskySettingsScreen.path,
            builder: (_, _) => const BlueskySettingsScreen(),
          ),
          GoRoute(
            path: Nip05SettingsScreen.path,
            builder: (_, _) => const Scaffold(body: Text(claimRouteMarker)),
          ),
        ],
      );

      return ProviderScope(
        overrides: [
          authServiceProvider.overrideWithValue(authService),
          crosspostApiClientProvider.overrideWithValue(apiClient),
        ],
        child: MaterialApp.router(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: ThemeData.dark(),
          routerConfig: router,
        ),
      );
    }

    testWidgets('shows the claim notice when no username is claimed', (
      tester,
    ) async {
      when(() => apiClient.getStatus()).thenAnswer(
        (_) async => const CrosspostStatus(crosspostEnabled: false),
      );

      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      expect(
        find.text('Set up a divine.video handle before publishing to Bluesky'),
        findsOneWidget,
      );
    });

    testWidgets('hides the claim notice once a username is claimed', (
      tester,
    ) async {
      when(() => apiClient.getStatus()).thenAnswer(
        (_) async => const CrosspostStatus(
          crosspostEnabled: false,
          username: 'testuser',
          handle: 'testuser.divine.video',
          provisioningState: 'pending',
        ),
      );

      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      expect(
        find.text('Set up a divine.video handle before publishing to Bluesky'),
        findsNothing,
      );
    });

    testWidgets('claim notice Set up button routes to the nip05 screen', (
      tester,
    ) async {
      when(() => apiClient.getStatus()).thenAnswer(
        (_) async => const CrosspostStatus(crosspostEnabled: false),
      );

      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(TextButton, 'Set up'));
      await tester.pumpAndSettle();

      expect(find.text(claimRouteMarker), findsOneWidget);
    });

    testWidgets(
      'enabling without a username surfaces a snackbar that routes to claim',
      (tester) async {
        when(() => apiClient.getStatus()).thenAnswer(
          (_) async => const CrosspostStatus(crosspostEnabled: false),
        );

        await tester.pumpWidget(buildApp());
        await tester.pumpAndSettle();

        await tester.tap(find.byType(Switch));
        await tester.pumpAndSettle();

        // The toggle short-circuits (no API call) and offers a claim action.
        verifyNever(
          () => apiClient.setCrosspost(
            pubkey: any(named: 'pubkey'),
            enabled: any(named: 'enabled'),
          ),
        );
        expect(find.byType(SnackBarAction), findsOneWidget);

        await tester.tap(find.text('Set up').last);
        await tester.pumpAndSettle();

        expect(find.text(claimRouteMarker), findsOneWidget);
      },
    );
  });
}
