// ABOUTME: Tests for relay settings screen functionality including adding/removing relays
// ABOUTME: Verifies relay status display, persistence, and connection management

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:provider/provider.dart';
import 'package:openvine/screens/relay_settings_screen.dart';
import 'package:openvine/services/nostr_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

@GenerateMocks([NostrService])
import 'relay_settings_screen_test.mocks.dart';

void main() {
  group('RelaySettingsScreen', () {
    late MockNostrService mockNostrService;
    
    setUp(() {
      mockNostrService = MockNostrService();
      
      // Setup default mocks
      when(mockNostrService.relays).thenReturn([
        'wss://relay.damus.io',
        'wss://nos.lol',
      ]);
      
      when(mockNostrService.relayStatuses).thenReturn({
        'wss://relay.damus.io': RelayStatus.connected,
        'wss://nos.lol': RelayStatus.connecting,
      });
    });

    Widget createTestWidget() {
      return MaterialApp(
        home: Provider<NostrService>.value(
          value: mockNostrService,
          child: const RelaySettingsScreen(),
        ),
      );
    }

    testWidgets('displays relay settings screen with app bar', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      
      expect(find.text('Relay Settings'), findsOneWidget);
      expect(find.byIcon(Icons.dns), findsOneWidget);
    });

    testWidgets('displays list of relays with their status', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      
      expect(find.text('wss://relay.damus.io'), findsOneWidget);
      expect(find.text('wss://nos.lol'), findsOneWidget);
      
      // Check for status indicators
      expect(find.byIcon(Icons.check_circle), findsOneWidget); // Connected
      expect(find.byType(CircularProgressIndicator), findsOneWidget); // Connecting
    });

    testWidgets('allows adding a new relay', (WidgetTester tester) async {
      when(mockNostrService.addRelay(any)).thenAnswer((_) async => true);
      
      await tester.pumpWidget(createTestWidget());
      
      // Tap add button
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();
      
      // Find dialog
      expect(find.text('Add Relay'), findsOneWidget);
      
      // Enter relay URL
      await tester.enterText(find.byType(TextField), 'wss://new.relay.com');
      
      // Tap add button in dialog
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();
      
      // Verify addRelay was called
      verify(mockNostrService.addRelay('wss://new.relay.com')).called(1);
    });

    testWidgets('validates relay URL format', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      
      // Open add relay dialog
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();
      
      // Enter invalid URL
      await tester.enterText(find.byType(TextField), 'invalid-url');
      
      // Tap add button
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();
      
      // Should show error
      expect(find.text('Invalid relay URL format'), findsOneWidget);
    });

    testWidgets('allows removing a relay', (WidgetTester tester) async {
      when(mockNostrService.removeRelay(any)).thenAnswer((_) async => true);
      
      await tester.pumpWidget(createTestWidget());
      
      // Find remove button for first relay
      final removeButtons = find.byIcon(Icons.remove_circle_outline);
      await tester.tap(removeButtons.first);
      await tester.pumpAndSettle();
      
      // Confirm dialog
      expect(find.text('Remove Relay'), findsOneWidget);
      
      // Tap remove in confirmation
      await tester.tap(find.text('Remove'));
      await tester.pumpAndSettle();
      
      // Verify removeRelay was called
      verify(mockNostrService.removeRelay('wss://relay.damus.io')).called(1);
    });

    testWidgets('shows error when relay operation fails', (WidgetTester tester) async {
      when(mockNostrService.addRelay(any)).thenAnswer((_) async => false);
      
      await tester.pumpWidget(createTestWidget());
      
      // Try to add relay
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();
      
      await tester.enterText(find.byType(TextField), 'wss://test.relay.com');
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();
      
      // Should show error snackbar
      expect(find.text('Failed to add relay'), findsOneWidget);
    });

    testWidgets('refreshes relay statuses on pull to refresh', (WidgetTester tester) async {
      when(mockNostrService.reconnectAll()).thenAnswer((_) async => {});
      
      await tester.pumpWidget(createTestWidget());
      
      // Pull to refresh
      await tester.fling(find.byType(ListView), const Offset(0, 300), 1000);
      await tester.pumpAndSettle();
      
      // Verify reconnectAll was called
      verify(mockNostrService.reconnectAll()).called(1);
    });

    testWidgets('displays help text about relay connectivity', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      
      // Find help icon button
      await tester.tap(find.byIcon(Icons.help_outline));
      await tester.pumpAndSettle();
      
      // Should show help dialog
      expect(find.text('About Relays'), findsOneWidget);
      expect(find.textContaining('Relays are servers'), findsOneWidget);
    });

    testWidgets('handles duplicate relay addition', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      
      // Try to add existing relay
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();
      
      await tester.enterText(find.byType(TextField), 'wss://relay.damus.io');
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();
      
      // Should show error about duplicate
      expect(find.text('Relay already exists'), findsOneWidget);
    });
  });
}