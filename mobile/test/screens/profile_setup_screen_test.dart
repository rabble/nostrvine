// ABOUTME: Widget tests for username field in ProfileSetupScreen
// ABOUTME: Tests status indicators, pre-population, and validation behavior

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/providers/username_notifier.dart';
import 'package:openvine/screens/profile_setup_screen.dart';
import 'package:openvine/state/username_state.dart';
import 'package:openvine/theme/vine_theme.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

class MockUrlLauncher extends Mock
    with MockPlatformInterfaceMixin
    implements UrlLauncherPlatform {}

class FakeLaunchOptions extends Fake implements LaunchOptions {}

void main() {
  setUpAll(() {
    registerFallbackValue(FakeLaunchOptions());
  });

  group('UsernameStatusIndicator', () {
    Widget buildIndicator(UsernameState state) {
      return MaterialApp(
        theme: VineTheme.theme,
        home: Scaffold(body: UsernameStatusIndicator(state: state)),
      );
    }

    testWidgets('shows nothing when status is idle', (tester) async {
      await tester.pumpWidget(
        buildIndicator(
          const UsernameState(username: '', status: UsernameCheckStatus.idle),
        ),
      );

      expect(find.text('Checking availability...'), findsNothing);
      expect(find.text('Username available!'), findsNothing);
      expect(find.text('Username already taken'), findsNothing);
      expect(find.text('Username is reserved'), findsNothing);
    });

    testWidgets('shows spinner when checking', (tester) async {
      await tester.pumpWidget(
        buildIndicator(
          const UsernameState(
            username: 'testuser',
            status: UsernameCheckStatus.checking,
          ),
        ),
      );

      expect(find.text('Checking availability...'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows green checkmark when available', (tester) async {
      await tester.pumpWidget(
        buildIndicator(
          const UsernameState(
            username: 'availableuser',
            status: UsernameCheckStatus.available,
          ),
        ),
      );

      expect(find.text('Username available!'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
    });

    testWidgets('shows red X when taken', (tester) async {
      await tester.pumpWidget(
        buildIndicator(
          const UsernameState(
            username: 'takenuser',
            status: UsernameCheckStatus.taken,
          ),
        ),
      );

      expect(find.text('Username already taken'), findsOneWidget);
      expect(find.byIcon(Icons.cancel), findsOneWidget);
    });

    testWidgets('shows reserved indicator when status is reserved', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildIndicator(
          const UsernameState(
            username: 'reserveduser',
            status: UsernameCheckStatus.reserved,
          ),
        ),
      );

      expect(find.text('Username is reserved'), findsOneWidget);
      expect(find.byIcon(Icons.lock), findsOneWidget);
    });

    testWidgets('shows error message when error', (tester) async {
      await tester.pumpWidget(
        buildIndicator(
          const UsernameState(
            username: 'erroruser',
            status: UsernameCheckStatus.error,
            errorMessage: 'Network error',
          ),
        ),
      );

      expect(find.text('Network error'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });
  });

  group('Username Validation Logic', () {
    test('allows valid usernames', () {
      expect(_isValidUsername('testuser'), isTrue);
      expect(_isValidUsername('test_user'), isTrue);
      expect(_isValidUsername('test-user'), isTrue);
      expect(_isValidUsername('test.user'), isTrue);
      expect(_isValidUsername('TestUser123'), isTrue);
    });

    test('rejects usernames that are too short', () {
      expect(_isValidUsername('ab'), isFalse);
      expect(_isValidUsername('a'), isFalse);
      expect(_isValidUsername(''), isFalse);
    });

    test('rejects usernames that are too long', () {
      expect(_isValidUsername('a' * (kMaxUsernameLength + 1)), isFalse);
      expect(_isValidUsername('a' * 30), isFalse);
    });

    test('rejects usernames with invalid characters', () {
      expect(_isValidUsername('user@name'), isFalse);
      expect(_isValidUsername('user name'), isFalse);
      expect(_isValidUsername('user!name'), isFalse);
      expect(_isValidUsername('user#name'), isFalse);
    });
  });

  group('NIP-05 Username Extraction', () {
    test('extracts username from @divine.video domain', () {
      expect(_extractUsername('testuser@divine.video'), equals('testuser'));
      expect(_extractUsername('my_user@divine.video'), equals('my_user'));
    });

    test('extracts username from legacy @openvine.co domain', () {
      expect(_extractUsername('legacyuser@openvine.co'), equals('legacyuser'));
    });

    test('returns null for external domains', () {
      expect(_extractUsername('user@nostr.com'), isNull);
      expect(_extractUsername('user@example.org'), isNull);
    });

    test('returns null for invalid formats', () {
      expect(_extractUsername('invalid'), isNull);
      expect(_extractUsername(''), isNull);
      expect(_extractUsername('user@'), isNull);
    });
  });

  group('UsernameReservedDialog', () {
    Widget buildDialog(String username) {
      return MaterialApp(
        theme: VineTheme.theme,
        home: Scaffold(body: UsernameReservedDialog(username)),
      );
    }

    testWidgets('shows correct title', (tester) async {
      await tester.pumpWidget(buildDialog('reservedname'));

      expect(find.text('Username reserved'), findsOneWidget);
    });

    testWidgets('shows username in message content', (tester) async {
      const username = 'reservedname';
      await tester.pumpWidget(buildDialog(username));

      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is RichText &&
              widget.text.toPlainText().contains(username),
        ),
        findsOneWidget,
      );
    });

    testWidgets('shows email address in message content', (tester) async {
      await tester.pumpWidget(buildDialog('reservedname'));

      expect(find.text('names@divine.video'), findsOneWidget);
    });

    testWidgets('has Close button as TextButton', (tester) async {
      await tester.pumpWidget(buildDialog('reservedname'));

      final closeButton = find.widgetWithText(TextButton, 'Close');
      expect(closeButton, findsOneWidget);
    });

    testWidgets('Close button dismisses dialog', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: VineTheme.theme,
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => const UsernameReservedDialog('testuser'),
                ),
                child: const Text('Show Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();
      expect(find.text('Username reserved'), findsOneWidget);

      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();

      expect(find.text('Username reserved'), findsNothing);
    });

    testWidgets('tapping email link calls launchUrl with mailto URI', (
      tester,
    ) async {
      final mockUrlLauncher = MockUrlLauncher();
      UrlLauncherPlatform.instance = mockUrlLauncher;

      when(
        () => mockUrlLauncher.launchUrl(any(), any()),
      ).thenAnswer((_) async => true);

      const username = 'reservedname';
      await tester.pumpWidget(buildDialog(username));

      await tester.tap(find.text('names@divine.video'));
      await tester.pumpAndSettle();

      final expectedUri = Uri.parse(
        'mailto:names@divine.video?subject=Reserved username request: $username',
      );
      verify(
        () => mockUrlLauncher.launchUrl(expectedUri.toString(), any()),
      ).called(1);
    });

    testWidgets('shows snackbar when email launch fails', (tester) async {
      final mockUrlLauncher = MockUrlLauncher();
      UrlLauncherPlatform.instance = mockUrlLauncher;

      when(
        () => mockUrlLauncher.launchUrl(any(), any()),
      ).thenAnswer((_) async => false);

      await tester.pumpWidget(buildDialog('reservedname'));

      await tester.tap(find.text('names@divine.video'));
      await tester.pumpAndSettle();

      expect(
        find.text("Couldn't open email. Send to: names@divine.video"),
        findsOneWidget,
      );
    });
  });
}

/// Validation logic matching ProfileSetupScreen
bool _isValidUsername(String username) {
  final regex = RegExp(r'^[a-z0-9\-_.]+$', caseSensitive: false);
  return regex.hasMatch(username) &&
      username.length >= kMinUsernameLength &&
      username.length <= kMaxUsernameLength;
}

/// Username extraction logic matching ProfileSetupScreen
String? _extractUsername(String? nip05) {
  if (nip05 == null || nip05.isEmpty) return null;

  if (nip05.endsWith('@divine.video') || nip05.endsWith('@openvine.co')) {
    final parts = nip05.split('@');
    if (parts.length == 2) {
      return parts[0];
    }
  }
  return null;
}
