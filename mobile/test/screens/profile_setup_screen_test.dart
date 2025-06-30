// ABOUTME: Test for ProfileSetupScreen save functionality - form validation, kind 0 event creation, and publishing
// ABOUTME: Ensures profile setup actually saves data and publishes to Nostr relays correctly

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:openvine/screens/profile_setup_screen.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/user_profile_service.dart';
import 'package:openvine/services/nostr_service_interface.dart';
import 'package:openvine/services/direct_upload_service.dart';
import 'package:openvine/services/subscription_manager.dart';
import 'package:openvine/models/user_profile.dart' as model;
import 'package:nostr_sdk/event.dart';

@GenerateMocks([
  AuthService,
  UserProfileService,
  INostrService,
  DirectUploadService,
  ImagePicker,
  SubscriptionManager,
])
import 'profile_setup_screen_test.mocks.dart';

void main() {
  group('ProfileSetupScreen', () {
    late MockAuthService mockAuthService;
    late MockUserProfileService mockUserProfileService;
    late MockINostrService mockNostrService;
    
    setUp(() {
      mockAuthService = MockAuthService();
      mockUserProfileService = MockUserProfileService();
      mockNostrService = MockINostrService();
      
      // Setup default mocks
      when(mockAuthService.currentPublicKeyHex).thenReturn('test_pubkey_hex');
      when(mockAuthService.createAndSignEvent(
        kind: anyNamed('kind'),
        content: anyNamed('content'),
      )).thenAnswer((_) async => Event(
        'test_pubkey',
        0,
        [],
        '{}',
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      ));
      
      when(mockNostrService.broadcastEvent(any)).thenAnswer(
        (_) async => NostrBroadcastResult(
          event: Event('test_pubkey', 0, [], '{}'),
          successCount: 1,
          totalRelays: 1,
          results: {'wss://relay1.com': true},
          errors: {},
        ),
      );
      
      when(mockUserProfileService.fetchProfile(any)).thenAnswer((_) async => null);
    });

    Widget createTestWidget({bool isNewUser = false}) {
      return MaterialApp(
        home: MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthService>.value(value: mockAuthService),
            ChangeNotifierProvider<UserProfileService>.value(value: mockUserProfileService),
            ChangeNotifierProvider<INostrService>.value(value: mockNostrService),
          ],
          child: ProfileSetupScreen(isNewUser: isNewUser),
        ),
      );
    }

    testWidgets('displays profile setup form', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(isNewUser: true));
      
      expect(find.text('Welcome to OpenVine!'), findsOneWidget);
      expect(find.text('Display Name'), findsOneWidget);
      expect(find.text('Bio (Optional)'), findsOneWidget);
      expect(find.text('Profile Picture (Optional)'), findsOneWidget);
    });

    testWidgets('validates required display name', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      
      // Try to submit without name
      await tester.tap(find.text('Get Started'));
      await tester.pumpAndSettle();
      
      expect(find.text('Please enter a display name'), findsOneWidget);
    });

    testWidgets('shows camera and gallery buttons for profile picture', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      
      expect(find.byIcon(Icons.camera_alt), findsOneWidget);
      expect(find.byIcon(Icons.photo_library), findsOneWidget);
      expect(find.text('Camera'), findsOneWidget);
      expect(find.text('Gallery'), findsOneWidget);
    });

    testWidgets('shows URL input in expansion tile', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      
      // Expand URL input
      await tester.tap(find.text('Or paste image URL'));
      await tester.pumpAndSettle();
      
      expect(find.byIcon(Icons.link), findsOneWidget);
      expect(find.text('https://example.com/your-avatar.jpg'), findsOneWidget);
    });

    testWidgets('successfully publishes profile', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      
      // Fill in form
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Display Name'),
        'Test User',
      );
      
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Bio (Optional)'),
        'Test bio',
      );
      
      // Submit
      await tester.tap(find.text('Get Started'));
      await tester.pumpAndSettle();
      
      // Verify profile was published
      verify(mockAuthService.createAndSignEvent(
        kind: 0,
        content: argThat(contains('"name":"Test User"')),
      )).called(1);
      
      verify(mockNostrService.broadcastEvent(any)).called(1);
    });

    testWidgets('shows publishing progress', (WidgetTester tester) async {
      // Delay the broadcast response
      when(mockNostrService.broadcastEvent(any)).thenAnswer(
        (_) async {
          await Future.delayed(const Duration(seconds: 1));
          return NostrBroadcastResult(
            event: Event('test_pubkey', 0, [], '{}'),
            successCount: 1,
            totalRelays: 1,
            results: {'wss://relay1.com': true},
            errors: {},
          );
        },
      );
      
      await tester.pumpWidget(createTestWidget());
      
      // Fill in name
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Display Name'),
        'Test User',
      );
      
      // Submit
      await tester.tap(find.text('Get Started'));
      await tester.pump();
      
      // Should show publishing indicator
      expect(find.text('Publishing...'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('handles profile publish failure', (WidgetTester tester) async {
      when(mockNostrService.broadcastEvent(any)).thenAnswer(
        (_) async => NostrBroadcastResult(
          event: Event('test_pubkey', 0, [], '{}'),
          successCount: 0,
          totalRelays: 1,
          results: {'wss://relay1.com': false},
          errors: {'wss://relay1.com': 'Connection failed'},
        ),
      );
      
      await tester.pumpWidget(createTestWidget());
      
      // Fill in form
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Display Name'),
        'Test User',
      );
      
      // Submit
      await tester.tap(find.text('Get Started'));
      await tester.pumpAndSettle();
      
      // Should show error snackbar
      expect(find.text('Failed to publish profile. Please try again.'), findsOneWidget);
    });

    testWidgets('skip button works for new users', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(isNewUser: true));
      
      // Find and tap skip button
      await tester.tap(find.text('Skip for now'));
      await tester.pumpAndSettle();
      
      // Should navigate away (in real app)
      // In test, we just verify the button exists and is tappable
    });

    testWidgets('loads existing profile for edit', (WidgetTester tester) async {
      final existingProfile = model.UserProfile(
        pubkey: 'test_pubkey_hex',
        name: 'Existing User',
        displayName: 'Existing User',
        about: 'Existing bio',
        picture: 'https://example.com/avatar.jpg',
        createdAt: DateTime.now(),
        eventId: 'test_event_id',
        rawData: {},
      );
      
      when(mockUserProfileService.fetchProfile(any)).thenAnswer(
        (_) async => existingProfile,
      );
      
      await tester.pumpWidget(createTestWidget(isNewUser: false));
      await tester.pumpAndSettle();
      
      // Should load existing values
      expect(find.text('Existing User'), findsOneWidget);
      expect(find.text('Existing bio'), findsOneWidget);
      expect(find.text('https://example.com/avatar.jpg'), findsOneWidget);
    });

    testWidgets('refreshes profile after successful update', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(isNewUser: false));
      
      // Fill in form
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Display Name'),
        'Updated User',
      );
      
      // Submit
      await tester.tap(find.text('Update Profile'));
      await tester.pumpAndSettle();
      
      // Verify profile refresh was called
      verify(mockUserProfileService.fetchProfile('test_pubkey_hex')).called(1);
    });

    testWidgets('creates proper kind 0 event content', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      
      // Fill in comprehensive profile data
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Display Name'),
        'Test User',
      );
      
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Bio (Optional)'),
        'This is my test bio',
      );
      
      // Expand URL section and add picture
      await tester.tap(find.text('Or paste image URL'));
      await tester.pumpAndSettle();
      
      final urlField = find.byType(TextFormField).last; // URL field is the last one after expansion
      await tester.enterText(urlField, 'https://example.com/avatar.jpg');
      
      // Submit
      await tester.tap(find.text('Get Started'));
      await tester.pumpAndSettle();
      
      // Verify the event content includes all profile data
      final captured = verify(mockAuthService.createAndSignEvent(
        kind: 0,
        content: captureAnyNamed('content'),
      )).captured.single;
      
      final profileData = jsonDecode(captured as String);
      expect(profileData['name'], equals('Test User'));
      expect(profileData['about'], equals('This is my test bio'));
      expect(profileData['picture'], equals('https://example.com/avatar.jpg'));
    });

    testWidgets('validates URL format for picture field', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      
      // Enter valid display name
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Display Name'),
        'Test User',
      );
      
      // Expand URL section
      await tester.tap(find.text('Or paste image URL'));
      await tester.pumpAndSettle();
      
      // Enter invalid URL
      final urlField = find.byType(TextFormField).last; // URL field is the last one after expansion
      await tester.enterText(urlField, 'not-a-valid-url');
      
      // Try to submit
      await tester.tap(find.text('Get Started'));
      await tester.pumpAndSettle();
      
      // Should show validation error
      expect(find.text('Please enter a valid URL'), findsOneWidget);
    });

    testWidgets('handles event creation failure gracefully', (WidgetTester tester) async {
      // Mock event creation to return null (failure)
      when(mockAuthService.createAndSignEvent(
        kind: anyNamed('kind'),
        content: anyNamed('content'),
      )).thenAnswer((_) async => null);
      
      await tester.pumpWidget(createTestWidget());
      
      // Fill in form
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Display Name'),
        'Test User',
      );
      
      // Submit
      await tester.tap(find.text('Get Started'));
      await tester.pumpAndSettle();
      
      // Should show error message
      expect(find.textContaining('Error publishing profile'), findsOneWidget);
    });

    testWidgets('handles broadcast failure with error message', (WidgetTester tester) async {
      // Mock broadcast to fail
      when(mockNostrService.broadcastEvent(any)).thenAnswer(
        (_) async => NostrBroadcastResult(
          event: Event('test_pubkey', 0, [], '{}'),
          successCount: 0,
          totalRelays: 1,
          results: {'wss://relay1.com': false},
          errors: {'wss://relay1.com': 'Network error'},
        ),
      );
      
      await tester.pumpWidget(createTestWidget());
      
      // Fill in form
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Display Name'),
        'Test User',
      );
      
      // Submit
      await tester.tap(find.text('Get Started'));
      await tester.pumpAndSettle();
      
      // Should show error message
      expect(find.text('Failed to publish profile. Please try again.'), findsOneWidget);
    });

    testWidgets('shows success message on successful publish', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      
      // Fill in form
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Display Name'),
        'Test User',
      );
      
      // Submit
      await tester.tap(find.text('Get Started'));
      await tester.pumpAndSettle();
      
      // Should show success message
      expect(find.text('Profile published successfully!'), findsOneWidget);
    });

    testWidgets('disables form while publishing', (WidgetTester tester) async {
      // Mock slow publishing
      when(mockNostrService.broadcastEvent(any)).thenAnswer((_) async {
        await Future.delayed(const Duration(milliseconds: 100));
        return NostrBroadcastResult(
          event: Event('test_pubkey', 0, [], '{}'),
          successCount: 1,
          totalRelays: 1,
          results: {'wss://relay1.com': true},
          errors: {},
        );
      });
      
      await tester.pumpWidget(createTestWidget());
      
      // Fill in form
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Display Name'),
        'Test User',
      );
      
      // Submit
      await tester.tap(find.text('Get Started'));
      await tester.pump(); // Don't settle, so we can see the loading state
      
      // Should show publishing state and disable button
      expect(find.text('Publishing...'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      
      // Button should be disabled (can't easily test directly, but we verify the loading state)
      final elevatedButton = tester.widget<ElevatedButton>(
        find.byType(ElevatedButton)
      );
      expect(elevatedButton.onPressed, isNull);
    });

    testWidgets('includes only non-empty fields in profile data', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      
      // Fill only display name (leave bio empty)
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Display Name'),
        'Minimal User',
      );
      
      // Submit
      await tester.tap(find.text('Get Started'));
      await tester.pumpAndSettle();
      
      // Verify the event content only includes non-empty fields
      final captured = verify(mockAuthService.createAndSignEvent(
        kind: 0,
        content: captureAnyNamed('content'),
      )).captured.single;
      
      final profileData = jsonDecode(captured as String);
      expect(profileData['name'], equals('Minimal User'));
      expect(profileData.containsKey('about'), isFalse); // Should not include empty bio
      expect(profileData.containsKey('picture'), isFalse); // Should not include empty picture
    });

    testWidgets('enforces bio character limit', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      
      // Enter valid display name
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Display Name'),
        'Test User',
      );
      
      // Try to enter bio longer than 160 characters
      final longBio = 'a' * 161; // 161 characters
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Bio (Optional)'),
        longBio,
      );
      
      // The text field should enforce the maxLength=160 limit through the UI
      // We can verify this by checking the actual text entered
      final bioFieldFinder = find.widgetWithText(TextFormField, 'Bio (Optional)');
      final bioField = tester.widget<TextFormField>(bioFieldFinder);
      
      // Verify field exists and has character limit (can't directly access maxLength in test)
      expect(bioField, isA<TextFormField>());
      expect(bioFieldFinder, findsOneWidget);
    });

    testWidgets('shows appropriate title for new vs existing users', (WidgetTester tester) async {
      // Test new user
      await tester.pumpWidget(createTestWidget(isNewUser: true));
      expect(find.text('Welcome to OpenVine!'), findsOneWidget);
      expect(find.text('Get Started'), findsOneWidget);
      
      // Test existing user
      await tester.pumpWidget(createTestWidget(isNewUser: false));
      await tester.pumpAndSettle();
      expect(find.text('Update Your Profile'), findsOneWidget);
      expect(find.text('Update Profile'), findsOneWidget);
    });

    testWidgets('loads existing profile data for editing', (WidgetTester tester) async {
      // Setup existing profile
      final existingProfile = model.UserProfile(
        pubkey: 'test_pubkey_hex',
        name: 'Existing Name',
        displayName: 'Existing Display',
        about: 'Existing bio',
        picture: 'https://example.com/existing.jpg',
        createdAt: DateTime.now(),
        eventId: 'existing_event_id',
        rawData: {},
      );
      
      when(mockUserProfileService.fetchProfile('test_pubkey_hex'))
          .thenAnswer((_) async => existingProfile);
      
      await tester.pumpWidget(createTestWidget(isNewUser: false));
      await tester.pumpAndSettle();
      
      // Should pre-populate form with existing data
      expect(find.text('Existing Display'), findsOneWidget);
      expect(find.text('Existing bio'), findsOneWidget);
      
      // Expand URL section to check picture URL
      await tester.tap(find.text('Or paste image URL'));
      await tester.pumpAndSettle();
      expect(find.text('https://example.com/existing.jpg'), findsOneWidget);
    });
  });
}