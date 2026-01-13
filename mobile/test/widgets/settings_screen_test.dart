// ABOUTME: Widget test for unified settings screen
// ABOUTME: Verifies settings navigation and UI structure

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/screens/settings_screen.dart';
import 'package:openvine/services/auth_service.dart';

@GenerateMocks([AuthService])
import 'settings_screen_test.mocks.dart';

void main() {
  group('SettingsScreen Tests', () {
    late MockAuthService mockAuthService;

    setUp(() {
      mockAuthService = MockAuthService();
      when(mockAuthService.isAuthenticated).thenReturn(true);
      when(mockAuthService.currentPublicKeyHex).thenReturn('test_pubkey');
      when(mockAuthService.authState).thenReturn(AuthState.authenticated);
      when(
        mockAuthService.authStateStream,
      ).thenAnswer((_) => Stream.value(AuthState.authenticated));
    });

    testWidgets('Settings screen displays all sections', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [authServiceProvider.overrideWithValue(mockAuthService)],
          child: const MaterialApp(home: SettingsScreen()),
        ),
      );

      // Verify section headers (displayed as uppercase)
      expect(find.text('PROFILE'), findsOneWidget);
      expect(find.text('NETWORK'), findsOneWidget);
      expect(find.text('PREFERENCES'), findsOneWidget);
      // TODO(any): Fix and re-enable these tests
    }, skip: true);

    testWidgets('Settings tiles display correctly', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [authServiceProvider.overrideWithValue(mockAuthService)],
          child: const MaterialApp(home: SettingsScreen()),
        ),
      );

      // Verify profile settings
      expect(find.text('Edit Profile'), findsOneWidget);
      expect(find.text('Key Management'), findsOneWidget);

      // Verify network settings
      expect(find.text('Relays'), findsOneWidget);
      expect(find.text('Relay Diagnostics'), findsOneWidget);
      expect(find.text('Media Servers'), findsOneWidget);

      // CRITICAL: P2P Sync should be hidden for release
      expect(find.text('P2P Sync'), findsNothing);
      expect(find.text('Peer-to-peer synchronization settings'), findsNothing);
      // TODO(any): Fix and re-enable these tests
    }, skip: true);

    testWidgets('Settings tiles have proper icons', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [authServiceProvider.overrideWithValue(mockAuthService)],
          child: const MaterialApp(home: SettingsScreen()),
        ),
      );

      // Verify icons exist
      expect(find.byIcon(Icons.person), findsWidgets); // Edit Profile
      expect(find.byIcon(Icons.key), findsWidgets); // Key Management
      expect(find.byIcon(Icons.hub), findsWidgets); // Relays
      expect(
        find.byIcon(Icons.troubleshoot),
        findsWidgets,
      ); // Relay Diagnostics
      expect(find.byIcon(Icons.cloud_upload), findsWidgets); // Media Servers

      // CRITICAL: P2P Sync icon (Icons.sync) should be hidden for release
      expect(find.byIcon(Icons.sync), findsNothing);
      // TODO(any): Fix and re-enable these tests
    }, skip: true);

    testWidgets('App bar displays correctly', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [authServiceProvider.overrideWithValue(mockAuthService)],
          child: const MaterialApp(home: SettingsScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Settings'), findsOneWidget);
      final appBar = tester.widget<AppBar>(find.byType(AppBar));
      expect(appBar.backgroundColor, isNotNull);

      // Dispose and pump to clear any pending timers from overlay visibility
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets('Settings screen reorganizes dev and danger items', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [authServiceProvider.overrideWithValue(mockAuthService)],
          child: const MaterialApp(home: SettingsScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // Preferences should be near the top (after Profile)
      expect(find.text('PREFERENCES'), findsOneWidget);

      // Scroll to find Developer Options under Network section
      await tester.scrollUntilVisible(
        find.text('Developer Options'),
        100,
        scrollable: find.byType(Scrollable),
      );
      await tester.pumpAndSettle();

      // Developer Options should always be visible (not hidden behind 7-tap)
      expect(find.text('Developer Options'), findsOneWidget);

      // Scroll to find Account section at the bottom with key management
      await tester.scrollUntilVisible(
        find.text('Key Management'),
        100,
        scrollable: find.byType(Scrollable),
      );
      await tester.pumpAndSettle();

      // Account section should have all key/account related items together
      expect(find.text('ACCOUNT'), findsOneWidget);
      expect(find.text('Log Out'), findsOneWidget);
      expect(find.text('Key Management'), findsOneWidget);
      expect(find.text('Remove Keys from Device'), findsOneWidget);
      expect(find.text('Delete Account and Data'), findsOneWidget);

      // Dispose and pump to clear any pending timers from overlay visibility
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });
  });
}
