// ABOUTME: Widget tests for the shell app bar / bottom nav composition
// ABOUTME: Previously only reachable by booting the whole app (#3337)

import 'package:bloc_test/bloc_test.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/blocs/dm/unread_count/dm_unread_count_cubit.dart';
import 'package:openvine/blocs/notifications/badge/notification_badge_cubit.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/router/providers/page_context_provider.dart';
import 'package:openvine/router/shell/shell_chrome.dart';
import 'package:openvine/screens/feed/home_feed_retap_cubit.dart';
import 'package:openvine/widgets/vine_bottom_nav.dart';

import '../../helpers/test_provider_overrides.dart';

class _MockDmUnreadCountCubit extends MockCubit<int>
    implements DmUnreadCountCubit {}

class _MockNotificationBadgeCubit extends MockCubit<int>
    implements NotificationBadgeCubit {}

void main() {
  group(ShellChrome, () {
    late MockAuthService mockAuth;
    late _MockDmUnreadCountCubit dmUnreadCubit;
    late _MockNotificationBadgeCubit notifBadgeCubit;
    late HomeFeedRetapCubit retapCubit;

    setUp(() {
      mockAuth = createMockAuthService();
      dmUnreadCubit = _MockDmUnreadCountCubit();
      notifBadgeCubit = _MockNotificationBadgeCubit();
      retapCubit = HomeFeedRetapCubit();
      whenListen(dmUnreadCubit, const Stream<int>.empty(), initialState: 0);
      whenListen(notifBadgeCubit, const Stream<int>.empty(), initialState: 0);
    });

    tearDown(() => retapCubit.close());

    Future<void> pumpChrome(
      WidgetTester tester, {
      required bool suppressAppBar,
      String title = 'Explore',
      RouteContext? routeContext,
      bool showBackButton = false,
      VoidCallback? onBackPressed,
    }) async {
      await tester.pumpWidget(
        MultiBlocProvider(
          providers: [
            BlocProvider<DmUnreadCountCubit>.value(value: dmUnreadCubit),
            BlocProvider<NotificationBadgeCubit>.value(value: notifBadgeCubit),
            BlocProvider<HomeFeedRetapCubit>.value(value: retapCubit),
          ],
          child: testProviderScope(
            mockAuthService: mockAuth,
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: ShellChrome(
                currentIndex: 1,
                title: title,
                routeContext: routeContext,
                suppressAppBar: suppressAppBar,
                showBackButton: showBackButton,
                resizeToAvoidBottomInset: true,
                onBackPressed: onBackPressed ?? () {},
                child: const Text('branch content'),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    group('renders', () {
      testWidgets('shows the resolved title in the app bar', (tester) async {
        await pumpChrome(tester, suppressAppBar: false);

        expect(
          find.descendant(
            of: find.byType(DiVineAppBar),
            matching: find.text('Explore'),
          ),
          findsOneWidget,
        );
      });

      testWidgets('renders no app bar for a route that owns its header', (
        tester,
      ) async {
        await pumpChrome(tester, suppressAppBar: true);

        expect(find.byType(DiVineAppBar), findsNothing);
        expect(find.text('branch content'), findsOneWidget);
      });

      testWidgets('keeps the bottom nav even without an app bar', (
        tester,
      ) async {
        await pumpChrome(tester, suppressAppBar: true);

        expect(find.byType(VineBottomNav), findsOneWidget);
      });

      testWidgets('hides the back button when the route does not want one', (
        tester,
      ) async {
        await pumpChrome(tester, suppressAppBar: false);

        expect(find.bySemanticsIdentifier('back_button'), findsNothing);
      });
    });

    group('interactions', () {
      testWidgets('runs the back policy when the back button is tapped', (
        tester,
      ) async {
        var pressed = 0;
        await pumpChrome(
          tester,
          suppressAppBar: false,
          showBackButton: true,
          onBackPressed: () => pressed++,
        );

        await tester.tap(find.bySemanticsIdentifier('back_button'));
        await tester.pump();

        expect(pressed, equals(1));
      });
    });
  });
}
