// ABOUTME: Widget tests for MessageBubble.
// ABOUTME: Tests rendering of message text, timestamp visibility,
// ABOUTME: alignment for sent vs received messages, URL linkification,
// ABOUTME: and long-press callback.

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/screens/inbox/conversation/widgets/message_bubble.dart';

void main() {
  group(MessageBubble, () {
    group('renders', () {
      testWidgets('renders message text', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: MessageBubble(
                message: 'Hello there',
                timestamp: '2:30 PM',
                isSent: true,
              ),
            ),
          ),
        );

        expect(find.text('Hello there'), findsOneWidget);
      });

      testWidgets(
        'renders timestamp when isFirstInGroup is true',
        (tester) async {
          await tester.pumpWidget(
            const MaterialApp(
              home: Scaffold(
                body: MessageBubble(
                  message: 'Hello there',
                  timestamp: '2:30 PM',
                  isSent: true,
                ),
              ),
            ),
          );

          expect(find.text('2:30 PM'), findsOneWidget);
        },
      );

      testWidgets(
        'does not render timestamp when isFirstInGroup is false',
        (tester) async {
          await tester.pumpWidget(
            const MaterialApp(
              home: Scaffold(
                body: MessageBubble(
                  message: 'Hello there',
                  timestamp: '2:30 PM',
                  isSent: true,
                  isFirstInGroup: false,
                ),
              ),
            ),
          );

          expect(find.text('2:30 PM'), findsNothing);
        },
      );

      testWidgets('aligns right for sent messages', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: MessageBubble(
                message: 'Sent message',
                timestamp: '2:30 PM',
                isSent: true,
              ),
            ),
          ),
        );

        final align = tester.widget<Align>(find.byType(Align));

        expect(align.alignment, equals(Alignment.centerRight));
      });

      testWidgets('aligns left for received messages', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: MessageBubble(
                message: 'Received message',
                timestamp: '2:30 PM',
                isSent: false,
              ),
            ),
          ),
        );

        final align = tester.widget<Align>(find.byType(Align));

        expect(align.alignment, equals(Alignment.centerLeft));
      });
    });

    group('URL linkification', () {
      testWidgets('renders plain text without $RichText', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: MessageBubble(
                message: 'No links here',
                timestamp: '2:30 PM',
                isSent: true,
              ),
            ),
          ),
        );

        expect(find.text('No links here'), findsOneWidget);
      });

      testWidgets('renders URL as tappable rich text', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: MessageBubble(
                message: 'Check https://divine.video/video/abc123',
                timestamp: '2:30 PM',
                isSent: true,
              ),
            ),
          ),
        );

        final richTextFinder = find.byWidgetPredicate(
          (widget) =>
              widget is RichText &&
              widget.text.toPlainText().contains('https://divine.video'),
        );
        expect(richTextFinder, findsOneWidget);
      });

      testWidgets('URL span has $TapGestureRecognizer', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: MessageBubble(
                message: 'Visit https://example.com today',
                timestamp: '2:30 PM',
                isSent: false,
              ),
            ),
          ),
        );

        final richText = tester.widget<RichText>(
          find.byWidgetPredicate(
            (widget) =>
                widget is RichText &&
                widget.text.toPlainText().contains('https://example.com'),
          ),
        );

        final textSpan = richText.text as TextSpan;
        // Text.rich wraps our TextSpan in a parent; unwrap to reach
        // the actual URL spans built by _MessageText.
        final innerSpan = textSpan.children!.first as TextSpan;
        final urlSpan =
            innerSpan.children!.firstWhere(
                  (span) =>
                      span is TextSpan &&
                      (span.text?.contains('https://example.com') ?? false),
                )
                as TextSpan;

        expect(urlSpan.recognizer, isA<TapGestureRecognizer>());
      });

      testWidgets('renders multiple URLs in one message', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: MessageBubble(
                message:
                    'See https://divine.video/terms and '
                    'https://divine.video/support',
                timestamp: '2:30 PM',
                isSent: true,
              ),
            ),
          ),
        );

        final richText = tester.widget<RichText>(
          find.byWidgetPredicate(
            (widget) =>
                widget is RichText &&
                widget.text.toPlainText().contains('divine.video'),
          ),
        );

        final textSpan = richText.text as TextSpan;
        final innerSpan = textSpan.children!.first as TextSpan;
        final urlSpans = innerSpan.children!
            .whereType<TextSpan>()
            .where((s) => s.recognizer is TapGestureRecognizer)
            .toList();

        expect(urlSpans, hasLength(2));
      });

      testWidgets('renders bare domain as tappable link', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: MessageBubble(
                message: 'Visit google.com for info',
                timestamp: '2:30 PM',
                isSent: true,
              ),
            ),
          ),
        );

        final richText = tester.widget<RichText>(
          find.byWidgetPredicate(
            (widget) =>
                widget is RichText &&
                widget.text.toPlainText().contains('google.com'),
          ),
        );

        final textSpan = richText.text as TextSpan;
        final innerSpan = textSpan.children!.first as TextSpan;
        final urlSpan =
            innerSpan.children!.firstWhere(
                  (span) =>
                      span is TextSpan &&
                      (span.text?.contains('google.com') ?? false),
                )
                as TextSpan;

        expect(urlSpan.recognizer, isA<TapGestureRecognizer>());
      });

      testWidgets(
        'renders bare domain with path as tappable link',
        (tester) async {
          await tester.pumpWidget(
            const MaterialApp(
              home: Scaffold(
                body: MessageBubble(
                  message: 'Check example.com/page today',
                  timestamp: '2:30 PM',
                  isSent: true,
                ),
              ),
            ),
          );

          final richText = tester.widget<RichText>(
            find.byWidgetPredicate(
              (widget) =>
                  widget is RichText &&
                  widget.text.toPlainText().contains('example.com/page'),
            ),
          );

          final textSpan = richText.text as TextSpan;
          final innerSpan = textSpan.children!.first as TextSpan;
          final urlSpan =
              innerSpan.children!.firstWhere(
                    (span) =>
                        span is TextSpan &&
                        (span.text?.contains('example.com/page') ?? false),
                  )
                  as TextSpan;

          expect(urlSpan.recognizer, isA<TapGestureRecognizer>());
        },
      );

      testWidgets(
        'renders email address as tappable link',
        (tester) async {
          await tester.pumpWidget(
            const MaterialApp(
              home: Scaffold(
                body: MessageBubble(
                  message: 'Email me at user@example.com please',
                  timestamp: '2:30 PM',
                  isSent: true,
                ),
              ),
            ),
          );

          final richText = tester.widget<RichText>(
            find.byWidgetPredicate(
              (widget) =>
                  widget is RichText &&
                  widget.text.toPlainText().contains('user@example.com'),
            ),
          );

          final textSpan = richText.text as TextSpan;
          final innerSpan = textSpan.children!.first as TextSpan;
          final emailSpan =
              innerSpan.children!.firstWhere(
                    (span) =>
                        span is TextSpan &&
                        (span.text?.contains('user@example.com') ?? false),
                  )
                  as TextSpan;

          expect(emailSpan.recognizer, isA<TapGestureRecognizer>());
        },
      );

      testWidgets('URL-only message renders as link', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: MessageBubble(
                message: 'https://divine.video/video/abc123',
                timestamp: '2:30 PM',
                isSent: true,
              ),
            ),
          ),
        );

        final richTextFinder = find.byWidgetPredicate(
          (widget) =>
              widget is RichText &&
              widget.text.toPlainText().contains('https://divine.video'),
        );
        expect(richTextFinder, findsOneWidget);
      });
    });

    group('long-press', () {
      testWidgets('calls onLongPress callback', (tester) async {
        var longPressed = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MessageBubble(
                message: 'Long press me',
                timestamp: '2:30 PM',
                isSent: true,
                onLongPress: () => longPressed = true,
              ),
            ),
          ),
        );

        await tester.longPress(find.text('Long press me'));
        await tester.pumpAndSettle();

        expect(longPressed, isTrue);
      });

      testWidgets('does not crash when onLongPress is null', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: MessageBubble(
                message: 'No callback',
                timestamp: '2:30 PM',
                isSent: true,
              ),
            ),
          ),
        );

        await tester.longPress(find.text('No callback'));
        await tester.pumpAndSettle();

        expect(find.text('No callback'), findsOneWidget);
      });
    });
  });
}
