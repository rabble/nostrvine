// ABOUTME: Widget test for welcome screen Google Font rendering
// ABOUTME: Verifies that the Divine title uses Pacifico font

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/screens/welcome_screen.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:openvine/services/auth_service.dart';

@GenerateMocks([AuthService])
import 'welcome_screen_font_test.mocks.dart';

void main() {
  group('WelcomeScreen Font Tests', () {
    late MockAuthService mockAuthService;

    setUp(() {
      mockAuthService = MockAuthService();
      // Mock the authState property that welcome screen now uses
      when(mockAuthService.authState).thenReturn(AuthState.authenticated);
      when(mockAuthService.isAuthenticated).thenReturn(true);
      when(mockAuthService.lastError).thenReturn(null);
    });

    testWidgets('Divine title uses Pacifico Google Font', (tester) async {
      // Set larger test size to prevent overflow
      await tester.binding.setSurfaceSize(const Size(800, 1200));

      // Build the widget with provider override
      await tester.pumpWidget(
        ProviderScope(
          overrides: [authServiceProvider.overrideWithValue(mockAuthService)],
          child: const MaterialApp(home: WelcomeScreen()),
        ),
      );

      // Allow font loading to complete (will use fallback in tests)
      await tester.pumpAndSettle();

      // Find the title text widget
      final titleFinder = find.text(
        'Create and share short videos\non the decentralized web',
      );
      expect(titleFinder, findsOneWidget);

      // Get the Text widget
      final Text titleWidget = tester.widget(titleFinder);

      // Verify the style uses Pacifico font family
      expect(titleWidget.style, isNotNull);
      expect(titleWidget.style!.fontFamily, contains('Pacifico'));

      // Verify other style properties
      expect(titleWidget.style!.fontSize, equals(18));
      expect(titleWidget.style!.color, equals(const Color(0xFFF5F6EA)));
    });

    testWidgets('Welcome screen layout renders correctly', (tester) async {
      // Set larger test size to prevent overflow
      await tester.binding.setSurfaceSize(const Size(800, 1200));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [authServiceProvider.overrideWithValue(mockAuthService)],
          child: const MaterialApp(home: WelcomeScreen()),
        ),
      );

      // Allow font loading to complete (will use fallback in tests)
      await tester.pumpAndSettle();

      // Verify key elements are present
      expect(
        find.text('Create and share short videos\non the decentralized web'),
        findsOneWidget,
      );
      expect(
        find.text('Already have keys? Import them here →'),
        findsOneWidget,
      );
    });
  });
}
