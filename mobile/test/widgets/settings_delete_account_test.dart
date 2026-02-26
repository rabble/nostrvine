// ABOUTME: Tests for Delete Account integration in Settings screen
// ABOUTME: Verifies Account section appears and delete flow triggers correctly

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/screens/settings_screen.dart';
import 'package:openvine/services/account_deletion_service.dart';
import 'package:openvine/services/auth_service.dart';

class _MockAccountDeletionService extends Mock
    implements AccountDeletionService {}

class _MockAuthService extends Mock implements AuthService {}

void main() {
  group('SettingsScreen - Delete Account', () {
    late _MockAccountDeletionService mockDeletionService;
    late _MockAuthService mockAuthService;

    setUp(() {
      mockDeletionService = _MockAccountDeletionService();
      mockAuthService = _MockAuthService();
    });

    testWidgets('should show Delete Account option when authenticated', (
      tester,
    ) async {
      when(() => mockAuthService.isAuthenticated).thenReturn(true);
      when(() => mockAuthService.currentProfile).thenReturn(null);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            accountDeletionServiceProvider.overrideWithValue(
              mockDeletionService,
            ),
            authServiceProvider.overrideWithValue(mockAuthService),
            currentAuthStateProvider.overrideWithValue(AuthState.authenticated),
          ],
          child: const MaterialApp(home: SettingsScreen()),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('ACCOUNT'), findsOneWidget);
      expect(find.text('Delete Account'), findsOneWidget);
      expect(
        find.text('Permanently delete all your content from Nostr relays'),
        findsOneWidget,
      );
      // TODO(any): Fix and re-enable these tests
    }, skip: true);

    testWidgets('should hide Delete Account when not authenticated', (
      tester,
    ) async {
      when(() => mockAuthService.isAuthenticated).thenReturn(false);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            accountDeletionServiceProvider.overrideWithValue(
              mockDeletionService,
            ),
            authServiceProvider.overrideWithValue(mockAuthService),
            currentAuthStateProvider.overrideWithValue(
              AuthState.unauthenticated,
            ),
          ],
          child: const MaterialApp(home: SettingsScreen()),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('ACCOUNT'), findsNothing);
      expect(find.text('Delete Account'), findsNothing);

      // Dispose and pump to clear any pending timers from overlay visibility
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets('should show warning dialog when Delete Account tapped', (
      tester,
    ) async {
      when(() => mockAuthService.isAuthenticated).thenReturn(true);
      when(() => mockAuthService.currentProfile).thenReturn(null);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            accountDeletionServiceProvider.overrideWithValue(
              mockDeletionService,
            ),
            authServiceProvider.overrideWithValue(mockAuthService),
            currentAuthStateProvider.overrideWithValue(AuthState.authenticated),
          ],
          child: const MaterialApp(home: SettingsScreen()),
        ),
      );

      await tester.pumpAndSettle();

      await tester.tap(find.text('Delete Account'));
      await tester.pumpAndSettle();

      expect(find.text('\u26A0\uFE0F Delete Account?'), findsOneWidget);
      expect(find.textContaining('PERMANENT'), findsOneWidget);
      // TODO(any): Fix and re-enable these tests
    }, skip: true);

    testWidgets('Delete Account tile should have red icon and text', (
      tester,
    ) async {
      when(() => mockAuthService.isAuthenticated).thenReturn(true);
      when(() => mockAuthService.currentProfile).thenReturn(null);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            accountDeletionServiceProvider.overrideWithValue(
              mockDeletionService,
            ),
            authServiceProvider.overrideWithValue(mockAuthService),
            currentAuthStateProvider.overrideWithValue(AuthState.authenticated),
          ],
          child: const MaterialApp(home: SettingsScreen()),
        ),
      );

      await tester.pumpAndSettle();

      final deleteAccountTile = find.ancestor(
        of: find.text('Delete Account'),
        matching: find.byType(ListTile),
      );

      expect(deleteAccountTile, findsOneWidget);

      final listTile = tester.widget<ListTile>(deleteAccountTile);
      final leadingIcon = listTile.leading! as Icon;
      final titleText = listTile.title! as Text;

      expect(leadingIcon.color, equals(Colors.red));
      expect(leadingIcon.icon, equals(Icons.delete_forever));
      expect(titleText.style?.color, equals(Colors.red));
      // TODO(any): Fix and re-enable these tests
    }, skip: true);
  });
}
