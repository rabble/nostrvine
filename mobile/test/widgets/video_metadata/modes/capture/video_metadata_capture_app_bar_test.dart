// ABOUTME: Tests for VideoMetadataCaptureAppBar widget
// ABOUTME: Verifies rendering, Hero animation, and navigation behavior

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/widgets/video_metadata/modes/capture/video_metadata_capture_app_bar.dart';

import '../../../../helpers/go_router.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group(VideoMetadataCaptureAppBar, () {
    late GoRouter router;

    setUp(() {
      router = GoRouter(
        initialLocation: '/test',
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const Scaffold(body: Text('Home')),
          ),
          GoRoute(
            path: '/test',
            builder: (context, state) => const Scaffold(
              appBar: VideoMetadataCaptureAppBar(),
              body: Text('Test'),
            ),
          ),
        ],
      );
    });

    Widget buildTestWidget() {
      return MaterialApp.router(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      );
    }

    testWidgets('renders $VideoMetadataCaptureAppBar', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      expect(find.byType(VideoMetadataCaptureAppBar), findsOneWidget);
    });

    testWidgets('renders title text "Post details"', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      expect(find.text('Post details'), findsOneWidget);
    });

    testWidgets('renders back button with $DivineIconButton', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      expect(find.byType(DivineIconButton), findsOneWidget);
    });

    testWidgets('renders back button icon', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      expect(find.byType(SvgPicture), findsOneWidget);
    });

    testWidgets('wraps back button in Hero with correct tag', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      final heroFinder = find.byType(Hero);
      expect(heroFinder, findsOneWidget);

      final hero = tester.widget<Hero>(heroFinder);
      expect(hero.tag, equals(VideoEditorConstants.heroBackButtonId));
    });

    testWidgets('implements PreferredSizeWidget with kToolbarHeight', (
      tester,
    ) async {
      const header = VideoMetadataCaptureAppBar();

      expect(header, isA<PreferredSizeWidget>());
      expect(header.preferredSize.height, equals(kToolbarHeight));
    });

    testWidgets('tapping back button triggers pop navigation', (tester) async {
      final mockGoRouter = MockGoRouter();
      when(mockGoRouter.canPop).thenReturn(true);
      when(() => mockGoRouter.pop<Object?>(any())).thenAnswer((_) async {});

      await tester.pumpWidget(
        MockGoRouterProvider(
          goRouter: mockGoRouter,
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              appBar: VideoMetadataCaptureAppBar(),
              body: Text('Test'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify we're showing the app bar
      expect(find.byType(VideoMetadataCaptureAppBar), findsOneWidget);

      await tester.tap(find.byType(DivineIconButton));
      await tester.pumpAndSettle();

      verify(() => mockGoRouter.pop<Object?>(any())).called(1);
    });

    testWidgets('renders inside SafeArea with bottom: false', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      final safeAreaFinder = find.descendant(
        of: find.byType(VideoMetadataCaptureAppBar),
        matching: find.byType(SafeArea),
      );
      expect(safeAreaFinder, findsOneWidget);

      final safeArea = tester.widget<SafeArea>(safeAreaFinder);
      expect(safeArea.bottom, isFalse);
    });
  });
}
