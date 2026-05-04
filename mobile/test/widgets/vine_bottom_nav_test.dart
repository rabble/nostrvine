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

    testWidgets('icon and profile tabs use opaque gesture hit behavior', (
      tester,
    ) async {
      await pumpSubject(tester);

      final opaqueDetectors = tester
          .widgetList<GestureDetector>(find.byType(GestureDetector))
          .where((detector) => detector.behavior == HitTestBehavior.opaque)
          .toList();

      expect(opaqueDetectors, hasLength(4));
    });

    testWidgets(
      'tapping the top-left corner of the home-tab hit target fires navigation',
      (tester) async {
        final router = MockGoRouter();

        await pumpSubjectWithRouter(tester, router);

        final rect = tester.getRect(find.bySemanticsIdentifier('home_tab'));
        // Tap 2 px inside the top-left corner — the 48×48 hit target must
        // respond here, not just at the centre where the icon is drawn.
        await tester.tapAt(rect.topLeft + const Offset(2, 2));
        await tester.pump();

        verify(() => router.go(any())).called(1);
      },
    );
  });
}
