// ABOUTME: Widget tests for username field in ProfileSetupScreen
// ABOUTME: Tests status indicators, pre-population, and validation behavior

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/profile_editor/profile_editor_bloc.dart';
import 'package:openvine/screens/profile_setup_screen.dart';
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
    Widget buildIndicator(
      UsernameStatus status, {
      UsernameValidationError? error,
    }) {
      return MaterialApp(
        theme: VineTheme.theme,
        home: Scaffold(
          body: UsernameStatusIndicator(status: status, error: error),
        ),
      );
    }

    testWidgets('shows nothing when status is idle', (tester) async {
      await tester.pumpWidget(buildIndicator(UsernameStatus.idle));

      expect(find.text('Checking availability...'), findsNothing);
      expect(find.text('Username available!'), findsNothing);
      expect(find.text('Username already taken'), findsNothing);
      expect(find.text('Username is reserved'), findsNothing);
    });

    testWidgets('shows spinner when checking', (tester) async {
      await tester.pumpWidget(buildIndicator(UsernameStatus.checking));

      expect(find.text('Checking availability...'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows green checkmark when available', (tester) async {
      await tester.pumpWidget(buildIndicator(UsernameStatus.available));

      expect(find.text('Username available!'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
    });

    testWidgets('shows red X when taken', (tester) async {
      await tester.pumpWidget(buildIndicator(UsernameStatus.taken));

      expect(find.text('Username already taken'), findsOneWidget);
      expect(find.byIcon(Icons.cancel), findsOneWidget);
    });

    testWidgets('shows reserved indicator when status is reserved', (
      tester,
    ) async {
      await tester.pumpWidget(buildIndicator(UsernameStatus.reserved));

      expect(find.text('Username is reserved'), findsOneWidget);
      expect(find.byIcon(Icons.lock), findsOneWidget);
    });

    testWidgets('shows error message when network error', (tester) async {
      await tester.pumpWidget(
        buildIndicator(
          UsernameStatus.error,
          error: UsernameValidationError.networkError,
        ),
      );

      expect(
        find.text('Could not check availability. Please try again.'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });

    testWidgets('shows default error message when no error provided', (
      tester,
    ) async {
      await tester.pumpWidget(buildIndicator(UsernameStatus.error));

      expect(find.text('Failed to check availability'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });

    testWidgets('shows format error message', (tester) async {
      await tester.pumpWidget(
        buildIndicator(
          UsernameStatus.error,
          error: UsernameValidationError.invalidFormat,
        ),
      );

      expect(
        find.text('Only letters, numbers, and hyphens are allowed'),
        findsOneWidget,
      );
    });

    testWidgets('shows length error message', (tester) async {
      await tester.pumpWidget(
        buildIndicator(
          UsernameStatus.error,
          error: UsernameValidationError.invalidLength,
        ),
      );

      expect(find.text('Username must be 3-20 characters'), findsOneWidget);
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
