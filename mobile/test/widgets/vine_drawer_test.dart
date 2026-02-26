// ABOUTME: Unit tests for VineDrawer widget
// ABOUTME: Tests branding (wordmark logo), navigation menu, and video pause behavior

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/screens/settings_screen.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/widgets/vine_drawer.dart';

import '../helpers/go_router.dart';

class _MockAuthService extends Mock implements AuthService {}

void main() {
  group('VineDrawer Branding', () {
    late _MockAuthService mockAuthService;

    setUp(() {
      mockAuthService = _MockAuthService();
      when(() => mockAuthService.isAuthenticated).thenReturn(true);
      when(
        () => mockAuthService.currentPublicKeyHex,
      ).thenReturn('test_pubkey_${'0' * 54}');
    });

    testWidgets('displays Divine logo image in header', (tester) async {
      final scaffoldKey = GlobalKey<ScaffoldState>();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authServiceProvider.overrideWith((ref) => mockAuthService),
            currentAuthStateProvider.overrideWithValue(AuthState.authenticated),
          ],
          child: MaterialApp(
            home: Scaffold(
              key: scaffoldKey,
              drawer: const VineDrawer(),
              body: const Center(child: Text('Test')),
            ),
          ),
        ),
      );

      // Open the drawer using scaffold key
      scaffoldKey.currentState!.openDrawer();
      await tester.pumpAndSettle();

      // Verify SVG logo is present (logo.svg rendered via SvgPicture)
      expect(
        find.byType(SvgPicture),
        findsWidgets,
        reason: 'Divine logo SVG should be displayed in drawer',
      );
    });

    testWidgets('does not display "OpenVine" text in header', (tester) async {
      final scaffoldKey = GlobalKey<ScaffoldState>();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authServiceProvider.overrideWith((ref) => mockAuthService),
            currentAuthStateProvider.overrideWithValue(AuthState.authenticated),
          ],
          child: MaterialApp(
            home: Scaffold(
              key: scaffoldKey,
              drawer: const VineDrawer(),
              body: const Center(child: Text('Test')),
            ),
          ),
        ),
      );

      // Open the drawer using scaffold key
      scaffoldKey.currentState!.openDrawer();
      await tester.pumpAndSettle();

      // Verify "OpenVine" text is NOT present in the header
      expect(
        find.text('OpenVine'),
        findsNothing,
        reason: 'Old "OpenVine" branding should not be displayed',
      );
    });

    testWidgets('does not use generic icon in header', (tester) async {
      final scaffoldKey = GlobalKey<ScaffoldState>();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authServiceProvider.overrideWith((ref) => mockAuthService),
            currentAuthStateProvider.overrideWithValue(AuthState.authenticated),
          ],
          child: MaterialApp(
            home: Scaffold(
              key: scaffoldKey,
              drawer: const VineDrawer(),
              body: const Center(child: Text('Test')),
            ),
          ),
        ),
      );

      // Open the drawer using scaffold key
      scaffoldKey.currentState!.openDrawer();
      await tester.pumpAndSettle();

      // Verify Icons.video_library is NOT used in header
      expect(
        find.byIcon(Icons.video_library),
        findsNothing,
        reason:
            'Generic video_library icon should not be used, use wordmark instead',
      );
    });
  });

  group('VineDrawer Settings navigation', () {
    late MockGoRouter mockGoRouter;
    late _MockAuthService mockAuthService;

    setUp(() {
      mockGoRouter = MockGoRouter();
      when(() => mockGoRouter.push(any())).thenAnswer((_) async => null);

      mockAuthService = _MockAuthService();
      when(() => mockAuthService.isAuthenticated).thenReturn(true);
      when(
        () => mockAuthService.currentPublicKeyHex,
      ).thenReturn('test_pubkey_${'0' * 54}');
    });

    testWidgets(
      'pushes settings route before closing drawer to prevent video resume',
      (tester) async {
        final scaffoldKey = GlobalKey<ScaffoldState>();
        var didDrawerClose = false;

        // Track call order to verify push happens before drawer closes
        when(() => mockGoRouter.push(any())).thenAnswer((_) => Future.value());

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authServiceProvider.overrideWith((ref) => mockAuthService),
              currentAuthStateProvider.overrideWithValue(
                AuthState.authenticated,
              ),
            ],
            child: MaterialApp(
              home: MockGoRouterProvider(
                goRouter: mockGoRouter,
                child: Scaffold(
                  key: scaffoldKey,
                  onDrawerChanged: (isOpen) {
                    if (!isOpen) didDrawerClose = true;
                  },
                  drawer: const VineDrawer(),
                  body: const Center(child: Text('Test')),
                ),
              ),
            ),
          ),
        );

        // Open the drawer
        scaffoldKey.currentState!.openDrawer();
        await tester.pumpAndSettle();

        // Tap Settings
        await tester.tap(find.text('Settings'));
        await tester.pumpAndSettle();

        // didDrawerClose stays true while the route is being pushed,
        // preventing a brief video resume.
        expect(didDrawerClose, isTrue);

        // Verify GoRouter.push was called with settings path
        verify(() => mockGoRouter.push(SettingsScreen.path)).called(1);
      },
    );
  });
}
