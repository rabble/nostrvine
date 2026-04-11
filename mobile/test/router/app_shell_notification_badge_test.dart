import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/app_update/app_update.dart';
import 'package:openvine/blocs/dm/unread_count/dm_unread_count_cubit.dart';
import 'package:openvine/models/environment_config.dart';
import 'package:openvine/providers/active_video_provider.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/environment_provider.dart';
import 'package:openvine/providers/relay_notifications_provider.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/router/router.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/widgets/notification_badge.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockAuthService extends Mock implements AuthService {}

class _MockDmUnreadCountCubit extends MockCubit<int>
    implements DmUnreadCountCubit {}

class _MockAppUpdateBloc extends MockBloc<AppUpdateEvent, AppUpdateState>
    implements AppUpdateBloc {}

Widget _buildSubject({
  required _MockAuthService mockAuthService,
  required SharedPreferences sharedPreferences,
  required int unreadCount,
  int dmUnreadCount = 0,
}) {
  final dmCubit = _MockDmUnreadCountCubit();
  when(() => dmCubit.state).thenReturn(dmUnreadCount);

  final appUpdateBloc = _MockAppUpdateBloc();
  when(() => appUpdateBloc.state).thenReturn(const AppUpdateState());

  return MultiBlocProvider(
    providers: [
      BlocProvider<DmUnreadCountCubit>.value(value: dmCubit),
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
        relayNotificationUnreadCountProvider.overrideWithValue(unreadCount),
      ],
      child: const MaterialApp(
        home: AppShell(currentIndex: 0, child: SizedBox.shrink()),
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

  group('$AppShell notification badge', () {
    testWidgets(
      'renders $NotificationBadge on bell tab when unread count > 0',
      (tester) async {
        await tester.pumpWidget(
          _buildSubject(
            mockAuthService: mockAuthService,
            sharedPreferences: sharedPreferences,
            unreadCount: 3,
          ),
        );
        await tester.pump();

        expect(find.byType(NotificationBadge), findsOneWidget);
        expect(find.text('3'), findsOneWidget);
      },
    );

    testWidgets('renders no badge when unread count is 0', (tester) async {
      await tester.pumpWidget(
        _buildSubject(
          mockAuthService: mockAuthService,
          sharedPreferences: sharedPreferences,
          unreadCount: 0,
        ),
      );
      await tester.pump();

      expect(find.byType(NotificationBadge), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(NotificationBadge),
          matching: find.byType(Positioned),
        ),
        findsNothing,
      );
    });
  });
}
