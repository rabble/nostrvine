// ABOUTME: Widget tests for CommentInput component
// ABOUTME: Tests input field, send button, and posting state behavior

import 'package:flutter/foundation.dart';
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

    testWidgets('top-level comments use send as the keyboard action', (
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

      final textField = tester.widget<TextField>(find.byType(TextField));

      // The composer still supports bounded multiline layout; only the primary
      // keyboard action changes for top-level comments.
      expect(textField.keyboardType, TextInputType.multiline);
      expect(textField.textInputAction, TextInputAction.send);
      expect(textField.minLines, 1);
      expect(textField.maxLines, 5);
    });

    testWidgets('submits top-level comments from the keyboard action', (
      tester,
    ) async {
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

      final textField = tester.widget<TextField>(find.byType(TextField));
      // Invoke the callback directly so the test asserts our submit wiring
      // rather than platform text-input plumbing.
      textField.onSubmitted?.call('Test comment');

      expect(submitted, isTrue);
    });

    testWidgets('reply input keeps newline as the keyboard action', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: CommentInput(
              controller: controller,
              replyToDisplayName: 'alice',
              onCancelReply: () {},
              onSubmit: () {},
            ),
          ),
        ),
      );

      final textField = tester.widget<TextField>(find.byType(TextField));

      // Replies keep newline semantics so they can expand into multi-line
      // composition without submitting early.
      expect(textField.textInputAction, TextInputAction.newline);
      expect(textField.onSubmitted, isNull);
    });

    testWidgets('shows keyboard dismissal control while focused', (
      tester,
    ) async {
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: CommentInput(
              controller: controller,
              focusNode: focusNode,
              onSubmit: () {},
            ),
          ),
        ),
      );

      // The dismiss control should be focus-driven rather than permanently
      // visible, otherwise it competes with the send affordance when idle.
      expect(
        find.bySemanticsIdentifier('hide_comment_keyboard_button'),
        findsNothing,
      );

      focusNode.requestFocus();
      await tester.pump();

      expect(
        find.bySemanticsIdentifier('hide_comment_keyboard_button'),
        findsOneWidget,
      );
    });

    testWidgets(
      'tap inside the bubble but above the TextField keeps focus on iOS '
      '(regression: issue #3770)',
      (tester) async {
        // The visible "bubble" Container is taller than the inner TextField
        // because of vertical padding around the field. A tap that lands in
        // that padding strip is outside the TextField's TapRegion. With a
        // `onTapOutside: (_) => unfocus()` override on the TextField, that
        // tap dismissed the keyboard. The override has been removed; iOS's
        // default tap-outside action is a no-op for touch events, so focus
        // must be retained.
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        try {
          controller.text = 'hello typo wolrd';
          final focusNode = FocusNode();
          addTearDown(focusNode.dispose);

          await tester.pumpWidget(
            MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                // Mirror the production setup: the comment input lives
                // inside a sheet whose surface is wrapped in an opaque
                // GestureDetector that absorbs taps not claimed by an inner
                // widget. Without an opaque ancestor, taps in the bubble
                // padding don't register any hit and TapRegionSurface
                // short-circuits the event.
                body: Stack(
                  fit: StackFit.expand,
                  children: [
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {},
                    ),
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: CommentInput(
                        controller: controller,
                        focusNode: focusNode,
                        onSubmit: () {},
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );

          focusNode.requestFocus();
          await tester.pump();
          expect(focusNode.hasFocus, isTrue);

          // The bubble is the inner Container with `minHeight: 48` —
          // uniquely identifiable vs. the outer padding-only Container and
          // the SendButton's smaller circular Container.
          final bubbleFinder = find.byWidgetPredicate(
            (widget) =>
                widget is Container &&
                widget.constraints == const BoxConstraints(minHeight: 48),
          );
          expect(bubbleFinder, findsOneWidget);

          final bubbleRect = tester.getRect(bubbleFinder);
          final textFieldRect = tester.getRect(find.byType(TextField));
          expect(
            textFieldRect.top - bubbleRect.top,
            greaterThan(4),
            reason:
                'There must be padding above the TextField inside the '
                'bubble for this regression test to be meaningful.',
          );

          await tester.tapAt(
            Offset(bubbleRect.center.dx, bubbleRect.top + 4),
          );
          await tester.pump();

          expect(
            focusNode.hasFocus,
            isTrue,
            reason:
                'Tap inside the comment bubble (in the padding above the '
                'TextField) must not dismiss the keyboard. See issue #3770.',
          );
        } finally {
          debugDefaultTargetPlatformOverride = null;
        }
      },
    );
  });
}
