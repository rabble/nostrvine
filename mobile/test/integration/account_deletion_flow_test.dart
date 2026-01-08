// ABOUTME: Integration test for complete account deletion flow
// ABOUTME: Tests end-to-end deletion from Settings through sign out

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:nostr_sdk/client_utils/keys.dart';
import 'package:nostr_sdk/event.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/screens/settings_screen.dart';
import 'package:openvine/services/account_deletion_service.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:nostr_key_manager/nostr_key_manager.dart';
import 'package:nostr_client/nostr_client.dart';

import 'account_deletion_flow_test.mocks.dart';

@GenerateMocks([NostrClient, AuthService, NostrKeyManager, Keychain])
void main() {
  group('Account Deletion Flow Integration', () {
    late MockNostrClient mockNostrService;
    late MockAuthService mockAuthService;
    late MockNostrKeyManager mockKeyManager;
    late MockKeychain mockKeychain;
    late String testPrivateKey;
    late String testPublicKey;

    setUp(() {
      // Generate valid keys for testing
      testPrivateKey = generatePrivateKey();
      testPublicKey = getPublicKey(testPrivateKey);

      mockNostrService = MockNostrClient();
      mockAuthService = MockAuthService();
      mockKeyManager = MockNostrKeyManager();
      mockKeychain = MockKeychain();

      // Setup common mocks with valid keys
      when(mockKeyManager.keyPair).thenReturn(mockKeychain);
      when(mockKeychain.public).thenReturn(testPublicKey);
      when(mockKeychain.private).thenReturn(testPrivateKey);
    });

    testWidgets('complete deletion flow from settings to sign out', (
      tester,
    ) async {
      // Arrange
      when(mockAuthService.isAuthenticated).thenReturn(true);
      when(mockAuthService.currentProfile).thenReturn(null);
      when(mockAuthService.currentPublicKeyHex).thenReturn(testPublicKey);
      when(mockNostrService.hasKeys).thenReturn(true);

      final mockEvent = Event(
        testPublicKey,
        62,
        [
          ['relay', 'ALL_RELAYS'],
        ],
        'User requested account deletion via diVine app',
        createdAt: 1234567890,
      );

      when(
        mockNostrService.publishEvent(any),
      ).thenAnswer((_) async => mockEvent);

      when(
        mockAuthService.signOut(deleteKeys: true),
      ).thenAnswer((_) async => Future.value());

      final deletionService = AccountDeletionService(
        nostrService: mockNostrService,
        authService: mockAuthService,
      );

      // Act
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            accountDeletionServiceProvider.overrideWithValue(deletionService),
            authServiceProvider.overrideWithValue(mockAuthService),
          ],
          child: const MaterialApp(home: SettingsScreen()),
        ),
      );

      await tester.pumpAndSettle();

      // Tap Delete Account
      await tester.tap(find.text('Delete Account'));
      await tester.pumpAndSettle();

      // Verify warning dialog appears
      expect(find.text('⚠️ Delete Account?'), findsOneWidget);

      // Confirm deletion
      await tester.tap(find.text('Delete My Account'));
      await tester.pump(); // Start deletion
      await tester.pump(const Duration(milliseconds: 100)); // Loading indicator
      await tester.pumpAndSettle(); // Complete deletion

      // Verify NIP-62 event was published
      verify(mockNostrService.publishEvent(any)).called(1);

      // Verify user was signed out with keys deleted
      verify(mockAuthService.signOut(deleteKeys: true)).called(1);

      // Verify completion dialog appears
      expect(find.text('✓ Account Deleted'), findsOneWidget);
      expect(find.text('Create New Account'), findsOneWidget);
    });

    testWidgets('should show error when publish fails', (tester) async {
      // Arrange
      when(mockAuthService.isAuthenticated).thenReturn(true);
      when(mockAuthService.currentProfile).thenReturn(null);
      when(mockAuthService.currentPublicKeyHex).thenReturn(testPublicKey);
      when(mockNostrService.hasKeys).thenReturn(true);

      // publishEvent returns null on failure
      when(mockNostrService.publishEvent(any)).thenAnswer((_) async => null);

      final deletionService = AccountDeletionService(
        nostrService: mockNostrService,
        authService: mockAuthService,
      );

      // Act
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            accountDeletionServiceProvider.overrideWithValue(deletionService),
            authServiceProvider.overrideWithValue(mockAuthService),
          ],
          child: const MaterialApp(home: SettingsScreen()),
        ),
      );

      await tester.pumpAndSettle();

      // Tap Delete Account
      await tester.tap(find.text('Delete Account'));
      await tester.pumpAndSettle();

      // Confirm deletion
      await tester.tap(find.text('Delete My Account'));
      await tester.pump();
      await tester.pumpAndSettle();

      // Verify error message appears
      expect(find.textContaining('Failed to'), findsOneWidget);

      // Verify user was NOT signed out
      verifyNever(mockAuthService.signOut(deleteKeys: true));
    });
    // TODO(any): Fix and reenable this test
  }, skip: true);
}
