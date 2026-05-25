// ABOUTME: Widget tests for FullReactionEmojiPickerSheet.
// ABOUTME: Verifies the sheet mounts the emoji picker and resolves its result.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/screens/inbox/conversation/widgets/full_reaction_emoji_picker_sheet.dart';
import 'package:pro_image_editor/pro_image_editor.dart';

import '../../../../helpers/test_provider_overrides.dart';

void main() {
  group('FullReactionEmojiPickerSheet', () {
    testWidgets('mounts the emoji picker when shown', (tester) async {
      await tester.pumpWidget(
        testMaterialApp(
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: TextButton(
                  onPressed: () {
                    unawaited(
                      FullReactionEmojiPickerSheet.show(context: context),
                    );
                  },
                  child: const Text('open'),
                ),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.byType(EmojiEditor), findsOneWidget);
    });

    testWidgets('resolves to null when dismissed without a choice', (
      tester,
    ) async {
      String? selected;
      var completed = false;
      await tester.pumpWidget(
        testMaterialApp(
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: TextButton(
                  onPressed: () async {
                    selected = await FullReactionEmojiPickerSheet.show(
                      context: context,
                    );
                    completed = true;
                  },
                  child: const Text('open'),
                ),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      // Dismiss the sheet without selecting an emoji.
      Navigator.of(tester.element(find.byType(EmojiEditor))).pop();
      await tester.pumpAndSettle();

      expect(completed, isTrue);
      expect(selected, isNull);
    });
  });
}
