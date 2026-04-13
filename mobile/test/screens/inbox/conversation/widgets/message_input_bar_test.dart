// ABOUTME: Widget tests for MessageInputBar.
// ABOUTME: Tests rendering of text field, send button visibility,
// ABOUTME: and send/clear interactions.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/screens/inbox/conversation/widgets/message_input_bar.dart';

void main() {
  group(MessageInputBar, () {
    group('renders', () {
      testWidgets('renders $TextField with hint text', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: MessageInputBar(onSend: (_) {}),
            ),
          ),
        );

        expect(find.byType(TextField), findsOneWidget);
        expect(find.text('Say something...'), findsOneWidget);
      });

      testWidgets(
        'does not render send button when text is empty',
        (tester) async {
          await tester.pumpWidget(
            MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: MessageInputBar(onSend: (_) {}),
              ),
            ),
          );

          expect(find.byType(DivineIcon), findsNothing);
        },
      );

      testWidgets(
        'renders send button after text is entered',
        (tester) async {
          await tester.pumpWidget(
            MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: MessageInputBar(onSend: (_) {}),
              ),
            ),
          );

          await tester.enterText(find.byType(TextField), 'Hello');
          await tester.pump();

          expect(find.byType(DivineIcon), findsOneWidget);
        },
      );
    });

    group('interactions', () {
      testWidgets(
        'calls onSend with trimmed text when send button is tapped',
        (tester) async {
          String? sentText;

          await tester.pumpWidget(
            MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: MessageInputBar(
                  onSend: (text) => sentText = text,
                ),
              ),
            ),
          );

          await tester.enterText(find.byType(TextField), '  Hello  ');
          await tester.pump();

          await tester.tap(find.byType(DivineIcon));
          await tester.pump();

          expect(sentText, equals('Hello'));
        },
      );

      testWidgets('clears text field after sending', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: MessageInputBar(onSend: (_) {}),
            ),
          ),
        );

        await tester.enterText(find.byType(TextField), 'Hello');
        await tester.pump();

        await tester.tap(find.byType(DivineIcon));
        await tester.pump();

        final textField = tester.widget<TextField>(find.byType(TextField));

        expect(textField.controller!.text, equals(''));
      });

      testWidgets(
        'does not call onSend when text is whitespace only',
        (tester) async {
          var sendCalled = false;

          await tester.pumpWidget(
            MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: MessageInputBar(
                  onSend: (_) => sendCalled = true,
                ),
              ),
            ),
          );

          await tester.enterText(find.byType(TextField), '   ');
          await tester.pump();

          // Send button should not appear for whitespace-only input.
          expect(find.byType(DivineIcon), findsNothing);
          expect(sendCalled, isFalse);
        },
      );
    });
  });
}
