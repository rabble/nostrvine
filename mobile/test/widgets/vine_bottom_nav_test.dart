import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/dm/unread_count/dm_unread_count_cubit.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/widgets/vine_bottom_nav.dart';

import '../helpers/go_router.dart';
import '../helpers/test_provider_overrides.dart';

class _MockDmUnreadCountCubit extends MockCubit<int>
    implements DmUnreadCountCubit {}

void main() {
  group('VineBottomNav interaction targets', () {
    late MockAuthService mockAuth;
    late _MockDmUnreadCountCubit dmUnreadCubit;

    setUp(() {
      mockAuth = createMockAuthService();
      dmUnreadCubit = _MockDmUnreadCountCubit();
      whenListen(dmUnreadCubit, const Stream<int>.empty(), initialState: 0);
    });

    Future<void> pumpSubject(WidgetTester tester) async {
      await tester.pumpWidget(
        BlocProvider<DmUnreadCountCubit>.value(
          value: dmUnreadCubit,
          child: testProviderScope(
            mockAuthService: mockAuth,
            child: const MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(body: VineBottomNav(currentIndex: 0)),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    Future<void> pumpSubjectWithRouter(
      WidgetTester tester,
      MockGoRouter router,
    ) async {
      await tester.pumpWidget(
        BlocProvider<DmUnreadCountCubit>.value(
          value: dmUnreadCubit,
          child: testProviderScope(
            mockAuthService: mockAuth,
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: MockGoRouterProvider(
                goRouter: router,
                child: const Scaffold(body: VineBottomNav(currentIndex: 0)),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('icon and profile tabs have minimum interactive dimensions', (
      tester,
    ) async {
      await pumpSubject(tester);

      final sizedBoxes = tester
          .widgetList<SizedBox>(find.byType(SizedBox))
          .where(
            (box) =>
                box.width == kMinInteractiveDimension &&
                box.height == kMinInteractiveDimension,
          )
          .toList();

      expect(sizedBoxes, hasLength(4));
    });

    testWidgets('all five tabs use opaque gesture hit behavior', (
      tester,
    ) async {
      await pumpSubject(tester);

      final opaqueDetectors = tester
          .widgetList<GestureDetector>(find.byType(GestureDetector))
          .where((detector) => detector.behavior == HitTestBehavior.opaque)
          .toList();

      // Home / Explore / Camera / Inbox / Profile — each owns an opaque
      // GestureDetector that fills its slice of the row so taps in the
      // surrounding gap also route to the right tab.
      expect(opaqueDetectors, hasLength(5));
    });

    testWidgets(
      'tapping the top-left corner of the home-tab hit target fires navigation',
      (tester) async {
        final router = MockGoRouter();

        await pumpSubjectWithRouter(tester, router);

        final rect = tester.getRect(find.bySemanticsIdentifier('home_tab'));
        // Tap 2 px inside the top-left corner — the hit target must respond
        // here, not just at the centre where the icon is drawn.
        await tester.tapAt(rect.topLeft + const Offset(2, 2));
        await tester.pump();

        verify(() => router.go(any())).called(1);
      },
    );

    testWidgets(
      'tab hit targets divide the inter-icon gap so taps just past an '
      'icon still route to that tab',
      (tester) async {
        final router = MockGoRouter();
        await pumpSubjectWithRouter(tester, router);

        final homeRect = tester.getRect(
          find.bySemanticsIdentifier('home_tab'),
        );
        final exploreRect = tester.getRect(
          find.bySemanticsIdentifier('explore_tab'),
        );

        // The two slots must touch (no dead zone between them).
        expect(homeRect.right, exploreRect.left);
        // And each must be wider than the bare 48 px icon container —
        // otherwise the gap was not absorbed.
        expect(homeRect.width, greaterThan(kMinInteractiveDimension));
        expect(exploreRect.width, greaterThan(kMinInteractiveDimension));

        // Tap inside the home slot, just to the right of the home icon
        // (i.e. inside the inter-icon half-gap, not on the icon itself).
        final justPastHomeIcon = Offset(
          homeRect.left + kMinInteractiveDimension + 1,
          homeRect.center.dy,
        );
        await tester.tapAt(justPastHomeIcon);
        await tester.pump();

        verify(() => router.go(any())).called(1);
      },
    );

    testWidgets(
      'tab hit targets extend above the icon row so taps in the strip '
      'above the icons still route to the tab below',
      (tester) async {
        final router = MockGoRouter();
        await pumpSubjectWithRouter(tester, router);

        final homeRect = tester.getRect(
          find.bySemanticsIdentifier('home_tab'),
        );

        // The slot is taller than a bare 48 px icon container — extra
        // height above the icon is part of the hit target.
        expect(homeRect.height, greaterThan(kMinInteractiveDimension));

        // Tap 2 px below the slot's top edge — well above where the
        // icon is drawn. The strip above the icon container is part of
        // the slot, not dead space.
        await tester.tapAt(homeRect.topLeft + const Offset(8, 2));
        await tester.pump();

        verify(() => router.go(any())).called(1);
      },
    );

    testWidgets(
      'home and profile slots reach the screen edges so taps in the '
      'edge strip still route to the adjacent tab',
      (tester) async {
        final router = MockGoRouter();
        await pumpSubjectWithRouter(tester, router);

        final navRect = tester.getRect(find.byType(VineBottomNav));
        final homeRect = tester.getRect(
          find.bySemanticsIdentifier('home_tab'),
        );
        final profileRect = tester.getRect(
          find.bySemanticsIdentifier('profile_tab'),
        );

        // Outer edges of Home / Profile slots align with the bottom
        // nav's left / right edges — no horizontal dead zone.
        expect(homeRect.left, navRect.left);
        expect(profileRect.right, navRect.right);

        // Tap 2 px in from the screen's left edge — inside the home
        // slot's outer edge inset, not on the icon itself.
        await tester.tapAt(
          Offset(navRect.left + 2, homeRect.center.dy),
        );
        await tester.pump();

        verify(() => router.go(any())).called(1);
      },
    );

    testWidgets(
      'tab hit targets extend below the icon row so taps in the strip '
      'below the icons still route to the tab above',
      (tester) async {
        final router = MockGoRouter();
        await pumpSubjectWithRouter(tester, router);

        final navRect = tester.getRect(find.byType(VineBottomNav));
        final homeRect = tester.getRect(
          find.bySemanticsIdentifier('home_tab'),
        );

        // The slot's bottom edge meets the bottom nav's bottom edge.
        // (No bottom safe area inset is applied in the test environment,
        // so the two are exactly equal — on real devices [SafeArea]
        // separates them by [MediaQuery.viewPadding.bottom].)
        expect(homeRect.bottom, navRect.bottom);

        // Tap 2 px above the slot's bottom edge — well below where the
        // icon is drawn (the icon is centred in a 72 px slot, so its
        // bottom edge sits 12 px above the slot's bottom). The strip
        // below the icon container is part of the slot.
        await tester.tapAt(
          Offset(homeRect.center.dx, homeRect.bottom - 2),
        );
        await tester.pump();

        verify(() => router.go(any())).called(1);
      },
    );
  });
}
