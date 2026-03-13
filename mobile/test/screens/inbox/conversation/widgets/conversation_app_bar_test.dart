import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/screens/inbox/conversation/widgets/conversation_app_bar.dart';

void main() {
  group(ConversationAppBar, () {
    group('renders', () {
      testWidgets('renders display name', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ConversationAppBar(
                displayName: 'Alice',
                handle: '@alice',
                onBack: () {},
                onOptions: () {},
              ),
            ),
          ),
        );

        expect(find.text('Alice'), findsOneWidget);
      });

      testWidgets('renders handle when non-empty', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ConversationAppBar(
                displayName: 'Alice',
                handle: '@alice',
                onBack: () {},
                onOptions: () {},
              ),
            ),
          ),
        );

        expect(find.text('@alice'), findsOneWidget);
      });

      testWidgets('does not render handle when empty', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ConversationAppBar(
                displayName: 'Alice',
                handle: '',
                onBack: () {},
                onOptions: () {},
              ),
            ),
          ),
        );

        // Display name is still shown
        expect(find.text('Alice'), findsOneWidget);
        // No handle text rendered
        final divineIcons = tester
            .widgetList<DivineIcon>(find.byType(DivineIcon))
            .toList();
        // Only two icons (back + options), no extra text for handle
        expect(divineIcons, hasLength(2));
        // Confirm no empty-string Text widget either
        expect(find.text(''), findsNothing);
      });
    });

    group('interactions', () {
      testWidgets('calls onBack when back button is tapped', (tester) async {
        var onBackCalled = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ConversationAppBar(
                displayName: 'Alice',
                handle: '@alice',
                onBack: () => onBackCalled = true,
                onOptions: () {},
              ),
            ),
          ),
        );

        // The back button contains the caretLeft icon.
        // Find the GestureDetector that is an ancestor of the caretLeft icon.
        final backButton = find.ancestor(
          of: find.byWidgetPredicate(
            (widget) =>
                widget is DivineIcon && widget.icon == DivineIconName.caretLeft,
          ),
          matching: find.byType(GestureDetector),
        );

        await tester.tap(backButton.first);
        await tester.pump();

        expect(onBackCalled, isTrue);
      });

      testWidgets('calls onOptions when options button is tapped', (
        tester,
      ) async {
        var onOptionsCalled = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ConversationAppBar(
                displayName: 'Alice',
                handle: '@alice',
                onBack: () {},
                onOptions: () => onOptionsCalled = true,
              ),
            ),
          ),
        );

        // The options button contains the dotsThreeVertical icon.
        final optionsButton = find.ancestor(
          of: find.byWidgetPredicate(
            (widget) =>
                widget is DivineIcon &&
                widget.icon == DivineIconName.dotsThreeVertical,
          ),
          matching: find.byType(GestureDetector),
        );

        await tester.tap(optionsButton.first);
        await tester.pump();

        expect(onOptionsCalled, isTrue);
      });
    });
  });
}
