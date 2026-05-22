// ABOUTME: Widget tests for MessageInputBar.
// ABOUTME: Tests rendering of text field, send button visibility,
// ABOUTME: send/clear interactions, and the markdown formatting items
// ABOUTME: in the text-selection context menu.

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
            home: Scaffold(body: MessageInputBar(onSend: (_) {})),
          ),
        );

        final l10n = lookupAppLocalizations(const Locale('en'));
        expect(find.byType(TextField), findsOneWidget);
        expect(find.text(l10n.dmMessageInputHint), findsOneWidget);
      });

      testWidgets('does not render send button when text is empty', (
        tester,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: MessageInputBar(onSend: (_) {})),
          ),
        );

        expect(find.byType(DivineIcon), findsNothing);
      });

      testWidgets('renders send button after text is entered', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: MessageInputBar(onSend: (_) {})),
          ),
        );

        await tester.enterText(find.byType(TextField), 'Hello');
        await tester.pump();

        expect(find.byType(DivineIcon), findsOneWidget);
      });
    });

    group('interactions', () {
      testWidgets('calls onSend with trimmed text when send button is tapped', (
        tester,
      ) async {
        String? sentText;

        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: MessageInputBar(onSend: (text) => sentText = text),
            ),
          ),
        );

        await tester.enterText(find.byType(TextField), '  Hello  ');
        await tester.pump();

        await tester.tap(find.byType(DivineIcon));
        await tester.pump();

        expect(sentText, equals('Hello'));
      });

      testWidgets('clears text field after sending', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: MessageInputBar(onSend: (_) {})),
          ),
        );

        await tester.enterText(find.byType(TextField), 'Hello');
        await tester.pump();

        await tester.tap(find.byType(DivineIcon));
        await tester.pump();

        final textField = tester.widget<TextField>(find.byType(TextField));

        expect(textField.controller!.text, equals(''));
      });

      testWidgets('does not call onSend when text is whitespace only', (
        tester,
      ) async {
        var sendCalled = false;

        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: MessageInputBar(onSend: (_) => sendCalled = true),
            ),
          ),
        );

        await tester.enterText(find.byType(TextField), '   ');
        await tester.pump();

        // Send button should not appear for whitespace-only input.
        expect(find.byType(DivineIcon), findsNothing);
        expect(sendCalled, isFalse);
      });
    });

    group('selection toolbar', () {
      /// Pumps the input bar, enters [seedText], selects the range
      /// `[selStart, selEnd]`, and invokes the TextField's
      /// `contextMenuBuilder`. Returns the resolved widget tree plus the
      /// `EditableTextState` and `TextEditingController` so individual
      /// tests can drive button taps and inspect controller state.
      Future<
        ({
          Widget toolbar,
          EditableTextState state,
          TextEditingController controller,
          AppLocalizations l10n,
        })
      >
      pumpAndBuildToolbar(
        WidgetTester tester, {
        required String seedText,
        required int selStart,
        required int selEnd,
      }) async {
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: MessageInputBar(onSend: (_) {})),
          ),
        );

        final textFieldFinder = find.byType(TextField);
        await tester.enterText(textFieldFinder, seedText);
        await tester.pump();

        final state = tester.state<EditableTextState>(
          find.byType(EditableText),
        );
        state.userUpdateTextEditingValue(
          state.textEditingValue.copyWith(
            selection: TextSelection(
              baseOffset: selStart,
              extentOffset: selEnd,
            ),
          ),
          SelectionChangedCause.toolbar,
        );
        await tester.pump();

        final textField = tester.widget<TextField>(textFieldFinder);
        final builder = textField.contextMenuBuilder!;
        final element = tester.element(textFieldFinder);
        final toolbar = builder(element, state);
        return (
          toolbar: toolbar,
          state: state,
          controller: textField.controller!,
          l10n: AppLocalizations.of(element),
        );
      }

      testWidgets('omits formatting items when selection is collapsed', (
        tester,
      ) async {
        final harness = await pumpAndBuildToolbar(
          tester,
          seedText: 'hello',
          selStart: 3,
          selEnd: 3,
        );
        final toolbar = harness.toolbar as AdaptiveTextSelectionToolbar;
        final labels = toolbar.buttonItems!.map((item) => item.label).toList();
        expect(labels, isNot(contains(harness.l10n.dmFormatBold)));
        expect(labels, isNot(contains(harness.l10n.dmFormatItalic)));
        expect(labels, isNot(contains(harness.l10n.dmFormatStrikethrough)));
        expect(labels, isNot(contains(harness.l10n.dmFormatCode)));
      });

      testWidgets(
        'prepends Bold/Italic/Strikethrough/Code when selection is non-empty',
        (tester) async {
          final harness = await pumpAndBuildToolbar(
            tester,
            seedText: 'hello world',
            selStart: 0,
            selEnd: 5,
          );
          final toolbar = harness.toolbar as AdaptiveTextSelectionToolbar;
          final labels = toolbar.buttonItems!
              .map((item) => item.label)
              .toList();
          expect(labels.take(4), [
            harness.l10n.dmFormatBold,
            harness.l10n.dmFormatItalic,
            harness.l10n.dmFormatStrikethrough,
            harness.l10n.dmFormatCode,
          ]);
        },
      );

      testWidgets('Bold wraps the selection with **', (tester) async {
        final harness = await pumpAndBuildToolbar(
          tester,
          seedText: 'say hi please',
          selStart: 4,
          selEnd: 6,
        );
        final toolbar = harness.toolbar as AdaptiveTextSelectionToolbar;
        toolbar.buttonItems!.first.onPressed!();
        await tester.pump();
        expect(harness.controller.text, equals('say **hi** please'));
      });

      testWidgets('Italic wraps the selection with _', (tester) async {
        final harness = await pumpAndBuildToolbar(
          tester,
          seedText: 'be _ kind',
          selStart: 0,
          selEnd: 2,
        );
        final toolbar = harness.toolbar as AdaptiveTextSelectionToolbar;
        toolbar.buttonItems![1].onPressed!();
        await tester.pump();
        expect(harness.controller.text, equals('_be_ _ kind'));
      });

      testWidgets('Strikethrough wraps the selection with ~~', (tester) async {
        final harness = await pumpAndBuildToolbar(
          tester,
          seedText: 'gone now',
          selStart: 0,
          selEnd: 4,
        );
        final toolbar = harness.toolbar as AdaptiveTextSelectionToolbar;
        toolbar.buttonItems![2].onPressed!();
        await tester.pump();
        expect(harness.controller.text, equals('~~gone~~ now'));
      });

      testWidgets('Code wraps the selection with `', (tester) async {
        final harness = await pumpAndBuildToolbar(
          tester,
          seedText: 'use foo() here',
          selStart: 4,
          selEnd: 9,
        );
        final toolbar = harness.toolbar as AdaptiveTextSelectionToolbar;
        toolbar.buttonItems![3].onPressed!();
        await tester.pump();
        expect(harness.controller.text, equals('use `foo()` here'));
      });

      testWidgets(
        'Bold on already-bold selection unwraps the surrounding **',
        (tester) async {
          // `**hi**` — select just the inner `hi` so the surrounding
          // `**` markers can be detected and stripped.
          final harness = await pumpAndBuildToolbar(
            tester,
            seedText: 'say **hi** please',
            selStart: 6,
            selEnd: 8,
          );
          final toolbar = harness.toolbar as AdaptiveTextSelectionToolbar;
          toolbar.buttonItems!.first.onPressed!();
          await tester.pump();
          expect(harness.controller.text, equals('say hi please'));
        },
      );

      testWidgets(
        'selection labels resolve from l10n, not hardcoded English',
        (tester) async {
          // Sanity guard against accidentally hardcoding the label —
          // if the widget ever stops reading from context.l10n, this
          // test breaks loudly.
          final harness = await pumpAndBuildToolbar(
            tester,
            seedText: 'hello',
            selStart: 0,
            selEnd: 5,
          );
          final toolbar = harness.toolbar as AdaptiveTextSelectionToolbar;
          final labels = toolbar.buttonItems!.take(4).map((b) => b.label);
          expect(labels, [
            lookupAppLocalizations(const Locale('en')).dmFormatBold,
            lookupAppLocalizations(const Locale('en')).dmFormatItalic,
            lookupAppLocalizations(const Locale('en')).dmFormatStrikethrough,
            lookupAppLocalizations(const Locale('en')).dmFormatCode,
          ]);
        },
      );
    });
  });
}
