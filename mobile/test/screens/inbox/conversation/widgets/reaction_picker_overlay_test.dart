// ABOUTME: Widget tests for ReactionPickerOverlay.
// ABOUTME: Verifies the combined sheet renders the expected controls and
// ABOUTME: dismisses when an action is selected.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/screens/inbox/conversation/widgets/reaction_picker_overlay.dart';

import '../../../../helpers/test_provider_overrides.dart';

void main() {
  Future<void> openOverlay(
    WidgetTester tester, {
    bool isSent = false,
    bool showPicker = true,
    bool isVideoShare = false,
  }) async {
    await tester.pumpWidget(
      testMaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: TextButton(
                onPressed: () {
                  unawaited(
                    ReactionPickerOverlay.show(
                      context: context,
                      isSent: isSent,
                      showPicker: showPicker,
                      isVideoShare: isVideoShare,
                    ),
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
  }

  group('ReactionPickerOverlay', () {
    testWidgets('renders quick reactions and delete action for sent messages', (
      tester,
    ) async {
      await openOverlay(tester, isSent: true);

      expect(find.text('🔥'), findsOneWidget);
      expect(
        find.bySemanticsLabel('Add custom emoji reaction'),
        findsOneWidget,
      );
      expect(find.text('Copy text'), findsOneWidget);
      expect(find.text('Delete for everyone'), findsOneWidget);
    });

    testWidgets('dismisses after selecting a quick reaction', (tester) async {
      await openOverlay(tester);

      await tester.tap(find.text('🔥'));
      await tester.pumpAndSettle();

      expect(find.text('🔥'), findsNothing);
      expect(find.text('Copy text'), findsNothing);
    });

    testWidgets('"+" affordance dismisses and pops openFullPicker', (
      tester,
    ) async {
      ReactionPickerResult? result;
      await tester.pumpWidget(
        testMaterialApp(
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: TextButton(
                  onPressed: () async {
                    result = await ReactionPickerOverlay.show(
                      context: context,
                      isSent: false,
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

      await tester.tap(find.bySemanticsLabel('Add custom emoji reaction'));
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('Add custom emoji reaction'), findsNothing);
      expect(result?.openFullPicker, isTrue);
    });

    testWidgets('omits picker row when showPicker is false', (tester) async {
      await openOverlay(tester, showPicker: false);

      expect(find.text('🔥'), findsNothing);
      expect(find.bySemanticsLabel('Add custom emoji reaction'), findsNothing);
      expect(find.text('Copy text'), findsOneWidget);
    });
  });
}
