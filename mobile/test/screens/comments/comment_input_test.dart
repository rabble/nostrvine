// ABOUTME: Widget tests for CommentInput component
// ABOUTME: Tests input field, send button, and posting state behavior

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/screens/comments/comments.dart';

void main() {
  group('CommentInput', () {
    late TextEditingController controller;

    setUp(() {
      controller = TextEditingController();
    });

    tearDown(() {
      controller.dispose();
    });

    testWidgets('renders with hint text and no send button when empty', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: CommentInput(
              controller: controller,
              onSubmit: () {},
            ),
          ),
        ),
      );

      expect(find.text('Add comment...'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_upward), findsNothing);
    });

    testWidgets('shows send button when text is entered', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: CommentInput(
              controller: controller,
              onSubmit: () {},
            ),
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), 'Test comment');
      await tester.pump();

      expect(find.byIcon(Icons.arrow_upward), findsOneWidget);
    });

    testWidgets(
      'never shows a CircularProgressIndicator on the send button',
      (tester) async {
        // Per Alex's WhatsApp/Telegram-style ask, posting is optimistic at
        // the BLoC layer and the send button has no in-flight state.
        controller.text = 'Test comment';

        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: CommentInput(
                controller: controller,
                onSubmit: () {},
              ),
            ),
          ),
        );

        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(find.byIcon(Icons.arrow_upward), findsOneWidget);
      },
    );

    testWidgets('calls onSubmit when send tapped', (tester) async {
      var submitted = false;

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: CommentInput(
              controller: controller,
              onSubmit: () => submitted = true,
            ),
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), 'Test comment');
      await tester.pump();

      await tester.tap(find.byIcon(Icons.arrow_upward));
      await tester.pump();

      expect(submitted, isTrue);
    });

    testWidgets('allows text input', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: CommentInput(
              controller: controller,
              onSubmit: () {},
            ),
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), 'Test comment');
      await tester.pump();

      expect(controller.text, equals('Test comment'));
    });
  });
}
