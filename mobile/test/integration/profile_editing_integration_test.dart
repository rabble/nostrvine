// ABOUTME: Integration test for profile editing race condition fix
// ABOUTME: Tests the complete profile editing flow from UI interaction to relay persistence

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';
import 'package:openvine/screens/profile_setup_screen.dart';
import 'package:openvine/services/user_profile_service.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/nostr_service.dart';
import 'package:openvine/models/user_profile.dart';
import '../helpers/test_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Profile Editing Integration Tests', () {
    late TestEnvironment testEnv;

    setUp(() async {
      testEnv = await TestEnvironment.create();
    });

    tearDown(() async {
      await testEnv.dispose();
    });

    testWidgets('profile editing should retry until relay processes update', (tester) async {
      // Setup: Create a test user profile
      const testName = 'Original Name';
      const testBio = 'Original Bio';
      const updatedName = 'Updated Name';
      const updatedBio = 'Updated Bio';
      
      final originalProfile = UserProfile.fromJson({
        'pubkey': testEnv.testPubkey,
        'name': testName,
        'about': testBio,
        'eventId': 'original-event-id',
        'createdAt': DateTime.now().subtract(const Duration(minutes: 1)).millisecondsSinceEpoch,
      });
      
      // Cache the original profile
      testEnv.userProfileService.updateCachedProfile(originalProfile);
      
      // Build the profile setup screen in edit mode
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<UserProfileService>.value(value: testEnv.userProfileService),
            ChangeNotifierProvider<AuthService>.value(value: testEnv.authService),
            ChangeNotifierProvider<NostrService>.value(value: testEnv.nostrService),
          ],
          child: MaterialApp(
            home: ProfileSetupScreen(isNewUser: false),
          ),
        ),
      );
      
      await tester.pumpAndSettle();
      
      // Find and fill in the form fields
      final nameField = find.byKey(const Key('profile_name_field'));
      final bioField = find.byKey(const Key('profile_bio_field'));
      final saveButton = find.byKey(const Key('save_profile_button'));
      
      expect(nameField, findsOneWidget);
      expect(bioField, findsOneWidget);
      expect(saveButton, findsOneWidget);
      
      // Clear existing text and enter new values
      await tester.enterText(nameField, updatedName);
      await tester.enterText(bioField, updatedBio);
      await tester.pumpAndSettle();
      
      // Setup: Mock the relay to initially return stale profile, then updated profile
      var fetchCallCount = 0;
      when(testEnv.userProfileService.fetchProfile(testEnv.testPubkey, forceRefresh: true))
          .thenAnswer((_) async {
        fetchCallCount++;
        if (fetchCallCount <= 2) {
          // First two calls return original profile (simulating relay lag)
          return originalProfile;
        } else {
          // Third call returns updated profile
          return UserProfile.fromJson({
            'pubkey': testEnv.testPubkey,
            'name': updatedName,
            'about': updatedBio,
            'eventId': 'updated-event-id',
            'createdAt': DateTime.now().millisecondsSinceEpoch,
          });
        }
      });
      
      // Mock successful broadcast
      when(testEnv.nostrService.broadcastEvent(any))
          .thenAnswer((_) async => TestEventBroadcastResult(
            isSuccessful: true,
            successCount: 1,
            totalRelays: 1,
            errors: [],
          ));
      
      // Tap save button
      await tester.tap(saveButton);
      await tester.pumpAndSettle();
      
      // Wait for retry logic to complete (should take ~3 seconds with 1s, 2s delays)
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      
      // Verify the retry logic was called multiple times
      verify(testEnv.userProfileService.fetchProfile(testEnv.testPubkey, forceRefresh: true))
          .called(greaterThanOrEqualTo(3));
      
      // Verify broadcast was called
      verify(testEnv.nostrService.broadcastEvent(any)).called(1);
      
      // Verify the screen shows success or navigates away
      // (Exact behavior depends on the UI implementation)
      expect(find.text('Profile updated successfully'), findsOneWidget);
    });

    testWidgets('profile editing should handle immediate success', (tester) async {
      const updatedName = 'Quick Update';
      const updatedBio = 'Quick Bio';
      
      // Build the profile setup screen
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<UserProfileService>.value(value: testEnv.userProfileService),
            ChangeNotifierProvider<AuthService>.value(value: testEnv.authService),
            ChangeNotifierProvider<NostrService>.value(value: testEnv.nostrService),
          ],
          child: MaterialApp(
            home: ProfileSetupScreen(isNewUser: false),
          ),
        ),
      );
      
      await tester.pumpAndSettle();
      
      // Fill in form
      await tester.enterText(find.byKey(const Key('profile_name_field')), updatedName);
      await tester.enterText(find.byKey(const Key('profile_bio_field')), updatedBio);
      
      // Setup: Mock immediate success (first fetch returns updated profile)
      when(testEnv.userProfileService.fetchProfile(testEnv.testPubkey, forceRefresh: true))
          .thenAnswer((_) async => UserProfile.fromJson({
            'pubkey': testEnv.testPubkey,
            'name': updatedName,
            'about': updatedBio,
            'eventId': 'immediate-success-event-id',
            'createdAt': DateTime.now().millisecondsSinceEpoch,
          }));
      
      when(testEnv.nostrService.broadcastEvent(any))
          .thenAnswer((_) async => TestEventBroadcastResult(
            isSuccessful: true,
            successCount: 1,
            totalRelays: 1,
            errors: [],
          ));
      
      // Save profile
      await tester.tap(find.byKey(const Key('save_profile_button')));
      await tester.pumpAndSettle();
      
      // Should complete quickly without retries
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      
      // Verify only one fetch call (no retries needed)
      verify(testEnv.userProfileService.fetchProfile(testEnv.testPubkey, forceRefresh: true))
          .called(1);
    });

    testWidgets('profile editing should handle max retries failure', (tester) async {
      const updatedName = 'Failed Update';
      
      // Build the profile setup screen
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<UserProfileService>.value(value: testEnv.userProfileService),
            ChangeNotifierProvider<AuthService>.value(value: testEnv.authService),
            ChangeNotifierProvider<NostrService>.value(value: testEnv.nostrService),
          ],
          child: MaterialApp(
            home: ProfileSetupScreen(isNewUser: false),
          ),
        ),
      );
      
      await tester.pumpAndSettle();
      
      // Fill in form
      await tester.enterText(find.byKey(const Key('profile_name_field')), updatedName);
      
      // Setup: Always return stale profile (relay never processes update)
      final staleProfile = UserProfile.fromJson({
        'pubkey': testEnv.testPubkey,
        'name': 'Stale Name',
        'about': 'Stale Bio',
        'eventId': 'stale-event-id',
        'createdAt': DateTime.now().subtract(const Duration(hours: 1)).millisecondsSinceEpoch,
      });
      
      when(testEnv.userProfileService.fetchProfile(testEnv.testPubkey, forceRefresh: true))
          .thenAnswer((_) async => staleProfile);
      
      when(testEnv.nostrService.broadcastEvent(any))
          .thenAnswer((_) async => TestEventBroadcastResult(
            isSuccessful: true,
            successCount: 1,
            totalRelays: 1,
            errors: [],
          ));
      
      // Save profile
      await tester.tap(find.byKey(const Key('save_profile_button')));
      await tester.pumpAndSettle();
      
      // Wait for all retries to complete (should fail after 3 attempts)
      await tester.pump(const Duration(seconds: 10));
      await tester.pumpAndSettle();
      
      // Should show error message
      expect(find.textContaining('Failed to update profile'), findsOneWidget);
      
      // Verify multiple retry attempts
      verify(testEnv.userProfileService.fetchProfile(testEnv.testPubkey, forceRefresh: true))
          .called(greaterThanOrEqualTo(3));
    });
  });
}

// Helper class for test event broadcast results
class TestEventBroadcastResult {
  final bool isSuccessful;
  final int successCount;
  final int totalRelays;
  final List<String> errors;
  
  TestEventBroadcastResult({
    required this.isSuccessful,
    required this.successCount,
    required this.totalRelays,
    required this.errors,
  });
}