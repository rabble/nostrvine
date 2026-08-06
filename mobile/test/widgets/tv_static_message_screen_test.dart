// ABOUTME: Widget tests for the shared TV-static message takeover
// ABOUTME: Covers optional description, optional action, close, and footer

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/widgets/tv_static_message_screen.dart';

void main() {
  group(TvStaticMessageScreen, () {
    testWidgets('renders the sticker, title, and description', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: TvStaticMessageScreen(
            sticker: DivineStickerName.vintageTvTestPattern,
            title: 'Video not found',
            description: 'It was either deleted, or it is hiding.',
            onClose: () {},
          ),
        ),
      );

      expect(
        find.byWidgetPredicate(
          (w) =>
              w is DivineSticker &&
              w.sticker == DivineStickerName.vintageTvTestPattern,
        ),
        findsOneWidget,
      );
      expect(find.text('Video not found'), findsOneWidget);
      expect(
        find.text('It was either deleted, or it is hiding.'),
        findsOneWidget,
      );
    });

    testWidgets('omits the action button when no action is supplied', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: TvStaticMessageScreen(
            sticker: DivineStickerName.alert,
            title: 'Video not found',
            onClose: () {},
          ),
        ),
      );

      expect(find.byType(DivineButton), findsNothing);
    });

    testWidgets('invokes the action when the button is tapped', (tester) async {
      var actionCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: TvStaticMessageScreen(
            sticker: DivineStickerName.alert,
            title: 'Failed to load video',
            actionLabel: 'Retry',
            onAction: () => actionCount++,
            onClose: () {},
          ),
        ),
      );

      await tester.tap(find.text('Retry'));
      await tester.pump();

      expect(actionCount, equals(1));
    });

    testWidgets('invokes onClose from the labelled close button', (
      tester,
    ) async {
      var closeCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: TvStaticMessageScreen(
            sticker: DivineStickerName.alert,
            title: 'Failed to load video',
            onClose: () => closeCount++,
            closeSemanticLabel: 'Close video player',
          ),
        ),
      );

      await tester.tap(find.bySemanticsLabel('Close video player'));
      await tester.pump();

      expect(closeCount, equals(1));
    });

    testWidgets('renders the footer chrome when supplied', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: TvStaticMessageScreen(
            sticker: DivineStickerName.alert,
            title: 'Allow camera access',
            onClose: () {},
            footer: const SizedBox(key: Key('footer'), height: 48),
          ),
        ),
      );

      expect(find.byKey(const Key('footer')), findsOneWidget);
    });
  });
}
