// ABOUTME: Widget tests for MessageBubble.
// ABOUTME: Tests rendering of message text, timestamp visibility,
// ABOUTME: and alignment for sent vs received messages.

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
  });
}
