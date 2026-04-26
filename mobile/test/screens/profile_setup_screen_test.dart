// ABOUTME: Widget tests for username field in ProfileSetupScreen
// ABOUTME: Tests status indicators, pre-population, and validation behavior

import 'package:bloc_test/bloc_test.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/profile_editor/profile_editor_bloc.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/screens/profile_setup_screen.dart';

class _MockProfileEditorBloc
    extends MockBloc<ProfileEditorEvent, ProfileEditorState>
    implements ProfileEditorBloc {}

void main() {
  group('UsernameStatusIndicator', () {
    late _MockProfileEditorBloc mockBloc;

    setUp(() {
      mockBloc = _MockProfileEditorBloc();
      when(() => mockBloc.state).thenReturn(
        const ProfileEditorState(
          username: 'testuser',
          usernameStatus: UsernameStatus.reserved,
        ),
      );
    });

    Widget buildIndicator(
      UsernameStatus status, {
      UsernameValidationError? error,
    }) {
      return MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: VineTheme.theme,
        home: Scaffold(
          body: UsernameStatusIndicator(status: status, error: error),
        ),
      );
    }

    Widget buildIndicatorWithBloc(
      UsernameStatus status, {
      UsernameValidationError? error,
    }) {
      return MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: VineTheme.theme,
        home: BlocProvider<ProfileEditorBloc>.value(
          value: mockBloc,
          child: Scaffold(
            body: UsernameStatusIndicator(status: status, error: error),
          ),
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
      await tester.pumpWidget(buildIndicatorWithBloc(UsernameStatus.reserved));

      expect(find.text('Username is reserved'), findsOneWidget);
      expect(find.byIcon(Icons.lock), findsOneWidget);
    });

    testWidgets('shows Contact support link when reserved', (tester) async {
      await tester.pumpWidget(buildIndicatorWithBloc(UsernameStatus.reserved));

      expect(find.text('Contact support'), findsOneWidget);
    });

    testWidgets('shows Check again link when reserved', (tester) async {
      await tester.pumpWidget(buildIndicatorWithBloc(UsernameStatus.reserved));

      expect(find.text('Check again'), findsOneWidget);
    });

    testWidgets('Check again link adds $UsernameRechecked event', (
      tester,
    ) async {
      await tester.pumpWidget(buildIndicatorWithBloc(UsernameStatus.reserved));

      await tester.tap(find.text('Check again'));
      await tester.pumpAndSettle();

      verify(() => mockBloc.add(const UsernameRechecked())).called(1);
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
    late _MockProfileEditorBloc mockBloc;

    setUp(() {
      mockBloc = _MockProfileEditorBloc();
      when(() => mockBloc.state).thenReturn(
        const ProfileEditorState(
          username: 'reservedname',
          usernameStatus: UsernameStatus.reserved,
        ),
      );
    });

    Widget buildDialog(String username) {
      return MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: VineTheme.theme,
        home: BlocProvider<ProfileEditorBloc>.value(
          value: mockBloc,
          child: Scaffold(body: UsernameReservedDialog(username)),
        ),
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
        find.text(
          'The name $username is reserved. Tell us why it should be yours.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('has reason text field', (tester) async {
      await tester.pumpWidget(buildDialog('reservedname'));

      expect(find.byType(TextField), findsOneWidget);
      expect(
        find.text("e.g. It's my brand name, stage name, etc."),
        findsOneWidget,
      );
    });

    testWidgets('has Close button', (tester) async {
      await tester.pumpWidget(buildDialog('reservedname'));

      final closeButton = find.widgetWithText(TextButton, 'Close');
      expect(closeButton, findsOneWidget);
    });

    testWidgets('has Send request button', (tester) async {
      await tester.pumpWidget(buildDialog('reservedname'));

      expect(find.widgetWithText(FilledButton, 'Send request'), findsOneWidget);
    });

    testWidgets('has Check again button', (tester) async {
      await tester.pumpWidget(buildDialog('reservedname'));

      expect(find.widgetWithText(TextButton, 'Check again'), findsOneWidget);
    });

    testWidgets('Close button dismisses dialog', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: VineTheme.theme,
          home: BlocProvider<ProfileEditorBloc>.value(
            value: mockBloc,
            child: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => BlocProvider<ProfileEditorBloc>.value(
                      value: mockBloc,
                      child: const UsernameReservedDialog('testuser'),
                    ),
                  ),
                  child: const Text('Show Dialog'),
                ),
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

    testWidgets('Check again button adds $UsernameRechecked event', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: VineTheme.theme,
          home: BlocProvider<ProfileEditorBloc>.value(
            value: mockBloc,
            child: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => BlocProvider<ProfileEditorBloc>.value(
                      value: mockBloc,
                      child: const UsernameReservedDialog('testuser'),
                    ),
                  ),
                  child: const Text('Show Dialog'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(TextButton, 'Check again'));
      await tester.pumpAndSettle();

      verify(() => mockBloc.add(const UsernameRechecked())).called(1);
    });

    testWidgets('shows hint about checking again after contacting support', (
      tester,
    ) async {
      await tester.pumpWidget(buildDialog('reservedname'));

      expect(
        find.text(
          'Already contacted support? Tap "Check again" to see if '
          "it's been released to you.",
        ),
        findsOneWidget,
      );
    });
  });
}
