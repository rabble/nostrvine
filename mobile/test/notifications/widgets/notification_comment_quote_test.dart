// ABOUTME: Tests for NotificationCommentQuote — quoted text rendering and
// ABOUTME: optional inline timestamp suffix.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/notifications/widgets/notification_comment_quote.dart';

Future<void> _pump(
  WidgetTester tester, {
  required String text,
  String? timestamp,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: NotificationCommentQuote(text: text, timestamp: timestamp),
      ),
    ),
  );
}

TextSpan? _findSpan(
  TextSpan root, {
  required bool Function(TextSpan) matching,
}) {
  if (matching(root)) return root;
  for (final child in root.children ?? const <InlineSpan>[]) {
    if (child is TextSpan) {
      final found = _findSpan(child, matching: matching);
      if (found != null) return found;
    }
  }
  return null;
}

void main() {
  group(NotificationCommentQuote, () {
    testWidgets('wraps text in curly quotes', (tester) async {
      await _pump(tester, text: 'Hello world');

      expect(find.textContaining('“Hello world”'), findsOneWidget);
    });

    testWidgets('appends timestamp inline when non-empty', (tester) async {
      await _pump(tester, text: 'Hello world', timestamp: '2d');

      // The Text.rich concatenates to "“Hello world” 2d" — find.text
      // matches Text widgets by their concatenated plaintext.
      expect(find.text('“Hello world” 2d'), findsOneWidget);
    });

    testWidgets('omits timestamp suffix when null', (tester) async {
      await _pump(tester, text: 'Hello world');

      expect(find.text('“Hello world”'), findsOneWidget);
    });

    testWidgets('omits timestamp suffix when empty string', (tester) async {
      await _pump(tester, text: 'Hello world', timestamp: '');

      expect(find.text('“Hello world”'), findsOneWidget);
    });

    testWidgets('caps at two lines for long quotes', (tester) async {
      // A long line will wrap; the widget's own maxLines should clamp.
      await _pump(
        tester,
        text:
            'This is a very long comment that will wrap to multiple lines '
            'when rendered in a constrained-width container, and we want to '
            'make sure the widget caps it at two lines.',
        timestamp: '5h',
      );

      final richText = tester.widget<RichText>(find.byType(RichText));
      expect(richText.maxLines, equals(2));
      expect(richText.overflow, equals(TextOverflow.ellipsis));
    });

    testWidgets('timestamp uses muted onSurfaceMuted55', (tester) async {
      await _pump(tester, text: 'Hi', timestamp: '2d');

      // Walk the rendered RichText's span tree to find the timestamp
      // suffix. Text.rich wraps our root TextSpan in another span to
      // apply the ambient text style, so our quote/timestamp children
      // sit one level deeper than the RichText's top-level children.
      final richText = tester.widget<RichText>(find.byType(RichText));
      final timestampSpan = _findSpan(
        richText.text as TextSpan,
        matching: (span) => span.text == ' 2d',
      );
      expect(timestampSpan, isNotNull);
      expect(timestampSpan!.style?.color, equals(VineTheme.onSurfaceMuted55));
    });
  });
}
