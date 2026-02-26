// ABOUTME: Tests for the settings screen layout, sections, and conditional
// ABOUTME: rendering based on authentication state

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/screens/settings_screen.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/bug_report_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockAuthService extends Mock implements AuthService {}

class _MockBugReportService extends Mock implements BugReportService {}

void main() {
  late _MockAuthService mockAuthService;
  late _MockBugReportService mockBugReportService;
  late SharedPreferences sharedPreferences;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    sharedPreferences = await SharedPreferences.getInstance();
    mockAuthService = _MockAuthService();
    mockBugReportService = _MockBugReportService();

    // Default mock behaviors
    when(() => mockAuthService.isAuthenticated).thenReturn(true);
    when(() => mockAuthService.isAnonymous).thenReturn(false);
    when(() => mockAuthService.currentPublicKeyHex).thenReturn('test_pubkey');
    when(() => mockAuthService.authState).thenReturn(AuthState.authenticated);
    when(
      () => mockAuthService.authStateStream,
    ).thenAnswer((_) => Stream.value(AuthState.authenticated));
  });

  Widget createTestWidget({AuthState authState = AuthState.authenticated}) {
    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(sharedPreferences),
        authServiceProvider.overrideWithValue(mockAuthService),
        currentAuthStateProvider.overrideWithValue(authState),
        bugReportServiceProvider.overrideWithValue(mockBugReportService),
      ],
      child: MaterialApp(theme: VineTheme.theme, home: const SettingsScreen()),
    );
  }

  group('SettingsScreen Layout', () {
    testWidgets('renders Settings title in app bar', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Settings'), findsOneWidget);
    });

    testWidgets('renders About section with Version tile', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('ABOUT'), findsOneWidget);
      expect(find.text('Version'), findsOneWidget);
    });

    testWidgets('renders Preferences section tiles', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('PREFERENCES'), findsOneWidget);
      expect(find.text('Notifications'), findsOneWidget);
      expect(find.text('Manage notification preferences'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('Safety & Privacy'),
        100,
        scrollable: find.byType(Scrollable),
      );
      expect(find.text('Safety & Privacy'), findsOneWidget);
    });

    testWidgets('renders Network section tiles', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('NETWORK'),
        100,
        scrollable: find.byType(Scrollable),
      );
      expect(find.text('NETWORK'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('Relays'),
        100,
        scrollable: find.byType(Scrollable),
      );
      expect(find.text('Relays'), findsOneWidget);
      expect(find.text('Manage Nostr relay connections'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('Relay Diagnostics'),
        100,
        scrollable: find.byType(Scrollable),
      );
      expect(find.text('Relay Diagnostics'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('Media Servers'),
        100,
        scrollable: find.byType(Scrollable),
      );
      expect(find.text('Media Servers'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('Developer Options'),
        100,
        scrollable: find.byType(Scrollable),
      );
      expect(find.text('Developer Options'), findsOneWidget);
    });

    testWidgets('renders Support section tiles', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('SUPPORT'),
        100,
        scrollable: find.byType(Scrollable),
      );
      expect(find.text('SUPPORT'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('Contact Support'),
        100,
        scrollable: find.byType(Scrollable),
      );
      expect(find.text('Contact Support'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('ProofMode Info'),
        100,
        scrollable: find.byType(Scrollable),
      );
      expect(find.text('ProofMode Info'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('Save Logs'),
        100,
        scrollable: find.byType(Scrollable),
      );
      expect(find.text('Save Logs'), findsOneWidget);
    });
  });

  group('SettingsScreen Authentication-Dependent Sections', () {
    testWidgets('renders Profile section when authenticated', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('PROFILE'), findsOneWidget);
      expect(find.text('Switch Account'), findsOneWidget);
    });

    testWidgets('renders Secure Your Account tile for anonymous users', (
      tester,
    ) async {
      when(() => mockAuthService.isAnonymous).thenReturn(true);

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Secure Your Account'), findsOneWidget);
      expect(
        find.text('Add email & password to recover your account on any device'),
        findsOneWidget,
      );
    });

    testWidgets(
      'hides Secure Your Account for non-anonymous authenticated users',
      (tester) async {
        when(() => mockAuthService.isAnonymous).thenReturn(false);

        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        expect(find.text('Secure Your Account'), findsNothing);
      },
    );

    testWidgets(
      'renders Advanced Account Options and Danger Zone when authenticated',
      (tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        await tester.scrollUntilVisible(
          find.text('ADVANCED ACCOUNT OPTIONS'),
          100,
          scrollable: find.byType(Scrollable),
        );
        expect(find.text('ADVANCED ACCOUNT OPTIONS'), findsOneWidget);

        await tester.scrollUntilVisible(
          find.text('Key Management'),
          100,
          scrollable: find.byType(Scrollable),
        );
        expect(find.text('Key Management'), findsOneWidget);
        expect(
          find.text('Export, backup, and restore your Nostr keys'),
          findsOneWidget,
        );

        await tester.scrollUntilVisible(
          find.text('Remove Keys from Device'),
          100,
          scrollable: find.byType(Scrollable),
        );
        expect(find.text('Remove Keys from Device'), findsOneWidget);

        await tester.scrollUntilVisible(
          find.text('DANGER ZONE'),
          100,
          scrollable: find.byType(Scrollable),
        );
        expect(find.text('DANGER ZONE'), findsOneWidget);

        await tester.scrollUntilVisible(
          find.text('Delete Account and Data'),
          100,
          scrollable: find.byType(Scrollable),
        );
        expect(find.text('Delete Account and Data'), findsOneWidget);
      },
    );

    testWidgets('hides Profile section when not authenticated', (tester) async {
      when(() => mockAuthService.isAuthenticated).thenReturn(false);
      when(() => mockAuthService.isAnonymous).thenReturn(false);

      await tester.pumpWidget(
        createTestWidget(authState: AuthState.unauthenticated),
      );
      await tester.pumpAndSettle();

      expect(find.text('PROFILE'), findsNothing);
      expect(find.text('Switch Account'), findsNothing);
    });

    testWidgets(
      'hides Advanced Account Options and Danger Zone when not authenticated',
      (tester) async {
        when(() => mockAuthService.isAuthenticated).thenReturn(false);
        when(() => mockAuthService.isAnonymous).thenReturn(false);

        await tester.pumpWidget(
          createTestWidget(authState: AuthState.unauthenticated),
        );
        await tester.pumpAndSettle();

        // Scroll to the bottom to confirm these sections are not present
        await tester.drag(find.byType(ListView), const Offset(0, -2000));
        await tester.pumpAndSettle();

        expect(find.text('ADVANCED ACCOUNT OPTIONS'), findsNothing);
        expect(find.text('DANGER ZONE'), findsNothing);
        expect(find.text('Key Management'), findsNothing);
        expect(find.text('Delete Account and Data'), findsNothing);
      },
    );
  });

  group('SettingsScreen Tile Subtitles', () {
    testWidgets('renders correct subtitles for Network tiles', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('Relays'),
        100,
        scrollable: find.byType(Scrollable),
      );
      expect(find.text('Manage Nostr relay connections'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('Relay Diagnostics'),
        100,
        scrollable: find.byType(Scrollable),
      );
      expect(
        find.text('Debug relay connectivity and network issues'),
        findsOneWidget,
      );

      await tester.scrollUntilVisible(
        find.text('Media Servers'),
        100,
        scrollable: find.byType(Scrollable),
      );
      expect(find.text('Configure Blossom upload servers'), findsOneWidget);
    });

    testWidgets('renders correct subtitles for Support tiles', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('Contact Support'),
        100,
        scrollable: find.byType(Scrollable),
      );
      expect(find.text('Get help or report an issue'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('ProofMode Info'),
        100,
        scrollable: find.byType(Scrollable),
      );
      expect(
        find.text('Learn about ProofMode verification and authenticity'),
        findsOneWidget,
      );

      await tester.scrollUntilVisible(
        find.text('Save Logs'),
        100,
        scrollable: find.byType(Scrollable),
      );
      expect(
        find.text('Export logs to file for manual sending'),
        findsOneWidget,
      );
    });
  });
}
