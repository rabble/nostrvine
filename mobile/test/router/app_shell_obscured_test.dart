// ABOUTME: Verifies AppShell drives shellObscuredProvider via RouteAware.
// ABOUTME: A route directly above the shell flips it; nested routes do not.

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/app_update/app_update.dart';
import 'package:openvine/blocs/dm/unread_count/dm_unread_count_cubit.dart';
import 'package:openvine/blocs/notifications/badge/notification_badge_cubit.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/models/environment_config.dart';
import 'package:openvine/providers/active_video_provider.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/environment_provider.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/providers/shell_obscured_provider.dart';
import 'package:openvine/router/router.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockAuthService extends Mock implements AuthService {}

class _MockDmUnreadCountCubit extends MockCubit<int>
    implements DmUnreadCountCubit {}

class _MockNotificationBadgeCubit extends MockCubit<int>
    implements NotificationBadgeCubit {}

class _MockAppUpdateBloc extends MockBloc<AppUpdateEvent, AppUpdateState>
    implements AppUpdateBloc {}

Widget _buildSubject({
  required _MockAuthService mockAuthService,
  required SharedPreferences sharedPreferences,
}) {
  final dmCubit = _MockDmUnreadCountCubit();
  when(() => dmCubit.state).thenReturn(0);

  final notifBadgeCubit = _MockNotificationBadgeCubit();
  when(() => notifBadgeCubit.state).thenReturn(0);

  final appUpdateBloc = _MockAppUpdateBloc();
  when(() => appUpdateBloc.state).thenReturn(const AppUpdateState());

  return MultiBlocProvider(
    providers: [
      BlocProvider<DmUnreadCountCubit>.value(value: dmCubit),
      BlocProvider<NotificationBadgeCubit>.value(value: notifBadgeCubit),
      BlocProvider<AppUpdateBloc>.value(value: appUpdateBloc),
    ],
    child: ProviderScope(
      overrides: [
        pageContextProvider.overrideWith(
          (ref) => Stream.value(const RouteContext(type: RouteType.home)),
        ),
        videoControllerAutoCleanupProvider.overrideWithValue(null),
        relayStatisticsBridgeProvider.overrideWithValue(null),
        relaySetChangeBridgeProvider.overrideWithValue(null),
        zendeskIdentitySyncProvider.overrideWithValue(null),
        pushNotificationSyncProvider.overrideWithValue(null),
        blocklistSyncBridgeProvider.overrideWithValue(null),
        authServiceProvider.overrideWithValue(mockAuthService),
        sharedPreferencesProvider.overrideWithValue(sharedPreferences),
        currentEnvironmentProvider.overrideWithValue(
          EnvironmentConfig.production,
        ),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        // The shell subscribes to this observer to learn when a full-screen
        // route covers it.
        navigatorObservers: [routeObserver],
        home: const AppShell(currentIndex: 0, child: SizedBox.shrink()),
      ),
    ),
  );
}

void main() {
  late _MockAuthService mockAuthService;
  late SharedPreferences sharedPreferences;

  setUp(() async {
    mockAuthService = _MockAuthService();
    when(() => mockAuthService.currentPublicKeyHex).thenReturn(null);
    when(() => mockAuthService.currentNpub).thenReturn(null);
    when(() => mockAuthService.isAuthenticated).thenReturn(false);
    when(() => mockAuthService.authState).thenReturn(AuthState.unauthenticated);

    SharedPreferences.setMockInitialValues(<String, Object>{});
    sharedPreferences = await SharedPreferences.getInstance();
  });

  testWidgets(
    'shellObscuredProvider only flips for the route directly above the '
    'shell',
    (tester) async {
      await tester.pumpWidget(
        _buildSubject(
          mockAuthService: mockAuthService,
          sharedPreferences: sharedPreferences,
        ),
      );
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(AppShell)),
      );
      final navigator = Navigator.of(tester.element(find.byType(AppShell)));

      // Nothing pushed yet.
      expect(container.read(shellObscuredProvider), isFalse);

      // Push a profile over the shell → obscured.
      unawaited(
        navigator.push(
          MaterialPageRoute<void>(builder: (_) => const SizedBox.shrink()),
        ),
      );
      await tester.pumpAndSettle();
      expect(container.read(shellObscuredProvider), isTrue);

      // Push a fullscreen video over the profile → still obscured (the shell's
      // RouteAware does not fire for a push above the profile).
      unawaited(
        navigator.push(
          MaterialPageRoute<void>(builder: (_) => const SizedBox.shrink()),
        ),
      );
      await tester.pumpAndSettle();
      expect(container.read(shellObscuredProvider), isTrue);

      // Close the video → back to the profile. The shell is still covered.
      navigator.pop();
      await tester.pumpAndSettle();
      expect(container.read(shellObscuredProvider), isTrue);

      // Close the profile → shell revealed.
      navigator.pop();
      await tester.pumpAndSettle();
      expect(container.read(shellObscuredProvider), isFalse);
    },
  );
}
